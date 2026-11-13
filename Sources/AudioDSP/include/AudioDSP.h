#ifndef MSC_AUDIO_DSP_H
#define MSC_AUDIO_DSP_H
#include <CoreAudio/CoreAudio.h>
#include <stdbool.h>
#include <stdint.h>

typedef struct MSCProcessor MSCProcessor;
MSCProcessor *MSCProcessorCreate(double sampleRate, float initialGain);
void MSCProcessorDestroy(MSCProcessor *processor);
void MSCProcessorSetGain(MSCProcessor *processor, float gain);
float MSCProcessorPeak(const MSCProcessor *processor);
uint64_t MSCProcessorCycles(const MSCProcessor *processor);
uint64_t MSCProcessorFaults(const MSCProcessor *processor);
// All buffers must contain native Float32 PCM. Supports stereo input and mono/stereo output.
// Called by Core Audio only after control-thread stream validation.
void MSCProcessorRender(MSCProcessor *processor, const AudioBufferList *input, AudioBufferList *output);
OSStatus MSCProcessorRegister(AudioObjectID device, MSCProcessor *processor, AudioDeviceIOProcID *ioProc);
#endif
