@directives
    .thumb
    .syntax unified

@equates
    .equ    HASH_ALGO,       0x15
    .equ    RANDOM_ALGO,     0x10
    .equ    TABLE_SIZE,      0x200
    .equ    TABLE_PTR,       0x200000


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
Hash table with size n (and element length p)
Memory footprint
4 Bytes:    Number of maximum iterations (depends on n, but is dynamically calculated when calling function f_full_init_table)
n bits (aligned to 4 Bytes)
       :    Bitset to determine whether a given index in hashtable is filled
n * (4 + p) Bytes
       :    Actual keys and values stored first four bytes are for key, next p bytes for element content


@ ------------------------------------------------------------------------------------------------------

_start:
        @ initialize HASH_TABLE with given size
        @ fill HASH_TABLE with random values
        LDR r0, =TABLE_SIZE
        LDR r1, =TABLE_PTR

        BL f_init_table
        


@ calculate the maximum amount of iterations for given size
@ r0: size of table, r1: ptr to start of table
f_full_init_table:
        PUSH {lr, r3, r4, r5, r6, r10}

        @ free enough space for temporary bitset
        LSR r2, r0, #0x05
        ADD r2, #0x01
        BL f_clear_words


        EOR r2, r2
        LDR r4, r1
        LDR r10, r0

l_square_loop:
        ADD r2, #0x01
        UMULL r9, r11, r2, r2
        BL f_modulo
        LDR r5, r11
        BL f_getbit
        CBNZ r6, l_found_bit_set
        LDR r3, r5
        BL f_setbit

        SUBS r10, #0x01
        BNZ l_square_loop



        @ endloop
l_found_bit_set:
        SUB r2, #0x01
        POP {lr, r3, r4, r5, r6, r10}
        

@ r0: size of table, r1: ptr to start of table, r2: max iterations
f_init_table:



@ r0: size of table, r1: ptr to start of table, r2: key
@ return: r3: value, r4: bool that indicates whether found
f_table_get:

@ r0: size of table, r1: ptr to start of table, r2: key, r3: value
@ return: r4: bool that indicates whether able to insert
f_table_set:

@
f_table_probe:

@ r0: size of table, r1: ptr to start of table
f_table_clear:




@---------------------------------------------------------------------------------------------
@ external algorithms


@ generate a random integer
f_randint:


@ r7: value
f_hash_algoithm_mod:


@ r9: value, r10: divisor
@ return r11: result
f_modulo:
        PUSH {r12, r13}
        UDIV r11, r9, r10
        UMULL r12, r13, r9, r11
        SUB r11, r12, r11
        POP {r12, r13}
        BX lr





@-----------------------------------------------------------------------------------
@ bit manipulation functions

@ r2: amount_words, r1: ptr
f_clear_words:
        PUSH {r6, r7}
        LDR r7, r1
        EOR r6, r6

l_clear_loop:
        STR r6, [r7]
        ADD r7, #0x04
        SUB r2, #0x01
        CBNZ r2, l_clear_loop

        @ endloop
        POP {r6, r7}


@ r3: index, r4: pointer to first bit block
f_setbit:
        PUSH {r5,r6,r8}

        LSR r6, r3, 5
        ADD r5, r4, r6, LSL 2
        AND r6, #0x1F
        LDR r8, =#0x01
        LSL r8, r6
        LDR r6, r8
        LDR r8, [r5]
        ORR r8, r6
        STR r8, [r5]

        POP {r5, r6,r8}
        BX lr

@ r5: index, r4: pointer
@ return: r6: bool set
f_getbit:
        PUSH  {r5, r8}
        LSR r6, r3, 5
        ADD r5, r4, r6, LSL 2
        AND r6, #0x1F
        LDR r8, [r5]
        LSR r8, r6
        LDR r6, =#0x01

        ANDS r8, #0x01
        CBNZ r6, l_not_zero
        EOR r6, r6

l_not_zero:
        POP   {r5, r8}
        BX lr


f_clear_bit:
        PUSH {r5,r6,r8}

        LSR r6, r3, 5
        ADD r5, r4, r6, LSL 2
        AND r6, #0x1F
        LDR r8, =#0x01
        LSL r8, r6
        EOR r6, r6
        SUB r6, #0x01
        EOR r6, r8
        LDR r8, [r5]
        AND r8, r6
        STR r8, [r5]
        POP {r5, r6,r8}

        BX lr



_dummy:                        @ if any int gets triggered, just hang in a loop
_nmi_handler:
_hard_fault:
_memory_fault:
_bus_fault:
_usage_fault:
        add r0, 1
        add r1, 1
        b _dummy
