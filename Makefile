KDIR ?= /lib/modules/$(shell uname -r)/build
PWD := $(shell pwd)
MODULE_DIR := $(PWD)/src

.PHONY: all clean load unload reload status help demo stress

all:
	$(MAKE) -C $(KDIR) M=$(MODULE_DIR) modules

clean:
	$(MAKE) -C $(KDIR) M=$(MODULE_DIR) clean

load:
	sudo insmod $(MODULE_DIR)/mem_explorer.ko

unload:
	sudo rmmod mem_explorer

reload: unload load

status:
	cat /proc/mem_explorer/status

demo:
	bash scripts/demo_allocator.sh

stress:
	bash scripts/stress_allocator.sh

help:
	@echo "Targets:"
	@echo "  make all      - Build the kernel module"
	@echo "  make clean    - Remove build artifacts"
	@echo "  make load     - Insert the kernel module"
	@echo "  make unload   - Remove the kernel module"
	@echo "  make reload   - Reinsert the module"
	@echo "  make status   - Show allocator status"
	@echo "  make demo     - Run a guided allocator demo"
	@echo "  make stress   - Run a basic stress workload"

