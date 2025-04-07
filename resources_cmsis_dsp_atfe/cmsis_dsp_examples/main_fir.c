#include <stdio.h>
#include "arm_math.h"

#define BLOCK_SIZE 32
#define NUM_TAPS 5

float32_t inputSignal[BLOCK_SIZE] = {
    0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8,
    0.9, 1.0, 1.1, 1.2, 1.3, 1.4, 1.5, 1.6,
    1.7,1.8,1.9,2.0,2.1,2.2,2.3,2.4,2.5,2.6,
    2.7,2.8,2.9,3.0,3.1,3.2
};

float32_t firCoeffs[NUM_TAPS] = { 0.2, 0.1, 0.0, -0.1, -0.2 };
float32_t outputSignal[BLOCK_SIZE];

int main() {
    printf("hello\n");
    arm_fir_instance_f32 firInstance = {0};
    printf("creation done\n");
    float32_t state[BLOCK_SIZE + NUM_TAPS - 1];

    arm_fir_init_f32(&firInstance, NUM_TAPS, firCoeffs, state, BLOCK_SIZE);
    printf("init done\n");

    arm_fir_f32(&firInstance, inputSignal, outputSignal, BLOCK_SIZE);
    printf("fir done\n");

    printf("Filtered Output:\n");
    for (int i = 0; i < BLOCK_SIZE; i++) {
        printf("%f\n", outputSignal[i]);
    }

    return 0;
}