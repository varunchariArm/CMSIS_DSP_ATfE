#include <stdio.h>
#include "arm_math.h"
#define FFT_SIZE        1024
#define SAMPLE_RATE     48000
float32_t inputSignal[FFT_SIZE];
float32_t fftOutput[FFT_SIZE];

int main(void){
    arm_rfft_fast_instance_f32 fftInstance;
    for (int i = 0; i < FFT_SIZE; i++) {
        inputSignal[i] = arm_sin_f32(2 * PI * 1000 * i / SAMPLE_RATE);  // 1 kHz sine wave
    }
    // Initialize the FFT
    arm_rfft_fast_init_f32(&fftInstance, FFT_SIZE);

    // Run FFT
    arm_rfft_fast_f32(&fftInstance, inputSignal, fftOutput, 0);  // 0 = forward FFT

    float32_t fftMagnitude[FFT_SIZE / 2];
    for (int i = 0; i < FFT_SIZE / 2; i++) {
        float32_t real = fftOutput[2 * i];
        float32_t imag = fftOutput[2 * i + 1];
        fftMagnitude[i] = sqrtf(real * real + imag * imag);
        printf("fftMagnitude = %f \n", fftMagnitude[i]);
    }
    return 0;

}