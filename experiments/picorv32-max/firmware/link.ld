ENTRY(_start)
MEMORY {
    ROM (rx) : ORIGIN = 0x00000000, LENGTH = 4K
    RAM (rw) : ORIGIN = 0x00001000, LENGTH = 512
}
SECTIONS {
    .text : { KEEP(*(.text.start)) *(.text*) *(.rodata*) } > ROM
    .data : ALIGN(4) { *(.data*) *(.sdata*) } > RAM
    ASSERT(SIZEOF(.data) == 0, "Use zero-initialized BSS or const ROM data")
    .bss (NOLOAD) : ALIGN(4) {
        _bss_start = .;
        *(.bss*) *(.sbss*) *(COMMON)
        . = ALIGN(4);
        _bss_end = .;
    } > RAM
    _stack_top = ORIGIN(RAM) + LENGTH(RAM);
    ASSERT(_bss_end <= _stack_top - 384, "At least 384 bytes of stack required")
}
