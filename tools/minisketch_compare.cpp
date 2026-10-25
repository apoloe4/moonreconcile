// MoonReconcile's independent test driver, Apache-2.0. Upstream is linked only
// for offline evaluation; no minisketch implementation is included here.
#include <minisketch.h>
#include <algorithm>
#include <chrono>
#include <cstdint>
#include <iostream>
#include <vector>

static uint64_t identifier(int index, int seed) {
    return (uint64_t(index) + 1 + uint64_t(seed) * 1000003) * UINT64_C(6364136223846793005);
}

int main() {
    std::cout << "members,differences,ratio_twice,seed,capacity,verified,reported_success,sketch_bytes,decode_us\n";
    for (int n : {1000, 10000}) {
        for (int d : {0, 2, 20, 200}) {
            for (int ratio : {1, 2, 4}) {
                for (int seed = 1; seed <= 10; ++seed) {
                    size_t capacity = d == 0 ? 1 : d * ratio / 2;
                    minisketch* sketch = minisketch_create(64, 0, capacity);
                    if (!sketch) return 2;
                    // Shared members cancel algebraically. This builds the exact
                    // merged difference, NOT two full sets. Compare decode time
                    // only; full-set construction time is intentionally absent.
                    std::vector<uint64_t> expected;
                    for (int i = 0; i < d / 2; ++i) {
                        expected.push_back(identifier(i, seed));
                        expected.push_back(identifier(n + i, seed));
                    }
                    for (auto id : expected) minisketch_add_uint64(sketch, id);
                    std::vector<uint64_t> actual(capacity);
                    auto start = std::chrono::steady_clock::now();
                    auto count = minisketch_decode(sketch, capacity, actual.data());
                    auto end = std::chrono::steady_clock::now();
                    bool reported = count >= 0;
                    if (reported) actual.resize(size_t(count));
                    std::sort(actual.begin(), actual.end());
                    std::sort(expected.begin(), expected.end());
                    bool verified = reported && actual == expected;
                    if (capacity >= size_t(d) && !verified) return 3;
                    double us = std::chrono::duration<double, std::micro>(end - start).count();
                    std::cout << n << ',' << d << ',' << ratio << ',' << seed << ','
                              << capacity << ',' << (verified ? "true" : "false") << ','
                              << (reported ? "true" : "false") << ','
                              << minisketch_serialized_size(sketch) << ',' << us << '\n';
                    minisketch_destroy(sketch);
                }
            }
        }
    }
}
