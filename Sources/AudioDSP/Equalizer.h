#ifndef MSC_EQUALIZER_INTERNAL_H
#define MSC_EQUALIZER_INTERNAL_H
#include <stdbool.h>
#include <stdatomic.h>
#include <stdint.h>
#define MSC_EQ_BANDS 10
typedef struct { double b0, b1, b2, a1, a2; } MSCEQCoefficients;
typedef struct {
    bool enabled;
    double preamp;
    MSCEQCoefficients bands[MSC_EQ_BANDS];
} MSCEQConfig;
typedef struct {
    MSCEQConfig config;
    double z1[2][MSC_EQ_BANDS], z2[2][MSC_EQ_BANDS];
} MSCEQBank;
typedef struct {
    // SPSC triple buffer: control owns back, audio owns front, atomic middle
    // transfers ownership. No shared mutable coefficient/state memory.
    MSCEQConfig slots[3];
    _Atomic unsigned middle;
    unsigned back, front;
    double sampleRate;
    MSCEQBank current, next;
    unsigned fadeFrame, fadeLength;
    bool fading;
} MSCEQ;
bool MSCEQInit(MSCEQ *eq, double sampleRate);
void MSCEQPublish(MSCEQ *eq, bool enabled, const float *gains, uint32_t count, float preamp, bool automatic);
void MSCEQBeginBlock(MSCEQ *eq);
// Returns whether peak protection is needed for this frame (including transitions).
bool MSCEQProcess(MSCEQ *eq, float *left, float *right);
#endif
