#ifndef MSC_AUDIO_DSP_H
#define MSC_AUDIO_DSP_H
#include <CoreAudio/CoreAudio.h>
#include <stdbool.h>
#include <stdint.h>

typedef struct MSCProcessor MSCProcessor;
MSCProcessor *MSCProcessorCreate(double sampleRate, float initialGain);
void MSCProcessorDestroy(MSCProcessor *processor);
void MSCProcessorSetGain(MSCProcessor *processor, float gain);
// Single control-thread producer; render is the sole consumer. No allocation/locks in render.
// Ten octave bands 31.25–16000 Hz, ±12 dB, preamp −24…0 dB. Out-of-Nyquist bands bypass.
void MSCProcessorSetEqualizer(MSCProcessor *processor, bool enabled, const float *gains,
                             uint32_t count, float preampDB, bool automaticHeadroom);
uint64_t MSCProcessorClippedFrames(const MSCProcessor *processor);
float MSCProcessorPeak(const MSCProcessor *processor);
uint64_t MSCProcessorCycles(const MSCProcessor *processor);
uint64_t MSCProcessorFaults(const MSCProcessor *processor);
// All buffers must contain native Float32 PCM. Supports stereo input and mono/stereo output.
// Called by Core Audio only after control-thread stream validation.
void MSCProcessorRender(MSCProcessor *processor, const AudioBufferList *input, AudioBufferList *output);
OSStatus MSCProcessorRegister(AudioObjectID device, MSCProcessor *processor, AudioDeviceIOProcID *ioProc);
#endif
