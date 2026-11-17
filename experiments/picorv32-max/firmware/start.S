// IRQ instruction encodings follow PicoRV32 firmware/custom_ops.S (public domain).
.macro getq rd, qs
    .insn r 0x0b, 4, 0, \rd, x\qs, x0
.endm
.macro setq qd, rs
    .insn r 0x0b, 2, 1, x\qd, \rs, x0
.endm
.macro maskirq rd, rs
    .insn r 0x0b, 6, 3, \rd, \rs, x0
.endm
.macro timer rd, rs
    .insn r 0x0b, 6, 5, \rd, \rs, x0
.endm
.section .text.start
.option norvc
.option norelax
.globl _start
_start:
    j boot
.org 0x10
.globl irq_entry
irq_entry:
    // Leaf handler saves its only two working registers in q2/q3.
    setq 2, t0
    setq 3, t1
    getq t0, 1
    andi t1, t0, 1
    beqz t1, 1f
    la t0, timer_irqs
    lw t1, 0(t0)
    addi t1, t1, 1
    sw t1, 0(t0)
1:
    getq t0, 1
    andi t1, t0, 16
    beqz t1, 2f
    la t0, soft_irqs
    lw t1, 0(t0)
    addi t1, t1, 1
    sw t1, 0(t0)
2:
    getq t0, 1
    andi t1, t0, 2
    beqz t1, 3f
    la t0, illegal_irqs
    lw t1, 0(t0)
    addi t1, t1, 1
    sw t1, 0(t0)
3:
    getq t0, 1
    andi t1, t0, 4
    beqz t1, 4f
    la t0, align_irqs
    lw t1, 0(t0)
    addi t1, t1, 1
    sw t1, 0(t0)
4:
    getq t0, 2
    getq t1, 3
    .insn r 0x0b, 0, 2, x0, x0, x0 // retirq
boot:
    la sp, _stack_top
    la a0, _bss_start
    la a1, _bss_end
5:
    bgeu a0, a1, 6f
    sw zero, 0(a0)
    addi a0, a0, 4
    j 5b
6:
    call main
    j .

.section .text
.globl irq_mask
irq_mask:
    maskirq a0, a0
    ret
.globl irq_timer
irq_timer:
    timer a0, a0
    ret
.globl irq_wait
irq_wait:
    .insn r 0x0b, 4, 4, a0, x0, x0
    ret
.globl read_cycle, read_cycle_high, read_instret, read_instret_high
// Counter reads only. No other CSR or privileged instructions are assumed.
read_cycle:
    .word 0xc0002573
    ret
read_cycle_high:
    .word 0xc8002573
    ret
read_instret:
    .word 0xc0202573
    ret
read_instret_high:
    .word 0xc8202573
    ret
.globl m_results
m_results:
    mul t0, a0, a1
    sw t0, 0(a2)
    mulh t0, a0, a1
    sw t0, 4(a2)
    mulhsu t0, a0, a1
    sw t0, 8(a2)
    mulhu t0, a0, a1
    sw t0, 12(a2)
    div t0, a0, a1
    sw t0, 16(a2)
    divu t0, a0, a1
    sw t0, 20(a2)
    rem t0, a0, a1
    sw t0, 24(a2)
    remu t0, a0, a1
    sw t0, 28(a2)
    ret
.globl shift_results
shift_results:
    sll t0, a0, a1
    sw t0, 0(a2)
    srl t0, a0, a1
    sw t0, 4(a2)
    sra t0, a0, a1
    sw t0, 8(a2)
    ret
.globl pcpi_reverse
pcpi_reverse:
    .insn r 0x2b, 0, 0, a0, a0, x0
    ret
.globl fault_probe
fault_probe:
    ebreak
    .word 0xffffffff // deliberately unsupported instruction
    lw a0, 1(sp)     // deliberately misaligned read
    ret
.option rvc
.globl compressed_probe
compressed_probe:
    c.li a0, 21
    c.slli a0, 1
    c.jr ra
