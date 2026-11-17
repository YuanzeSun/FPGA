#include <stdint.h>
#define MMIO(a) (*(volatile uint32_t *)(a))
#define GPIO MMIO(0x40000000u)
#define TX MMIO(0x40000004u)
#define RX MMIO(0x40000008u)
#define TICKS MMIO(0x40000010u)
static volatile uint32_t va = 0x81234567u, vb = 0x10203040u;
static volatile uint8_t bytes[8];
static volatile uint16_t halves[4];
static void puts_uart(const char *s) { while (*s) TX = (uint8_t)*s++; }
static void hex(uint32_t v) {
    for (int i = 28; i >= 0; i -= 4) {
        uint32_t d = (v >> i) & 15u;
        TX = d < 10 ? d + '0' : d - 10 + 'A';
    }
}
static uint32_t selftest(void) {
    uint32_t a = va, b = vb, mask = 0;
    if (a + b == 0x914375a7u) mask |= 1;
    if (a - b == 0x71031527u) mask |= 2;
    if ((uint32_t)((int32_t)a >> 7) == 0xff02468au) mask |= 4;
    if ((a << 5) == 0x2468ace0u && (a >> 28) == 8) mask |= 8;
    if ((int32_t)a < (int32_t)b && a > b) mask |= 16;
    bytes[1] = 0xfe; bytes[3] = 0x81;
    if ((int8_t)bytes[1] == -2 && bytes[3] == 129) mask |= 32;
    halves[1] = 0x8001; halves[3] = 0x7ffe;
    if ((int16_t)halves[1] == -32767 && halves[3] == 32766) mask |= 64;
    uint32_t x = 0, y = 1;
    for (unsigned i = 0; i < 12; ++i) { uint32_t n = x + y; x = y; y = n; }
    if (x == 144 && (a ^ b) == 0x91037527u) mask |= 128;
    return mask;
}
static void status(uint32_t count) {
    puts_uart("COUNT="); hex(count); puts_uart(" GPIO="); hex(GPIO);
    puts_uart(" TICKS="); hex(TICKS); puts_uart("\r\n");
}
int main(void) {
    uint32_t mask = selftest();
    puts_uart("\r\nCPU=SimpleRV32I ISA=RV32I SELF="); hex(mask); puts_uart("\r\n");
    if (mask != 255) {
        GPIO = 63; puts_uart("SELF=FAIL\r\n");
        __asm__ volatile("ebreak");
    }
    puts_uart("SELF=PASS\r\n");
    uint32_t count = 0, pos = 0, last = TICKS;
    GPIO = 1;
    for (;;) {
        int32_t ch = (int32_t)RX;
        if (ch >= 0) {
            puts_uart("RX="); hex((uint32_t)ch); puts_uart("\r\n");
            if (ch == 'p') puts_uart("PONG\r\n");
            if (ch == '?') { puts_uart("CPU=SimpleRV32I SELF=PASS "); status(count); }
        }
        uint32_t now = TICKS;
        if (now - last >= 13500000u) {
            last = now; ++count; ++pos; if (pos == 6) pos = 0;
            GPIO = 1u << pos; status(count);
        }
    }
}
