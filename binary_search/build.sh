arm-none-eabi-as -mcpu=cortex-m3 -mthumb -mapcs-32 -gstabs -ahls=./binary_search.lst -o ./binary_search.o ./binary_search.asm
arm-none-eabi-ld -v -T ./binary_search.ld -nostartfiles -o ./binary_search.elf ./binary_search.o
arm-none-eabi-objcopy -O binary ./binary_search.elf  ./binary_search.bin