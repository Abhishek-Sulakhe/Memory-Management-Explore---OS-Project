#include <linux/init.h>
#include <linux/kernel.h>
#include <linux/kstrtox.h>
#include <linux/list.h>
#include <linux/module.h>
#include <linux/mutex.h>
#include <linux/proc_fs.h>
#include <linux/seq_file.h>
#include <linux/slab.h>
#include <linux/string.h>
#include <linux/uaccess.h>
#include <linux/vmalloc.h>

#define MEMX_MODULE_NAME "mem_explorer"
#define MEMX_PROC_DIR "mem_explorer"
#define MEMX_PROC_CONTROL "control"
#define MEMX_PROC_STATUS "status"
#define MEMX_CMD_LEN 128
struct memx_block {
	struct list_head node;
	u64 id;
	void *ptr;
	size_t size;
	bool via_vmalloc;
	bool zeroed;
};

static LIST_HEAD(memx_blocks);
static DEFINE_MUTEX(memx_lock);

static struct proc_dir_entry *memx_proc_dir;
static struct proc_dir_entry *memx_proc_control;
static struct proc_dir_entry *memx_proc_status;

static ulong vmalloc_threshold = 8192;
module_param(vmalloc_threshold, ulong, 0644);
MODULE_PARM_DESC(vmalloc_threshold,
		 "Sizes above this threshold use vmalloc instead of kmalloc");

static ulong max_allocation = 4 * 1024 * 1024;
module_param(max_allocation, ulong, 0644);
MODULE_PARM_DESC(max_allocation,
		 "Maximum size allowed for a single allocation request");

static uint max_tracked_allocations = 256;
module_param(max_tracked_allocations, uint, 0644);
MODULE_PARM_DESC(max_tracked_allocations,
		 "Maximum number of live allocations tracked by the module");

static u64 next_id = 1;
static u64 alloc_requests;
static u64 free_requests;
static u64 failed_allocations;
static u64 total_allocations_created;
static u64 peak_active_bytes;
static u64 active_bytes;
static u64 last_allocated_id;
static u32 active_allocations;
static u8 last_touch_checksum;

static struct memx_block *memx_find_block_locked(u64 id)
{
	struct memx_block *block;

	list_for_each_entry(block, &memx_blocks, node) {
		if (block->id == id)
			return block;
	}

	return NULL;
}

static void memx_free_block_storage(struct memx_block *block)
{
	if (!block)
		return;

	if (block->via_vmalloc)
		vfree(block->ptr);
	else
		kfree(block->ptr);

	kfree(block);
}

static void memx_account_allocation_locked(size_t size)
{
	active_allocations++;
	active_bytes += size;
	total_allocations_created++;
	if (active_bytes > peak_active_bytes)
		peak_active_bytes = active_bytes;
}

static void memx_account_free_locked(size_t size)
{
	active_allocations--;
	active_bytes -= size;
}

static int memx_alloc_block(size_t size, bool zeroed, u64 *new_id)
{
	struct memx_block *block;
	void *ptr;
	bool via_vmalloc;
	int ret = 0;

	if (!size || size > max_allocation)
		return -EINVAL;

	mutex_lock(&memx_lock);
	alloc_requests++;
	if (active_allocations >= max_tracked_allocations) {
		failed_allocations++;
		mutex_unlock(&memx_lock);
		return -ENOSPC;
	}
	mutex_unlock(&memx_lock);

	block = kzalloc(sizeof(*block), GFP_KERNEL);
	if (!block) {
		mutex_lock(&memx_lock);
		failed_allocations++;
		mutex_unlock(&memx_lock);
		return -ENOMEM;
	}

	via_vmalloc = size > vmalloc_threshold;
	if (via_vmalloc)
		ptr = zeroed ? vzalloc(size) : vmalloc(size);
	else
		ptr = zeroed ? kzalloc(size, GFP_KERNEL) : kmalloc(size, GFP_KERNEL);

	if (!ptr) {
		mutex_lock(&memx_lock);
		failed_allocations++;
		mutex_unlock(&memx_lock);
		kfree(block);
		return -ENOMEM;
	}

	block->ptr = ptr;
	block->size = size;
	block->via_vmalloc = via_vmalloc;
	block->zeroed = zeroed;

	mutex_lock(&memx_lock);
	if (active_allocations >= max_tracked_allocations) {
		failed_allocations++;
		ret = -ENOSPC;
		goto unlock_free;
	}

	block->id = next_id++;
	list_add_tail(&block->node, &memx_blocks);
	memx_account_allocation_locked(size);
	last_allocated_id = block->id;
	*new_id = block->id;
	mutex_unlock(&memx_lock);

	pr_info("%s: allocated id=%llu size=%zu backend=%s zeroed=%d\n",
		MEMX_MODULE_NAME, (unsigned long long)block->id, block->size,
		block->via_vmalloc ? "vmalloc" : "kmalloc", block->zeroed);

	return 0;

unlock_free:
	mutex_unlock(&memx_lock);
	memx_free_block_storage(block);
	return ret;
}

static int memx_free_block(u64 id)
{
	struct memx_block *block;

	mutex_lock(&memx_lock);
	free_requests++;
	block = memx_find_block_locked(id);
	if (!block) {
		mutex_unlock(&memx_lock);
		return -ENOENT;
	}

	list_del(&block->node);
	memx_account_free_locked(block->size);
	mutex_unlock(&memx_lock);

	pr_info("%s: freed id=%llu size=%zu backend=%s\n",
		MEMX_MODULE_NAME, (unsigned long long)block->id, block->size,
		block->via_vmalloc ? "vmalloc" : "kmalloc");

	memx_free_block_storage(block);
	return 0;
}

static int memx_free_all_blocks(void)
{
	struct memx_block *block;
	struct memx_block *tmp;
	u32 freed = 0;

	mutex_lock(&memx_lock);
	list_for_each_entry_safe(block, tmp, &memx_blocks, node) {
		list_del(&block->node);
		memx_account_free_locked(block->size);
		mutex_unlock(&memx_lock);
		memx_free_block_storage(block);
		freed++;
		mutex_lock(&memx_lock);
	}
	mutex_unlock(&memx_lock);

	pr_info("%s: freed all blocks count=%u\n", MEMX_MODULE_NAME, freed);
	return freed;
}

static int memx_fill_block(u64 id, u8 value)
{
	struct memx_block *block;
	void *ptr;
	size_t size;

	mutex_lock(&memx_lock);
	block = memx_find_block_locked(id);
	if (!block) {
		mutex_unlock(&memx_lock);
		return -ENOENT;
	}

	ptr = block->ptr;
	size = block->size;
	memset(ptr, value, size);
	mutex_unlock(&memx_lock);

	pr_info("%s: filled id=%llu with byte=0x%02x\n",
		MEMX_MODULE_NAME, (unsigned long long)id, value);
	return 0;
}

static int memx_touch_block(u64 id)
{
	struct memx_block *block;
	u8 checksum = 0;
	size_t offset;
	u8 *bytes;
	size_t size;

	mutex_lock(&memx_lock);
	block = memx_find_block_locked(id);
	if (!block) {
		mutex_unlock(&memx_lock);
		return -ENOENT;
	}

	bytes = block->ptr;
	size = block->size;
	for (offset = 0; offset < size; offset += PAGE_SIZE)
		checksum ^= bytes[offset];
	if (size > 0)
		checksum ^= bytes[size - 1];
	last_touch_checksum = checksum;
	mutex_unlock(&memx_lock);

	pr_info("%s: touched id=%llu checksum=0x%02x\n",
		MEMX_MODULE_NAME, (unsigned long long)id, checksum);
	return 0;
}

static int memx_status_show(struct seq_file *m, void *v)
{
	struct memx_block *block;

	mutex_lock(&memx_lock);
	seq_puts(m, "Memory Management Explorer\n");
	seq_puts(m, "==========================\n");
	seq_printf(m, "vmalloc_threshold_bytes: %lu\n", vmalloc_threshold);
	seq_printf(m, "max_allocation_bytes:    %lu\n", max_allocation);
	seq_printf(m, "max_tracked_allocations: %u\n", max_tracked_allocations);
	seq_printf(m, "alloc_requests:          %llu\n",
		   (unsigned long long)alloc_requests);
	seq_printf(m, "free_requests:           %llu\n",
		   (unsigned long long)free_requests);
	seq_printf(m, "failed_allocations:      %llu\n",
		   (unsigned long long)failed_allocations);
	seq_printf(m, "total_allocations:       %llu\n",
		   (unsigned long long)total_allocations_created);
	seq_printf(m, "last_allocated_id:       %llu\n",
		   (unsigned long long)last_allocated_id);
	seq_printf(m, "active_allocations:      %u\n", active_allocations);
	seq_printf(m, "active_bytes:            %llu\n",
		   (unsigned long long)active_bytes);
	seq_printf(m, "peak_active_bytes:       %llu\n",
		   (unsigned long long)peak_active_bytes);
	seq_printf(m, "last_touch_checksum:     0x%02x\n", last_touch_checksum);
	seq_puts(m, "\nCommands:\n");
	seq_puts(m, "  alloc <size> [zero]\n");
	seq_puts(m, "  free <id>\n");
	seq_puts(m, "  fill <id> <byte>\n");
	seq_puts(m, "  touch <id>\n");
	seq_puts(m, "  freeall\n");
	seq_puts(m, "\nActive allocations:\n");
	seq_puts(m, "  ID    Size(bytes)  Backend   Zeroed\n");

	list_for_each_entry(block, &memx_blocks, node) {
		seq_printf(m, "  %-5llu %-12zu %-8s %d\n",
			   (unsigned long long)block->id, block->size,
			   block->via_vmalloc ? "vmalloc" : "kmalloc",
			   block->zeroed);
	}
	mutex_unlock(&memx_lock);

	return 0;
}

static int memx_status_open(struct inode *inode, struct file *file)
{
	return single_open(file, memx_status_show, NULL);
}

static int memx_control_show(struct seq_file *m, void *v)
{
	seq_puts(m, "Write commands into this file. Example:\n");
	seq_puts(m, "  echo \"alloc 4096 zero\" > /proc/mem_explorer/control\n");
	seq_puts(m, "  echo \"fill 1 170\" > /proc/mem_explorer/control\n");
	seq_puts(m, "  echo \"touch 1\" > /proc/mem_explorer/control\n");
	seq_puts(m, "  echo \"free 1\" > /proc/mem_explorer/control\n");
	return 0;
}

static int memx_control_open(struct inode *inode, struct file *file)
{
	return single_open(file, memx_control_show, NULL);
}

static int memx_parse_u64_token(char *token, u64 *value)
{
	if (!token)
		return -EINVAL;
	return kstrtou64(token, 0, value);
}

static int memx_parse_u8_token(char *token, u8 *value)
{
	unsigned int parsed;
	int ret;

	if (!token)
		return -EINVAL;

	ret = kstrtouint(token, 0, &parsed);
	if (ret)
		return ret;
	if (parsed > 0xff)
		return -ERANGE;

	*value = parsed;
	return 0;
}

static char *memx_next_token(char **cursor)
{
	char *token;

	while (cursor && *cursor) {
		token = strsep(cursor, " \t");
		if (token && *token)
			return token;
	}

	return NULL;
}

static ssize_t memx_control_write(struct file *file, const char __user *ubuf,
				  size_t len, loff_t *off)
{
	char buf[MEMX_CMD_LEN];
	char *cursor;
	char *cmd;
	char *arg1;
	char *arg2;
	char *arg3;
	int ret = 0;

	if (*off != 0)
		return 0;

	if (!len || len >= sizeof(buf))
		return -EINVAL;

	if (copy_from_user(buf, ubuf, len))
		return -EFAULT;

	buf[len] = '\0';
	strim(buf);
	cursor = buf;
	cmd = memx_next_token(&cursor);
	arg1 = memx_next_token(&cursor);
	arg2 = memx_next_token(&cursor);
	arg3 = memx_next_token(&cursor);

	if (!cmd || !*cmd)
		return -EINVAL;

	if (!strcmp(cmd, "alloc")) {
		u64 size;
		bool zeroed = false;
		u64 id;

		ret = memx_parse_u64_token(arg1, &size);
		if (ret)
			return ret;
		if (size > (u64)((size_t)-1))
			return -EOVERFLOW;

		if (arg2 && !strcmp(arg2, "zero"))
			zeroed = true;
		else if (arg2)
			return -EINVAL;

		ret = memx_alloc_block(size, zeroed, &id);
		if (ret)
			return ret;

		pr_info("%s: allocation available as id=%llu\n",
			MEMX_MODULE_NAME, (unsigned long long)id);
	} else if (!strcmp(cmd, "free")) {
		u64 id;

		if (arg3)
			return -EINVAL;
		ret = memx_parse_u64_token(arg1, &id);
		if (ret)
			return ret;
		ret = memx_free_block(id);
		if (ret)
			return ret;
	} else if (!strcmp(cmd, "fill")) {
		u64 id;
		u8 value;

		ret = memx_parse_u64_token(arg1, &id);
		if (ret)
			return ret;
		ret = memx_parse_u8_token(arg2, &value);
		if (ret)
			return ret;
		if (arg3)
			return -EINVAL;
		ret = memx_fill_block(id, value);
		if (ret)
			return ret;
	} else if (!strcmp(cmd, "touch")) {
		u64 id;

		if (arg2 || arg3)
			return -EINVAL;
		ret = memx_parse_u64_token(arg1, &id);
		if (ret)
			return ret;
		ret = memx_touch_block(id);
		if (ret)
			return ret;
	} else if (!strcmp(cmd, "freeall")) {
		if (arg1 || arg2 || arg3)
			return -EINVAL;
		memx_free_all_blocks();
	} else {
		return -EINVAL;
	}

	*off += len;
	return len;
}

static const struct proc_ops memx_status_ops = {
	.proc_open = memx_status_open,
	.proc_read = seq_read,
	.proc_lseek = seq_lseek,
	.proc_release = single_release,
};

static const struct proc_ops memx_control_ops = {
	.proc_open = memx_control_open,
	.proc_read = seq_read,
	.proc_write = memx_control_write,
	.proc_lseek = seq_lseek,
	.proc_release = single_release,
};

static int __init memx_init(void)
{
	memx_proc_dir = proc_mkdir(MEMX_PROC_DIR, NULL);
	if (!memx_proc_dir)
		return -ENOMEM;

	memx_proc_control = proc_create(MEMX_PROC_CONTROL, 0666, memx_proc_dir,
					&memx_control_ops);
	if (!memx_proc_control)
		goto err_remove_dir;

	memx_proc_status = proc_create(MEMX_PROC_STATUS, 0444, memx_proc_dir,
				       &memx_status_ops);
	if (!memx_proc_status)
		goto err_remove_control;

	pr_info("%s: initialized vmalloc_threshold=%lu max_allocation=%lu max_tracked=%u\n",
		MEMX_MODULE_NAME, vmalloc_threshold, max_allocation,
		max_tracked_allocations);
	return 0;

err_remove_control:
	proc_remove(memx_proc_control);
err_remove_dir:
	proc_remove(memx_proc_dir);
	return -ENOMEM;
}

static void __exit memx_exit(void)
{
	memx_free_all_blocks();
	if (memx_proc_status)
		proc_remove(memx_proc_status);
	if (memx_proc_control)
		proc_remove(memx_proc_control);
	if (memx_proc_dir)
		proc_remove(memx_proc_dir);

	pr_info("%s: unloaded\n", MEMX_MODULE_NAME);
}

module_init(memx_init);
module_exit(memx_exit);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("OpenAI Codex");
MODULE_DESCRIPTION("Academic memory management explorer using kmalloc/vmalloc");
MODULE_VERSION("1.0");
