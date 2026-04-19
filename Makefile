KDIR ?= /lib/modules/$(shell uname -r)/build
PWD := $(shell pwd)
MODULE_DIR := $(PWD)/src

.PHONY: all clean load unload reload status help demo stress \
	expt-threshold expt-memory expt-guardrails expt-latency expt-resize present

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

expt-threshold:
	bash scripts/experiment_threshold.sh

expt-memory:
	bash scripts/experiment_memory_tracking.sh

expt-guardrails:
	bash scripts/experiment_guardrails.sh

expt-latency:
	bash scripts/experiment_latency.sh

expt-resize:
	bash scripts/experiment_resize.sh

present:
	bash scripts/run_all_experiments.sh

help:
	@echo "Targets:"
	@echo "  make all             - Build the kernel module"
	@echo "  make clean           - Remove build artifacts"
	@echo "  make load            - Insert the kernel module"
	@echo "  make unload          - Remove the kernel module"
	@echo "  make reload          - Reinsert the module"
	@echo "  make status          - Show allocator status"
	@echo "  make demo            - Run a guided allocator demo"
	@echo "  make stress          - Run a stress workload"
	@echo "  make expt-threshold  - Experiment: backend selection"
	@echo "  make expt-memory     - Experiment: memory tracking"
	@echo "  make expt-guardrails - Experiment: error handling"
	@echo "  make expt-latency    - Experiment: latency comparison"
	@echo "  make expt-resize     - Experiment: resize & migration"
	@echo "  make present         - Run ALL experiments (for demos)"

