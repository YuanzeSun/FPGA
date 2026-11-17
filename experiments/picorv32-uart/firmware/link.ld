ENTRY(_start)
MEMORY { RAM (rwx) : ORIGIN = 0x00000000, LENGTH = 1K }
SECTIONS {
    .text : { KEEP(*(.text.start)) *(.text*) *(.rodata*) } > RAM
    .data : ALIGN(4) { *(.data*) *(.sdata*) } > RAM
    .bss (NOLOAD) : ALIGN(4) {
        _bss_start = .;
        *(.bss*) *(.sbss*) *(COMMON)
        . = ALIGN(4);
        _bss_end = .;
    } > RAM
    _stack_top = ORIGIN(RAM) + LENGTH(RAM);
    ASSERT(_bss_end < _stack_top - 256, "Firmware leaves less than 256 bytes for stack")
}
