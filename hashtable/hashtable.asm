@directives
    .thumb
    .syntax unified

@equates
    .equ    TABLE_SIZE,      500
    .equ    TABLE_PTR,       0x20001500
    .equ    ARRAY_PTR,       0x20000000
    .equ    STACKINIT,       0x20005000


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
@ Hash table with size n
@ Memory footprint
@ 4 Bytes:    Number of maximum iterations (depends on n, but is dynamically calculated when calling function f_full_init_table)
@ n bits (aligned to 4 Bytes)
@        :    Bitset to determine whether a given index in hashtable is filled
@ n * (4 + 4) Bytes
@        :    Actual keys and values stored first four bytes are for key, next 4 bytes for element content

@ Notes:
@ Labels starting with l are labels that are not supposed to be jumped to as subroutines
@ Labels starting with f are supposed to be interpreted as functions
@ Purpose of _start label is measuring the amount of collisions when reading all values in the hashtable
@     This is measured with different percentages of filled indices.
@     Note that in order to get the actual amount of reads one has to add the amount of actual
@     values in the hashtable on top of that number.
@
@ Contents of the hash table cannot be deleted yet. The hashtable cannot grow dynamically and
@     cloning ( or copying to an array ) is not possible either.
@
@ For the initialization of the hashtable one can either specify the maximum amount of collisions 
@   or by calling f_full_init_table the initialization is done with the highest value possible
@   ( which is just m = n / 2, where n is the size of the table and m is the maximum amount ).
@
@ TODO:
@ - Change data structure to support deletion of elements
@ - implement delete function
@ - implement to_array function
@ - write tests for all functionality
@ ------------------------------------------------------------------------------------------------------

_start:
        @ initialize HASH_TABLE with given size
        @ fill HASH_TABLE with random values
        LDR r0, =TABLE_SIZE
        LDR r1, =TABLE_PTR

        BL f_full_init_table

        LDR r8, =ARRAY_PTR


        LDR r4, =250
        BL f_test_suite

        EOR r5, r5
        LDR r4, =450
        BL f_test_suite

        EOR r5, r5
        LDR r4, =475
        BL f_test_suite

        EOR r5, r5
        LDR r4, =500
        BL f_test_suite

        EOR r5, r5

        BL f_table_amount_elements

        EOR r4, r4


        @ the following is for debugging purposes
        @LDR r2, =100
        @LDR r3, =555
        @BL f_table_set
        @LDR r2, =300
        @LDR r3, =666
        @BL f_table_set
        @LDR r2, =500
        @LDR r3, =777
        @BL f_table_set
        @LDR r2, =700
        @LDR r3, =888
        @BL f_table_set

        @EOR r3, r3
        @BL f_table_get




@ r0: size of table, r1: pointer to table, r4: amount of elements, r8: array ptr
@ r5: amount of collisions
f_test_suite:
        PUSH {r2, r3, r4, r6, r9, r10, r11, lr}
        BL f_full_init_table

        MOV r12, r4
        MOV r9, r8
        MOV r5, r4
        LDR r11, =314159265

l_element_fill_loop:
        MOV r3, r11
        BL f_randint
        MOV r11, r4, ROR 13
        MOV r3, r5
        MOV r2, r4

        BL f_table_set

        CMP r4, #0x00
        ITT EQ
        ADDEQ r11, #0x01
        BEQ l_element_fill_loop

        STR.W r2, [r9]
        ADD r9, #0x04
        SUB r5, #0x01
        CMP r5, #0x00
        BNE l_element_fill_loop

        @endloop

        BL f_table_amount_elements

        CMP r5, r12
        ITT CC
        ADDCC r11, #0x01
        BCC l_element_fill_loop


l_filled_hash_table:
        MOV r9, r8
        EOR r6, r6
        MOV r11, r4

l_element_get_loop:
        LDR r2, [r9]
        ADD r9, #0x04
        BL f_table_get
        CBZ r4, l_error_occured

        CMP r12, r3 @ test whether values are equal
        BNE l_error_occured

        ADD r6, r5
        ADD r11, #0x01
        SUB r12, #0x01
        CMP r12, #0x00
        BNE l_element_get_loop

        @endloop

        MOV r5, r6
        POP {r2, r3, r4, r6, r9, r10, r11, lr}

        BX lr


l_error_occured:
        ADD r0, #0x01
        B l_error_occured



@ calculate the maximum amount of iterations for given size
@ r0: size of table, r1: ptr to start of table
f_full_init_table:
        MOV r2, r0, LSR 1

@ r0: size of table, r1: ptr to start of table, r2: max iterations
f_init_table:
        STR.W r2, [r1]

        PUSH { r1, lr }
        ADD r1, #0x01
        LSR r2, r0, #0x05
        ADD r2, #0x01
        BL f_clear_words

        POP { r1, lr }
        BX lr



@ r0: size of table, r1: ptr to start of table, r2: key
@ return: r3: value, r4: bool that indicates whether found, r5: amount of collisions
f_table_get:
        @ 1. hash value, 2. check whether bit set, 3a. if not, r4=0, 3b. if yes loop with quadratic probing
        PUSH {r6, r7, r9, r10, r11, r12, lr}
        MOV r9, r2
        MOV r10, r0
        BL f_modulo


        MOV r4, r1
        ADD r4, #0x04

        MOV r5, r11
        BL f_getbit
        LDR r12, =#0x00
        CBZ r6, l_not_in_table

        @ check whether keys are same
        MOV r6, r0, LSR 5
        ADD r6, #0x01
        LSL r6, #0x02
        ADD r6, r4
        MOV r7, r6

        ADD r9, r6, r5, LSL 3

        LDR r10, [r9]
        CMP r10, r2
        BEQ l_in_table

        @ resolve collision
        @ r3: amount of iters, r4: ptr to bitset, r5: index, r6: pointer to start of kv-pairs r9: pointer onto current value

        LDR r12, =#0x01
        LDR r3, [r1]

l_collision_resolve_loop_get:
        MLA r5, r12, r12, r5
        CMP r5, r0

        BCC l_no_mod
        MOV r9, r5
        MOV r10, r0
        BL f_modulo
        MOV r5, r11

l_no_mod:
        BL f_getbit
        CBZ r6, l_not_in_table

        @ bit is set, check contents
        ADD r9, r7, r5, LSL 3
        LDR r10, [r9]
        CMP r10, r2
        BEQ l_found_with_collisions

        @ update counters
        ADD r12, #0x01
        SUB r3, #0x01
        CMP r3, #0x00
        BNE l_collision_resolve_loop_get

        @ endloop
        B l_not_in_table

l_found_with_collisions:
        MOV r5, r12
l_in_table:
        CMP r12, #0x00
        IT EQ
        LDREQ r5, =#0x00
        ADD r9, #0x04
        LDR r3, [r9]
        LDR r4, =#0x01
        B l_ret_from_get

l_not_in_table:
        MOV r5, r12
        EOR r4, r4

l_ret_from_get:
        POP {r6, r7, r9, r10, r11, r12, lr}
        BX lr


@ r0: size of table, r1: ptr to start of table, r2: key, r3: value
@ return: r4: bool that indicates whether able to insert
f_table_set:
        PUSH {r5, r6, r7, r8, r9, r10, r11, r12, lr}
        MOV r9, r2
        MOV r10, r0
        BL f_modulo
        @ r11 now "hashed"

        ADD r4, r1, #0x04
        MOV r5, r11
        BL f_getbit

        MOV r7, r0, LSR 5
        ADD r7, #0x01
        LSL r7, #0x02
        ADD r7, r4
        @ r7 now pointer on start of kv-pairs

        ADD r8, r7, r5, LSL 3
        CBZ r6, l_insert

        @ check whether contents equal
        LDR r9, [r8]
        CMP r2, r9
        BEQ l_insert_content

        @ resolve collision
        LDR r12, =#0x01
        LDR r4, [r1]

l_collision_resolve_loop_set:
        MLA r5, r12, r12, r5
        CMP r5, r0

        BCC l_no_mod_needed
        MOV r9, r5
        MOV r10, r0
        BL f_modulo
        MOV r5, r11

l_no_mod_needed:
        MOV r11, r4
        ADD r4, r1, #0x04
        BL f_getbit
        MOV r4, r11

        ADD r8, r7, r5, LSL 3
        CBZ r6, l_insert

        @ bit is set, check contents

        LDR r9, [r8]
        CMP r9, r2
        BEQ l_insert_content

        @ update counters
        ADD r12, #0x01
        SUB r4, #0x01
        CMP r4, #0x00
        BNE l_collision_resolve_loop_set

        @ endloop

        EOR r4, r4
        B l_ret_from_set



l_insert:
        MOV r12, r3
        MOV r3, r5
        ADD r4, r1, #0x04
        BL f_setbit

        STR r2, [r8]
        MOV r3, r12
l_insert_content:
        ADD r8, #0x04
        STR.W r3, [r8]
        LDR r4, =#0x01
l_ret_from_set:
        POP {r5, r6, r7, r8, r9, r10, r11, r12, lr}
        BX lr


@ r0: size of table, r1: ptr to start of table
f_table_clear:
        PUSH {r1, lr}
        ADD r1, #0x01
        LSR r2, r0, #0x05
        ADD r2, #0x01
        BL f_clear_words

        POP {r1, lr}
        BX lr

@ r0: size of table, r1: ptr to start of table
@ return: r5: amount of elements
f_table_amount_elements:
        PUSH { r3, r4, r6, r7, r8 }
        EOR r5, r5

        CMP r0, #0x00
        BEQ ret_from_amount_elements

        MOV r7, r0

        MOV r3, r1
        ADD r3, #0x04

l_word_check_loop:
        CBZ r7, ret_from_amount_elements
        LDR r4, [r3]
        ADD r3, #0x04

        LDR r8, =#0x20
        CMP r7, #0x20
        BCS l_bit_check_loop
        MOV r8, r7

l_bit_check_loop:
        ANDS r6, r4, #0x01
        LSR r4, 1
        ADD r5, r6

        SUB r8, #0x01
        SUB r7, #0x01
        CBZ r7, ret_from_amount_elements

        CMP r4, #0x00
        ITT EQ
        SUBEQ r7, r8
        BEQ l_word_check_loop

        B l_bit_check_loop


ret_from_amount_elements:
        POP { r3, r4, r6, r7, r8 }
        BX lr



@---------------------------------------------------------------------------------------------
@ external algorithms


@ generate a random integer using "xorshift"
@ r3: random seed
@ return: r4: "random" value
f_randint:
        MOV r4, r3
        EOR r4, r4, r4, LSL 13
        EOR r4, r4, r4, LSR 17
        EOR r4, r4, r4, LSL 5
        BX lr


@ r9: value, r10: divisor
@ return r11: result
f_modulo:
        PUSH {r12}
        UDIV r11, r9, r10
        MUL r12, r10, r11
        SUB r11, r9, r12
        POP {r12}
        BX lr

@-----------------------------------------------------------------------------------
@ bit manipulation functions

@ r2: amount_words, r1: ptr
f_clear_words:
        PUSH {r6, r7}
        MOV r7, r1
        EOR r6, r6

l_clear_loop:
        STR.W r6, [r7]
        ADD r7, #0x04
        SUB r2, #0x01
        CMP r2, #0x00
        BNE l_clear_loop

        @ endloop
        POP {r6, r7}
        BX lr


@ r3: index, r4: pointer to first bit block
f_setbit:
        PUSH {r5,r6,r8}

        MOV r6, r3, LSR 5
        ADD r5, r4, r6, LSL 2
        AND r6, r3, #0x1F
        LDR r8, =#0x01
        LSL r8, r6
        MOV r6, r8
        LDR r8, [r5]
        ORR r8, r6
        STR.W r8, [r5]

        POP {r5, r6,r8}
        BX lr


@ r5: index, r4: pointer
@ return: r6: bool set
f_getbit:
        PUSH  {r5, r7, r8}
        MOV r6, r5, LSR 5
        MOV r7, r5
        ADD r5, r4, r6, LSL 2
        AND r6, r7, #0x1F
        LDR r8, [r5]
        LSR r8, r6
        LDR r6, =#0x01

        AND r8, #0x01
        CMP r8, #0x00
        BNE l_not_zero
        EOR r6, r6

l_not_zero:
        POP   {r5, r7, r8}
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
        STR.W r8, [r5]
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
