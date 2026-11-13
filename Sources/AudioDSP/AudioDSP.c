#include "AudioDSP.h"
#include <math.h>
#include <stdatomic.h>
#include <stdlib.h>
#include <string.h>

struct MSCProcessor {
    _Atomic float target;
    _Atomic float peak;
    _Atomic uint64_t cycles;
    _Atomic uint64_t faults;
    float current; // Audio thread only.
    float coefficient;
};

static float safeGain(float value) {
    return isfinite(value) ? fmaxf(0, fminf(1, value)) : 0;
}

MSCProcessor *MSCProcessorCreate(double sampleRate, float initialGain) {
    if (!isfinite(sampleRate) || sampleRate < 8000 || sampleRate > 384000) return NULL;
    MSCProcessor *p = calloc(1, sizeof(*p));
    if (!p) return NULL;
    atomic_init(&p->target, safeGain(initialGain));
    atomic_init(&p->peak, 0);
    atomic_init(&p->cycles, 0);
    atomic_init(&p->faults, 0);
    if (!atomic_is_lock_free(&p->target) || !atomic_is_lock_free(&p->peak) ||
        !atomic_is_lock_free(&p->cycles) || !atomic_is_lock_free(&p->faults)) {
        free(p); return NULL;
    }
    p->current = safeGain(initialGain);
    p->coefficient = (float)(1 - exp(-1 / (sampleRate * 0.005)));
    return p;
}

void MSCProcessorDestroy(MSCProcessor *p) { free(p); }
void MSCProcessorSetGain(MSCProcessor *p, float gain) {
    if (p) atomic_store_explicit(&p->target, safeGain(gain), memory_order_relaxed);
}
float MSCProcessorPeak(const MSCProcessor *p) {
    return p ? atomic_load_explicit(&p->peak, memory_order_relaxed) : 0;
}
uint64_t MSCProcessorCycles(const MSCProcessor *p) {
    return p ? atomic_load_explicit(&p->cycles, memory_order_relaxed) : 0;
}
uint64_t MSCProcessorFaults(const MSCProcessor *p) {
    return p ? atomic_load_explicit(&p->faults, memory_order_relaxed) : 0;
}

typedef struct { float *data; uint32_t stride; uint32_t frames; } Channel;
static bool channels(const AudioBufferList *list, Channel result[2], uint32_t *count) {
    *count = 0;
    if (!list || list->mNumberBuffers > 2) return false;
    for (uint32_t b = 0; b < list->mNumberBuffers; b++) {
        const AudioBuffer *buffer = &list->mBuffers[b];
        uint32_t n = buffer->mNumberChannels;
        if (!n || *count + n > 2 || !buffer->mData ||
            buffer->mDataByteSize % (n * sizeof(float))) return false;
        for (uint32_t c = 0; c < n; c++) {
            result[*count] = (Channel){(float *)buffer->mData + c, n,
                                      buffer->mDataByteSize / (n * sizeof(float))};
            (*count)++;
        }
    }
    return *count > 0;
}

void MSCProcessorRender(MSCProcessor *p, const AudioBufferList *input, AudioBufferList *output) {
    if (!p || !output) return;
    // Core Audio input/output are separate. Clear every output before handling errors or underruns.
    for (uint32_t b = 0; b < output->mNumberBuffers; b++) {
        if (output->mBuffers[b].mData)
            memset(output->mBuffers[b].mData, 0, output->mBuffers[b].mDataByteSize);
    }
    Channel in[2], out[2];
    uint32_t ni = 0, no = 0;
    atomic_fetch_add_explicit(&p->cycles, 1, memory_order_relaxed);
    if (!channels(input, in, &ni) || ni != 2 || !channels(output, out, &no)) {
        atomic_fetch_add_explicit(&p->faults, 1, memory_order_relaxed);
        atomic_store_explicit(&p->peak, 0, memory_order_relaxed);
        return;
    }
    uint32_t frames = in[0].frames;
    if (in[1].frames != frames || out[0].frames != frames || (no == 2 && out[1].frames != frames)) {
        atomic_fetch_add_explicit(&p->faults, 1, memory_order_relaxed);
        atomic_store_explicit(&p->peak, 0, memory_order_relaxed);
        return;
    }
    const float target = atomic_load_explicit(&p->target, memory_order_relaxed);
    float peak = 0;
    for (uint32_t f = 0; f < frames; f++) {
        p->current += (target - p->current) * p->coefficient;
        float l = in[0].data[f * in[0].stride];
        float r = in[1].data[f * in[1].stride];
        l = isfinite(l) ? l * p->current : 0;
        r = isfinite(r) ? r * p->current : 0;
        if (no == 1) {
            out[0].data[f * out[0].stride] = 0.5f * (l + r);
        } else {
            out[0].data[f * out[0].stride] = l;
            out[1].data[f * out[1].stride] = r;
        }
        peak = fmaxf(peak, fmaxf(fabsf(l), fabsf(r)));
    }
    atomic_store_explicit(&p->peak, peak, memory_order_relaxed);
}

static OSStatus MSCAudioIOProc(AudioObjectID device, const AudioTimeStamp *now,
                      const AudioBufferList *input, const AudioTimeStamp *inputTime,
                      AudioBufferList *output, const AudioTimeStamp *outputTime, void *context) {
    (void)device; (void)now; (void)inputTime; (void)outputTime;
    MSCProcessorRender(context, input, output);
    return noErr;
}

OSStatus MSCProcessorRegister(AudioObjectID device, MSCProcessor *processor, AudioDeviceIOProcID *ioProc) {
    return AudioDeviceCreateIOProcID(device, MSCAudioIOProc, processor, ioProc);
}
