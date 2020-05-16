#!/bin/bash

arm-none-eabi-as -mcpu=cortex-m3 -mthumb -mapcs-32 -gstabs -ahls=hashtable.lst -o ./hashtable.o ./hashtable.asm

arm-none-eabi-ld -v -T ./hashtable.ld -nostartfiles -o ./hashtable.elf ./hashtable.o

arm-none-eabi-objcopy -O binary ./hashtable.elf  ./hashtable.bin
