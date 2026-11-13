#include "Equalizer.h"
#include <math.h>
#include <string.h>

static const double centers[MSC_EQ_BANDS] = {31.25, 62.5, 125, 250, 500, 1000, 2000, 4000, 8000, 16000};
static double bounded(float value, double low, double high) {
    return isfinite(value) ? fmax(low, fmin(high, value)) : 0;
}
static MSCEQCoefficients peaking(double sampleRate, double frequency, double db) {
    // A band at/above Nyquist is an identity, never a folded/aliased filter.
    if (frequency >= sampleRate * 0.49 || fabs(db) < 1e-8)
        return (MSCEQCoefficients){1, 0, 0, 0, 0};
    const double a = pow(10, db / 40), omega = 2 * M_PI * frequency / sampleRate;
    const double alpha = sin(omega) / (2 * 1.4), c = cos(omega), a0 = 1 + alpha / a;
    // RBJ peaking EQ, Q=1.4, direct form II transposed at render time.
    return (MSCEQCoefficients){(1 + alpha * a) / a0, -2 * c / a0,
        (1 - alpha * a) / a0, -2 * c / a0, (1 - alpha / a) / a0};
}
static double responseDB(const MSCEQConfig *config, double sampleRate, double frequency) {
    const double w = 2 * M_PI * frequency / sampleRate;
    const double c = cos(w), s = sin(w), c2 = cos(2*w), s2 = sin(2*w);
    double db = 0;
    for (int i = 0; i < MSC_EQ_BANDS; i++) {
        const MSCEQCoefficients b = config->bands[i];
        double nr = b.b0 + b.b1*c + b.b2*c2, ni = -b.b1*s - b.b2*s2;
        double dr = 1 + b.a1*c + b.a2*c2, di = -b.a1*s - b.a2*s2;
        db += 10 * log10(fmax(1e-30, (nr*nr + ni*ni) / fmax(1e-30, dr*dr + di*di)));
    }
    return db;
}
bool MSCEQInit(MSCEQ *eq, double sampleRate) {
    memset(eq, 0, sizeof(*eq));
    eq->sampleRate = sampleRate;
    eq->back = 0; eq->front = 1;
    atomic_init(&eq->middle, 2);
    eq->fadeLength = (unsigned)fmax(1, sampleRate * 0.02);
    return atomic_is_lock_free(&eq->middle);
}
void MSCEQPublish(MSCEQ *eq, bool enabled, const float *gains, uint32_t count, float preamp, bool automatic) {
    MSCEQConfig config = {0};
    config.enabled = enabled;
    for (unsigned i = 0; i < MSC_EQ_BANDS; i++)
        config.bands[i] = peaking(eq->sampleRate, centers[i], gains && i < count ? bounded(gains[i], -12, 12) : 0);
    double headroom = 0;
    if (automatic && enabled) {
        // Dense logarithmic sweep plus exact centers; estimate, not a true-peak limiter.
        for (unsigned i = 0; i <= 1024; i++) {
            double frequency = 10 * pow(eq->sampleRate * 0.499 / 10, i / 1024.0);
            headroom = fmax(headroom, responseDB(&config, eq->sampleRate, frequency));
        }
        for (unsigned i = 0; i < MSC_EQ_BANDS; i++)
            if (centers[i] < eq->sampleRate * 0.49)
                headroom = fmax(headroom, responseDB(&config, eq->sampleRate, centers[i]));
        if (headroom > 0.01) headroom += 1; // Additional 1 dB for grid/transient margin.
    }
    config.preamp = pow(10, (bounded(preamp, -24, 0) - headroom) / 20);
    eq->slots[eq->back] = config;
    unsigned previous = atomic_exchange_explicit(&eq->middle, eq->back | 4u, memory_order_acq_rel);
    eq->back = previous & 3u;
}
void MSCEQBeginBlock(MSCEQ *eq) {
    // Keep only the latest pending configuration while a transition completes.
    if (eq->fading || !(atomic_load_explicit(&eq->middle, memory_order_acquire) & 4u)) return;
    unsigned previous = atomic_exchange_explicit(&eq->middle, eq->front, memory_order_acq_rel);
    eq->front = previous & 3u;
    memset(&eq->next, 0, sizeof(eq->next));
    eq->next.config = eq->slots[eq->front];
    eq->fadeFrame = 0;
    eq->fading = true;
}
static double processChannel(MSCEQBank *bank, double input, unsigned channel) {
    if (!bank->config.enabled) return input;
    double value = input * bank->config.preamp;
    for (unsigned i = 0; i < MSC_EQ_BANDS; i++) {
        MSCEQCoefficients b = bank->config.bands[i];
        double output = b.b0 * value + bank->z1[channel][i];
        double z1 = b.b1 * value - b.a1 * output + bank->z2[channel][i];
        double z2 = b.b2 * value - b.a2 * output;
        // Contain non-finite state; flush extremely small tails to avoid denormals.
        bank->z1[channel][i] = isfinite(z1) && fabs(z1) > 1e-24 ? z1 : 0;
        bank->z2[channel][i] = isfinite(z2) && fabs(z2) > 1e-24 ? z2 : 0;
        value = isfinite(output) ? output : 0;
    }
    return value;
}
bool MSCEQProcess(MSCEQ *eq, float *left, float *right) {
    bool protect = eq->current.config.enabled || (eq->fading && eq->next.config.enabled);
    double l = processChannel(&eq->current, *left, 0), r = processChannel(&eq->current, *right, 1);
    if (eq->fading) {
        double nl = processChannel(&eq->next, *left, 0), nr = processChannel(&eq->next, *right, 1);
        double mix = (double)++eq->fadeFrame / eq->fadeLength;
        l += (nl - l) * mix; r += (nr - r) * mix;
        if (eq->fadeFrame >= eq->fadeLength) { eq->current = eq->next; eq->fading = false; }
    }
    *left = (float)l; *right = (float)r;
    return protect;
}
