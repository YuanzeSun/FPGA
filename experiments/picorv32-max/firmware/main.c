typedef unsigned int u32;
typedef signed int s32;
_Static_assert(sizeof(u32) == 4, "RV32 required");
#define MMIO(a) (*(volatile u32 *)(a))
#define UART_DIV MMIO(0x02000000u)
#define UART_DATA MMIO(0x02000004u)
#define GPIO MMIO(0x02000008u)
#define IRQ_PERIOD MMIO(0x02000010u)
#define SOFT_IRQ MMIO(0x02000020u)
#define TRACE_COUNT MMIO(0x02000024u)

volatile u32 timer_irqs, soft_irqs, illegal_irqs, align_irqs;
u32 irq_mask(u32), irq_timer(u32), irq_wait(void);
u32 read_cycle(void), read_cycle_high(void), read_instret(void), read_instret_high(void);
u32 compressed_probe(void), pcpi_reverse(u32);
void m_results(u32, u32, u32 *), shift_results(u32, u32, u32 *), fault_probe(void);
#include "golden_vectors.h"

static void putc_uart(char c) { UART_DATA = (unsigned char)c; }
static void puts_uart(const char *s) { while (*s) putc_uart(*s++); }
static void hex32(u32 value) {
    const char *digits = "0123456789ABCDEF";
    for (int shift = 28; shift >= 0; shift -= 4)
        putc_uart(digits[(value >> shift) & 15u]);
}
static void field(const char *s, u32 value) { puts_uart(s); hex32(value); }
static u32 test_m(void) {
    u32 actual[8];
    for (u32 row = 0; row < sizeof(m_vectors) / sizeof(m_vectors[0]); row++) {
        m_results(m_vectors[row][0], m_vectors[row][1], actual);
        for (u32 i = 0; i < 8; i++)
            if (actual[i] != m_vectors[row][i + 2]) return 0;
    }
    return 1;
}
static u32 test_shift(void) {
    u32 actual[3];
    for (u32 row = 0; row < sizeof(shift_vectors) / sizeof(shift_vectors[0]); row++) {
        shift_results(shift_vectors[row][0], shift_vectors[row][1], actual);
        for (u32 i = 0; i < 3; i++)
            if (actual[i] != shift_vectors[row][i + 2]) return 0;
    }
    return 1;
}
static u32 selftest(void) {
    u32 passed = 0;
    if (test_m()) passed |= 1;
    if (compressed_probe() == 42) passed |= 2;
    u32 before = read_cycle();
    u32 instructions = read_instret();
    if (read_cycle() > before && instructions > 0 &&
        read_cycle_high() == 0 && read_instret_high() == 0) passed |= 4;
    if (test_shift()) passed |= 8;
    if (pcpi_reverse(0x12345678u) == 0x1e6a2c48u) passed |= 16;
    // Keep timer IRQ masked while waitirq waits for its pending bit.
    irq_mask(~(2u | 4u | 16u));
    irq_timer(4000);
    u32 pending = irq_wait();
    irq_mask(~(1u | 2u | 4u | 16u));
    while (timer_irqs == 0) {}
    SOFT_IRQ = 1;
    while (soft_irqs == 0) {}
    if ((pending & 1u) && timer_irqs == 1 && soft_irqs == 1) passed |= 32;
    fault_probe();
    if (illegal_irqs == 2 && align_irqs == 1) passed |= 64;
    if (TRACE_COUNT > 0) passed |= 128;
    return passed;
}
static void status(u32 tests) {
    puts_uart("CPU=RV32IMC");
    field(" SELF=", tests);
    field(" IRQ=", timer_irqs);
    field(" SOFT=", soft_irqs);
    field(" ILLEGAL=", illegal_irqs);
    field(" ALIGN=", align_irqs);
    field(" TRACE=", TRACE_COUNT);
    field(" CYCLEH=", read_cycle_high());
    field(" CYCLE=", read_cycle());
    field(" INSTRETH=", read_instret_high());
    field(" INSTRET=", read_instret());
    puts_uart("\r\n");
}
int main(void) {
    UART_DIV = 115;
    GPIO = 1;
    u32 tests = selftest();
    field("RV32IMC selftest=", tests);
    puts_uart("\r\np=PONG m=M-test i=IRQ ?=status 0..5=LED\r\n");
    if (tests != 255) for (;;) {}
    u32 seen = timer_irqs, led = 0;
    irq_timer(IRQ_PERIOD);
    for (;;) {
        s32 input = (s32)UART_DATA;
        if (input == 'p') puts_uart("PONG\r\n");
        else if (input == 'm') puts_uart(test_m() ? "M=PASS\r\n" : "M=FAIL\r\n");
        else if (input == '?') status(tests);
        else if (input == 'i') {
            u32 old = soft_irqs;
            SOFT_IRQ = 1;
            while (soft_irqs == old) {}
            field("SOFTIRQ=", soft_irqs);
            puts_uart("\r\n");
        } else if (input >= '0' && input <= '5') {
            led = (u32)input - '0';
            GPIO = 1u << led;
            field("GPIO=", GPIO);
            puts_uart("\r\n");
        }
        else if (input >= 0) {
            field("RX=", (u32)input);
            puts_uart("\r\n");
        }
        if (timer_irqs != seen) {
            seen = timer_irqs;
            irq_timer(IRQ_PERIOD);
            if (++led == 6) led = 0;
            GPIO = 1u << led;
            field("IRQ_TICK=", seen);
            field(" GPIO=", GPIO);
            puts_uart("\r\n");
        }
    }
}
