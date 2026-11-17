#include "algorithms.h"
void insertion_sort(int32_t *a, uint32_t n, sort_stats *s) {
    s->comparisons = 0; s->moves = 0;
    for (uint32_t i = 1; i < n; ++i) {
        int32_t key = a[i]; uint32_t j = i;
        while (j) {
            ++s->comparisons;
            if (a[j - 1] <= key) break;
            a[j] = a[j - 1]; ++s->moves; --j;
        }
        if (j != i) { a[j] = key; ++s->moves; }
    }
}
void bubble_sort(int32_t *a, uint32_t n, sort_stats *s) {
    s->comparisons = 0; s->moves = 0;
    for (uint32_t end = n; end > 1; --end) {
        uint32_t changed = 0;
        for (uint32_t j = 1; j < end; ++j) {
            ++s->comparisons;
            if (a[j - 1] > a[j]) {
                int32_t t = a[j - 1]; a[j - 1] = a[j]; a[j] = t;
                s->moves += 2; changed = 1;
            }
        }
        if (!changed) break;
    }
}
int32_t binary_search(const int32_t *a, uint32_t n, int32_t target) {
    uint32_t low = 0, high = n;
    while (low < high) {
        uint32_t mid = low + ((high - low) >> 1);
        if (a[mid] == target) return (int32_t)mid;
        if (a[mid] < target) low = mid + 1; else high = mid;
    }
    return -1;
}
subarray_result max_subarray(const int32_t *a, uint32_t n) {
    subarray_result best = {a[0], 0, 0};
    int32_t sum = a[0]; uint32_t start = 0;
    for (uint32_t i = 1; i < n; ++i) {
        if (sum < 0) { sum = a[i]; start = i; } else sum += a[i];
        if (sum > best.sum) { best.sum = sum; best.left = start; best.right = i; }
    }
    return best;
}
uint32_t binary_gcd(uint32_t a, uint32_t b) {
    if (!a) return b;
    if (!b) return a;
    uint32_t shift = 0;
    while (((a | b) & 1u) == 0) { a >>= 1; b >>= 1; ++shift; }
    while ((a & 1u) == 0) a >>= 1;
    do {
        while ((b & 1u) == 0) b >>= 1;
        if (a > b) { uint32_t t = a; a = b; b = t; }
        b -= a;
    } while (b);
    return a << shift;
}
