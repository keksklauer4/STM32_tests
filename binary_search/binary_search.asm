@directives
    .thumb
    .syntax unified

@ create list, use dma and interrupts to copy somewhere else, then do binary search

@equates
    .equ    SIZE,               0xFF
    .equ    SRAM,               0x20000000
    .equ    L0,                 0x20000000
    .equ    L1,                 0x20000800
    .equ    SEARCH,             0x68

    .equ    DMA_CALLBACK_PTR,    0x20001000

    .equ    STACKINIT,          0x20005000

    .equ    CLOCK_EN_REG,      0x40021014 @ RCC_AHBENR (peripheral clock enable register)
    .equ    GPIOC_CRH,          0x40011004
    .equ    GPIOC_ODR,          0x4001100C
    .equ    DMA_CPAR1,          0x40020010  @ source address
    .equ    DMA_CMAR1,          0x40020014  @ destination address
    .equ    DMA_CNDTR1,         0x4002000C  @ copy size
    .equ    DMA_CCR1,            0x40020008  @ dma configuration register


    .equ    DMA_CONFIG_FLAGS,    0b111101011010010 @configuration of dma channel



@ Vectors (taken from somewhere else)
vectors:
        .word STACKINIT         @ stack pointer value when stack is empty
        .word _start + 1        @ reset vector (manually adjust to odd for thumb)
        .word _nmi_handler + 1  @
        .word _hard_fault  + 1  @
        .word _memory_fault + 1 @
        .word _bus_fault + 1    @
        .word _usage_fault + 1  @


@ ------------------------------------------------------------------------------------------------------
_start:
            LDR r0, =L0
            LDR r1, =SIZE
            EOR r2, r2
            BL f_create_list
            BL f_invoke_dma_handler

@ ------------------------------------------------------------------------------------------------------
f_create_list:
            STR.W r1, [r0]
            ADD r0, #0x04

l_list_creation_loop:
            STR.W r2, [r0]
            ADD r0, #0x04
            ADD r2, #0x04
            CMP r2, r1, LSL 0x02
            BNE l_list_creation_loop

            BX lr

@ ------------------------------------------------------------------------------------------------------
f_binary_search:
            @ r0 : lower end
            @ r1 : upper end
            @ r2 : value to be searched for
            @ r3 : pointer to base of list

            @ get element at middle
            MOV r4, r0
            ADD r4, r1
            LSR r4, #0x01
            ADD r6, r3, r4, LSL #0x02

            LDR r5, [r6]
            CMP r5, r2
            BEQ l_value_found
            BCS l_lower_bound
            @ fallthrough: Carry Clear (upper bound)
            ADD r4, #0x01
            MOV r0, r4
            B f_binary_search
l_value_found:
            BX lr       @ return to saved program counter
l_lower_bound:
            SUB r4, #0x01
            MOV r1, r4
            B f_binary_search

@ ------------------------------------------------------------------------------------------------------
f_invoke_dma_handler:
            @ enable DMA1 clock
            @ LDR r1, =CLOCK_EN_REG
            @ LDR r0, [r1]
            @ ORR r0, #0x01
            @ STR.W r0, [r1]

            @ set source address
            LDR r0, =L0
            LDR r1, =DMA_CPAR1
            STR.W r0, [r1]

            @ set destination address
            LDR r0, =L1
            ADD r1, #0x04
            STR.W r0, [r1]

            @ set size
            LDR r0, =SIZE
            LDR r1, =DMA_CNDTR1
            STR.W r0, [r1]

            @ set configuration of channel
            LDR r0, =DMA_CONFIG_FLAGS
            LDR r1, =DMA_CCR1
            STR.W r0, [r1]

            @ set callback
            LDR r0, =f_dma_callback
            LDR r1, =DMA_CALLBACK_PTR
            STR.W r0, [r1]


            @ enable dma channel
            LDR r0, =DMA_CONFIG_FLAGS
            LDR r1, [r0]
            ORR r1, #0x01
            STR.W r1, [r0]

            @ enable interrupts and wait for int
            CPSIE i
            WFI
            LDR r9, =#0x88


@ ------------------------------------------------------------------------------------------------------
f_dma_callback:
            @ call binary search
            LDR r0, =#0x04
            LDR r3, =L1 @ TODO: actually L1 instead of L0
            LDR r1, [r3]
            ADD r1, #0x04

            LDR r2, =SEARCH

            B f_binary_search

@ ------------------------------------------------------------------------------------------------------
_dummy:
_nmi_handler:
_hard_fault:
_memory_fault:
_bus_fault:
_usage_fault:
        B f_dma_callback
        add r0, 1
        add r1, 1
        b _dummy