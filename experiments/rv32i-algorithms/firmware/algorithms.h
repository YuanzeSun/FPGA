#ifndef ALGORITHMS_H
#define ALGORITHMS_H
#include <stdint.h>
#define MAX_VALUES 16u
typedef struct { uint32_t comparisons, moves; } sort_stats;
typedef struct { int32_t sum; uint32_t left, right; } subarray_result;
void insertion_sort(int32_t *a, uint32_t n, sort_stats *stats);
void bubble_sort(int32_t *a, uint32_t n, sort_stats *stats);
int32_t binary_search(const int32_t *a, uint32_t n, int32_t target);
subarray_result max_subarray(const int32_t *a, uint32_t n);
uint32_t binary_gcd(uint32_t a, uint32_t b);
#endif
