typedef unsigned int u32;
typedef signed int s32;
_Static_assert(sizeof(u32) == 4, "RV32 word required");

#define MMIO(address) (*(volatile u32 *)(address))
#define UART_DIV MMIO(0x02000000u)
#define UART_DATA MMIO(0x02000004u)
#define GPIO MMIO(0x02000008u)
#define TIMER MMIO(0x0200000cu)
#define CLOCK_HZ 27000000u

static void putc_uart(char c) { UART_DATA = (unsigned char)c; }
static void puts_uart(const char *text) {
    while (*text) putc_uart(*text++);
}
static void hex32(u32 value) {
    const char *digits = "0123456789ABCDEF";
    for (int shift = 28; shift >= 0; shift -= 4)
        putc_uart(digits[(value >> shift) & 15u]);
}

int main(void) {
    // This upstream UART implementation uses divider + 2 clocks per bit.
    UART_DIV = (CLOCK_HZ + 115200u / 2) / 115200u - 2;
    GPIO = 1;
    puts_uart("PicoRV32 C firmware ready\r\n");
    puts_uart("p=PONG, 0..5=LED, ?=status\r\n");
    u32 ticks = 0;
    u32 led = 0;
    u32 deadline = TIMER + CLOCK_HZ;
    for (;;) {
        s32 input = (s32)UART_DATA;
        if (input >= 0) {
            if (input == 'p') {
                puts_uart("PONG\r\n");
            } else if (input >= '0' && input <= '5') {
                led = (u32)input - '0';
                GPIO = 1u << led;
                puts_uart("GPIO=");
                hex32(GPIO);
                puts_uart("\r\n");
            } else if (input == '?') {
                puts_uart("CPU=PicoRV32 TICKS=");
                hex32(ticks);
                puts_uart(" GPIO=");
                hex32(GPIO);
                puts_uart("\r\n");
            }
        }
        if ((s32)(TIMER - deadline) >= 0) {
            deadline += CLOCK_HZ;
            ticks++;
            led++;
            if (led == 6) led = 0;
            GPIO = 1u << led;
            puts_uart("TICK=");
            hex32(ticks);
            puts_uart(" GPIO=");
            hex32(GPIO);
            puts_uart("\r\n");
        }
    }
}
