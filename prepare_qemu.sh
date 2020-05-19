#!/bin/bash
# run as admin

sudo apt-get install git make gdb gcc g++

cd ..

git clone https://github.com/beckus/qemu_stm32.git

cd qemu_stm32
./configure --enable-debug --target-list="arm-softmmu" --disable-werror

make

cd ..

# do not delete qemu_stm32 since it is not installed

sudo apt-get install gcc-arm-none-eabi

