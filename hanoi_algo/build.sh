#!/bin/bash

arm-none-eabi-as -mcpu=cortex-m3 -mthumb -mapcs-32 -gstabs -ahls=hanoi.lst -o hanoi.o hanoi.asm

arm-none-eabi-ld -v -T hanoi.ld -nostartfiles -o hanoi.elf hanoi.o

arm-none-eabi-objcopy -O binary hanoi.elf  hanoi.bin
