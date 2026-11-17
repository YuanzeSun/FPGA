OUTPUT_ARCH(riscv)
ENTRY(_start)
MEMORY {
    ROM (rx) : ORIGIN = 0, LENGTH = 4K
    RAM (rw) : ORIGIN = 0x1000, LENGTH = 1K
}
SECTIONS {
    .text : { KEEP(*(.text.start)) *(.text*) *(.rodata*) . = ALIGN(4); } > ROM
    .data : { _sdata = .; *(.data*) *(.sdata*) . = ALIGN(4); _edata = .; } > RAM AT>ROM
    _sidata = LOADADDR(.data);
    .bss (NOLOAD) : { _sbss = .; *(.bss*) *(.sbss*) *(COMMON) . = ALIGN(4); _ebss = .; } > RAM
    _stack_top = ORIGIN(RAM) + LENGTH(RAM);
    ASSERT(_ebss <= _stack_top - 512, "Reserve at least 512 bytes of stack")
}
