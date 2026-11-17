ENTRY(_start)
MEMORY {
    ROM (rx) : ORIGIN = 0, LENGTH = 16K
    RAM (rw) : ORIGIN = 0x10000, LENGTH = 8K
}
SECTIONS {
    .text : { KEEP(*(.text.start)) *(.text*) *(.rodata*) } > ROM
    .data : ALIGN(4) { *(.data*) *(.sdata*) } > RAM
    ASSERT(SIZEOF(.data)==0, "Use const or zero-initialized data")
    .bss (NOLOAD) : ALIGN(4) {
        _bss_start = .; *(.bss*) *(.sbss*) *(COMMON)
        . = ALIGN(4); _bss_end = .;
    } > RAM
    _stack_top = ORIGIN(RAM)+LENGTH(RAM);
    ASSERT(_bss_end <= _stack_top-1536, "Reserve at least 1536 bytes of stack")
}
