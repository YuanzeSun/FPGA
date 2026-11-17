#include <stdint.h>
#include "algorithms.h"
#define MMIO(a) (*(volatile uint32_t *)(a))
#define GPIO MMIO(0x40000000u)
#define TX MMIO(0x40000004u)
#define RX MMIO(0x40000008u)
#define TICKS MMIO(0x40000010u)
#define INSTRUCTIONS MMIO(0x40000018u)
static char line[192];
static int32_t values[MAX_VALUES + 1], scratch[MAX_VALUES];
static void putc_uart(char c) { TX = (uint8_t)c; }
static void text(const char *s) { while (*s) putc_uart(*s++); }
/* Decimal conversion needs neither a runtime library nor M instructions. */
static void number(uint32_t v) {
    static const uint32_t powers[] = {1000000000u,100000000u,10000000u,
        1000000u,100000u,10000u,1000u,100u,10u,1u};
    uint32_t started = 0;
    for (uint32_t i = 0; i < 10; ++i) {
        uint32_t digit = 0;
        while (v >= powers[i]) { v -= powers[i]; ++digit; }
        if (digit || started || i == 9) { putc_uart((char)('0' + digit)); started = 1; }
    }
}
static void signed_number(int32_t v) {
    if (v < 0) { putc_uart('-'); number(0u - (uint32_t)v); } else number((uint32_t)v);
}
static uint32_t equal(const char *a, const char *b) {
    while (*a && *a == *b) { ++a; ++b; }
    return *a == *b;
}
static int32_t parse(char *p) {
    uint32_t count = 0;
    while (*p) {
        while (*p == ' ' || *p == '\t') ++p;
        if (!*p) break;
        if (count == MAX_VALUES + 1) return -1;
        uint32_t negative = 0, v = 0;
        if (*p == '-' || *p == '+') { negative = *p == '-'; ++p; }
        if (*p < '0' || *p > '9') return -1;
        while (*p >= '0' && *p <= '9') {
            if (v > 100000u) return -1;
            v = (v << 3) + (v << 1) + (uint32_t)(*p++ - '0');
            if (v > 1000000u) return -1;
        }
        if (*p && *p != ' ' && *p != '\t') return -1;
        values[count++] = negative ? -(int32_t)v : (int32_t)v;
    }
    return (int32_t)count;
}
static void error(const char *s) { GPIO = 32; text("ERR "); text(s); text("\r\n"); }
static void metrics(uint32_t cycles, uint32_t instructions) {
    text(" cycles="); number(cycles);
    text(" instructions="); number(instructions); text("\r\n");
}
static void array(const int32_t *a, uint32_t n) {
    for (uint32_t i = 0; i < n; ++i) { putc_uart(' '); signed_number(a[i]); }
    text("\r\n");
}
static void run(void) {
    char *command = line;
    while (*command == ' ' || *command == '\t') ++command;
    if (!*command) return;
    char *args = command;
    while (*args && *args != ' ' && *args != '\t') ++args;
    if (*args) *args++ = 0;
    int32_t count = parse(args);
    if (count < 0) { error("integers -1000000..1000000; at most 17 arguments"); return; }
    if (equal(command, "help") && count == 0) {
        text("sort <1..16 integers>\r\nfind <target> <sorted integers>\r\n"
             "maxsub <1..16 integers>\r\ngcd <a>=0 <b>=0\r\n"
             "info | help | ping\r\nIndices are zero-based.\r\n"); return;
    }
    if (equal(command, "info") && count == 0) {
        text("CPU=SimpleRV32I ISA=RV32I CLOCK=13500000 ROM=16384 RAM=1024\r\n"); return;
    }
    if (equal(command, "ping") && count == 0) { text("PONG\r\n"); return; }
    GPIO = 2;
    uint32_t start_cycles, start_instructions, cycles, instructions;
    if (equal(command, "sort") && count >= 1 && count <= (int32_t)MAX_VALUES) {
        sort_stats stats;
        for (int32_t i = 0; i < count; ++i) scratch[i] = values[i];
        start_cycles = TICKS; start_instructions = INSTRUCTIONS;
        insertion_sort(scratch, (uint32_t)count, &stats);
        instructions = INSTRUCTIONS - start_instructions; cycles = TICKS - start_cycles;
        text("SORT"); array(scratch, (uint32_t)count);
        text("INSERT comparisons="); number(stats.comparisons); text(" moves="); number(stats.moves);
        metrics(cycles, instructions);
        for (int32_t i = 0; i < count; ++i) scratch[i] = values[i];
        start_cycles = TICKS; start_instructions = INSTRUCTIONS;
        bubble_sort(scratch, (uint32_t)count, &stats);
        instructions = INSTRUCTIONS - start_instructions; cycles = TICKS - start_cycles;
        text("BUBBLE comparisons="); number(stats.comparisons); text(" moves="); number(stats.moves);
        metrics(cycles, instructions);
    } else if (equal(command, "find") && count >= 2 && count <= (int32_t)MAX_VALUES + 1) {
        for (int32_t i = 2; i < count; ++i)
            if (values[i] < values[i - 1]) { error("find requires ascending input"); return; }
        start_cycles = TICKS; start_instructions = INSTRUCTIONS;
        int32_t found = binary_search(values + 1, (uint32_t)count - 1, values[0]);
        instructions = INSTRUCTIONS - start_instructions; cycles = TICKS - start_cycles;
        text("FIND index="); signed_number(found); metrics(cycles, instructions);
    } else if (equal(command, "maxsub") && count >= 1 && count <= (int32_t)MAX_VALUES) {
        start_cycles = TICKS; start_instructions = INSTRUCTIONS;
        subarray_result best = max_subarray(values, (uint32_t)count);
        instructions = INSTRUCTIONS - start_instructions; cycles = TICKS - start_cycles;
        text("MAXSUB sum="); signed_number(best.sum); text(" left="); number(best.left);
        text(" right="); number(best.right); metrics(cycles, instructions);
    } else if (equal(command, "gcd") && count == 2 && values[0] >= 0 && values[1] >= 0) {
        start_cycles = TICKS; start_instructions = INSTRUCTIONS;
        uint32_t result = binary_gcd((uint32_t)values[0], (uint32_t)values[1]);
        instructions = INSTRUCTIONS - start_instructions; cycles = TICKS - start_cycles;
        text("GCD value="); number(result); metrics(cycles, instructions);
    } else { error("command or argument count; type help"); return; }
    GPIO = 4;
}
int main(void) {
    GPIO = 1;
    text("SimpleRV32I Algorithms v1\r\nType help for commands.\r\nREADY\r\n");
    uint32_t used = 0, overflow = 0, previous_cr = 0;
    for (;;) {
        int32_t ch = (int32_t)RX;
        if (ch < 0) continue;
        if (ch == '\n' && previous_cr) { previous_cr = 0; continue; }
        previous_cr = ch == '\r';
        if (ch == '\r' || ch == '\n') {
            line[used] = 0;
            if (overflow) error("line too long"); else run();
            used = 0; overflow = 0; text("READY\r\n");
        } else if (ch == 8 || ch == 127) { if (used) --used; }
        else if (ch >= 32 && ch <= 126) {
            if (used + 1 < sizeof(line)) line[used++] = (char)ch;
            else overflow = 1;
        }
    }
}
