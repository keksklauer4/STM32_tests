@directives
    .thumb
    .syntax unified

@ each tower has a size of HANOI_HEIGHT
@ first byte of each tower holds the amount of values on that tower

@equates
    .equ    HANOI_HEIGHT,       0x15
    .equ    SRAM,               0x20000000
    .equ    T0,                 0x20000010
    .equ    T1,                 0x20000060
    .equ    T2,                 0x200000B0

    .equ STACKINIT,             0x20005000

    .equ    CLOCK_EN_REG2,       0x40021018 @ RCC_APB2ENR (peripheral clock enable register 2)
    .equ    GPIOC_CRH,          0x40011004
    .equ    GPIOC_ODR,          0x4001100C


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
            BL f_turn_on_led

            BL f_initialize_memory
            BL f_create_tower

            @ prepare registers for Hanoi
            LDR r0, =T0
            LDR r1, =T1
            LDR r2, =T2
            LDR r3, =HANOI_HEIGHT

            BL f_hanoi_algo
            BL _usage_fault


@ ------------------------------------------------------------------------------------------------------
f_initialize_memory:
            LDR r0, =SRAM
            LDR r1, =#0x00
            LDR r2, =#0x200000FF

l_initilization_loop:
            STR r1, [r0]
            ADD r0, #0x01    @ increment pointer to SRAM location
            CMP r0, r2
            BNE l_initilization_loop

            @ endloop
            BX lr
@ ------------------------------------------------------------------------------------------------------

f_create_tower:
            @ Tower is created in T0
            LDR r0, =T0
            LDR r1, =HANOI_HEIGHT

l_tower_filling_loop:
            STR r1, [r0]
            SUBS r1, #0x01
            ADD r0, #0x01
            CMP r1, #0x00
            BNE l_tower_filling_loop @ stop at the top of the tower

            @ endloop
            BX lr

@ ------------------------------------------------------------------------------------------------------
f_hanoi_algo:
            @ if n = 1 jump to move upper plate
            CMP r3, #0x01
            BEQ f_move_upper_plate @ will ret from current function

            @ general case
            @ swap destination location and temp location
            MOV r8, r2              @ register 8 will only be used for this purpopse
            MOV r2, r1
            MOV r1, r8

            @ call f_hanoi_algo for n-1 to move upper (n-1) plates to temporary location
            SUB r3, 0x01        @ n = n - 1
            PUSH {lr}           @ save Link Register for return
            BL f_hanoi_algo

            @ now move plate with value n
            MOV r8, r2
            MOV r2, r1
            MOV r1, r8

            BL f_move_upper_plate


            @ now move (n-1) plates from temporary location onto destination location
            MOV r8, r0
            MOV r0, r1
            MOV r1, r8

            BL f_hanoi_algo

            MOV r8, r0
            MOV r0, r1
            MOV r1, r8
            ADD r3, #0x01

            POP {lr}
            BX lr

@ ------------------------------------------------------------------------------------------------------
f_move_upper_plate:
            @ r0 from tower
            @ r2 to tower
            PUSH {r0, r2, r4, r5}
            LDR r4, [r0] @ obtain amount of values on "from" tower
            AND r4, r4, #0xFF
            ADD r0, r4    @ set pointer to value to be copied
            LDR r4, [r0]

            @ TODO: not needed
            LDR r5, =#0x00
            STR r5, [r0]
            @@@

            LDR r5, [r2] @ obtain amount of values on "to" tower
            AND r5, r5, #0xFF
            ADD r2, r5
            ADD r2, #0x01
            STR r4, [r2]

            POP {r0, r2, r4, r5}
            PUSH {r5}
            LDR r5, [r0]
            SUB r5, #0x01
            STR r5, [r0]
            LDR r5, [r2]
            ADD r5, #0x01
            STR r5, [r2]
            POP {r5}
            BX lr

@ ------------------------------------------------------------------------------------------------------
f_turn_on_led:
            LDR r1, =CLOCK_EN_REG2 @enable clock for io ports
            LDR r0, [r1]
            ORR r0, r0, 0x1fc
            STR r0, [r1]

            LDR   r1, =GPIOC_CRH      @ Address for port c control register
            LDR   r0, [r1]
            STR   r0, [r1]            @ Write to contorl register

            LDR   r1, =GPIOC_ODR      @ Address for port c output data register
            MOV     r0, #0x0A00         @ Value for port c
            STR     r0, [r1]            @ Write value
            BX lr
@ ------------------------------------------------------------------------------------------------------

_dummy:                        @ if any int gets triggered, just hang in a loop
_nmi_handler:
_hard_fault:
_memory_fault:
_bus_fault:
_usage_fault:
        add r0, 1
        add r1, 1
        b _dummy
