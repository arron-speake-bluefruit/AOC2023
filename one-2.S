.extern exit
.extern print_unsigned
.extern open_file
.extern close_file
.extern read_byte_from_file

.global _start

.section .text

/*
To solve this problem, we need to scan through each line and find numeric string, the strings we
recognise are:
- single digits ("0", "1", ..., "8", and "9")
- digit names ("zero", "one", "two", ..., "eight", "nine")

We can run an FSM with the file as input, which may produce digits or a 'stop' as output. See the
parser_fsm_* symbols defined in .rodata below.
*/

/*
functions:
    state_machine_step(STATE, CHAR) -> (STATE, OUTPUT):
        // given the current state and incoming input, look up the next state and the output to emit
        INPUT = lookup CHAR in input translation table
        STATE = lookup (STATE, INPUT) in state transition table
        OUTPUT = lookup (STATE, INPUT) in output table
        return

open FILE for reading

set STATE to 0 (start)

set SUM to 0 (sum is the accumulated value from ever line parsed so far)

set FIRST-DIGIT to 10 (the first digit seen on a line, a value >=10 mean no digit has been seen yet)

set CURRENT-DIGIT to 0 (the most recently seen digit)

for CHAR in FILE:
    if FILE exhausted, break

    (STATE, OUTPUT) = state_machine_step(STATE and CHAR)

    if output is digit (< 10):
        set current digit to numeric value
        if first digit is 10 (magic number):
            set first digit to current digit
    else if output is newline (== 10):
        concat first & current digit to a new number (first + 10*current)
        increment sum by new number

close FILE

print SUM

exit
*/

/**
 * Return the next state & associated output given a state and input.
 * rdi: state
 * rsi: ASCII character input
 * Returns next state (rax) and associated output (rdx).
 */
state_machine_step:
    /* lookup CHAR in input translation table, saved in RAX */
    lea parser_fsm_input_lookup(%rip), %r11 /* base address */
    add %rsi, %r11 /* offset into array */
    xor %rcx, %rcx /* clear RCX for subsequent byte-load */
    mov (%r11), %cl /* load single byte int CL */

    /* calculate array offset for FSM tables */
    mov $27, %rax /* row width of both tables */
    mul %rdi /* convert state index into row offset in RAX */
    add %rax, %rcx /* add column offset, give specific byte offset into table in RCX */

    /* lookup (STATE, INPUT) in state transition table */
    lea parser_fsm_transition_table(%rip), %r11 /* base address */
    add %rcx, %r11 /* offset into array */
    xor %rax, %rax
    mov (%r11), %al /* load single byte int AL */

    /* lookup (STATE, INPUT) in output table */
    lea parser_fsm_output_table(%rip), %r11 /* base address */
    add %rcx, %r11 /* offset into array */
    xor %rdx, %rdx
    mov (%r11), %dl /* load single byte int DL */

    /* return state and output lookups in RAX and RDX */
    ret

_start:
    lea input_path(%rip), %rdi
    call open_file
    mov %rax, %rbx /* preserve the file descriptor */

    mov $0, %r12 /* move 0 into SUM accumulator */
    mov $10, %r13 /* move magic number 10 into FIRST-DIGIT register */
    mov $0, %r14 /* move 0 into CURRENT-DIGIT register */
    mov $0, %r15 /* move 0 (START) into STATE register */

    _start__while_file_not_empty:
        mov %rbx, %rdi /* prepare to read from the input data file */
        call read_byte_from_file /* status -> RAX, byte -> RDX */

        /* check if the read succeeded */
        mov $1, %rdi
        cmp %rax, %rdi /* see below & function docs in common.S */
        jne _start__read_failed /* if we failed to load a byte, jump to end */

        /* get the next state and output given the current state and input */
        mov %r15, %rdi
        mov %rdx, %rsi
        call state_machine_step
        mov %rax, %r15 /* update the STATE register with subsequent state */

        /* check output (read char) is ASCII 10 '\n' */
        cmp $10, %rdx
        je _start__char_is_newline /* if so, handle a newline! */
        ja _start__while_file_not_empty /* not a newline or digit, move on to next char */

        /* char is a digit, the value is in RDI. */
        mov %rdx, %r14 /* store the value in the current digit register */
        cmp $10, %r13 /* compare first digit against 10 */
        jne _start__while_file_not_empty /* already seen a digit, nothing more to do */
        mov %r14, %r13 /* the current digit is the first digit */
        /* move onto next character */
        jmp _start__while_file_not_empty

        _start__char_is_newline:
            /* concatenate first and last digits */
            mov $10, %rax
            mul %r13 /* rax = rax * r13 */
            add %r14, %rax
            mov %rax, %r13

            add %r13, %r12 /* increment total by value */

            /* reset values, see initialization code */
            mov $10, %r13
            mov $0, %r14

            /* move onto the next character */
            jmp _start__while_file_not_empty

        _start__read_failed:
            /* either IO error or EOF, loop terminates */

    /* close the input file */
    mov %rbx, %rdi
    call close_file

    /* print out total value */
    mov %r12, %rdi
    call print_unsigned

    mov $0, %rdi
    call exit

.section .rodata

input_path:
    .ascii "data/one.txt\0"

/**
 * Transition table for the parser FSM. each row is a state, each column is an input
 * Accepted inputs are (in order):
 * '\n', 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, e, f, g, h, i, n, o, r, s, t, u, v, w, x, z
 * Defined states are:
 * start, o, on, t, tw, t, th, thr, thre, f, fo, fou, f, fi, fiv, s, si, s, se, sev, seve, e, ei,
 * eig, eigh, n, ni, nin, z, ze, zer
 */

parser_fsm_transition_table:
    /*    *,  \n,   0,  1,  2,  3,  4,  5,  6,  7,  8,  9,    e,  f,  g,  h,  i,  n,  o,  r,  s,  t,  u,  v,  w,  x,  z              */
    .byte 0,  0,    0,  0,  0,  0,  0,  0,  0,  0,  0,  0,    1,  2,  0,  0,  0,  3,  4,  0,  5,  6,  0,  0,  0,  0,  7  /* 0 start  */
    .byte 0,  0,    0,  0,  0,  0,  0,  0,  0,  0,  0,  0,    1,  2,  0,  0,  8,  3,  4,  0,  5,  6,  0,  0,  0,  0,  7  /* 1 e      */
    .byte 0,  0,    0,  0,  0,  0,  0,  0,  0,  0,  0,  0,    1,  2,  0,  0,  9,  3,  10, 0,  5,  6,  0,  0,  0,  0,  7  /* 2 f      */
    .byte 0,  0,    0,  0,  0,  0,  0,  0,  0,  0,  0,  0,    1,  2,  0,  0,  11, 3,  4,  0,  5,  6,  0,  0,  0,  0,  7  /* 3 n      */
    .byte 0,  0,    0,  0,  0,  0,  0,  0,  0,  0,  0,  0,    1,  2,  0,  0,  0,  12, 4,  0,  5,  6,  0,  0,  0,  0,  7  /* 4 o      */
    .byte 0,  0,    0,  0,  0,  0,  0,  0,  0,  0,  0,  0,    13, 2,  0,  0,  14, 3,  4,  0,  5,  6,  0,  0,  0,  0,  7  /* 5 s      */
    .byte 0,  0,    0,  0,  0,  0,  0,  0,  0,  0,  0,  0,    1,  2,  0,  15, 0,  3,  4,  0,  5,  6,  0,  0,  16, 0,  7  /* 6 t      */
    .byte 0,  0,    0,  0,  0,  0,  0,  0,  0,  0,  0,  0,    17, 2,  0,  0,  0,  3,  4,  0,  5,  6,  0,  0,  0,  0,  7  /* 7 z      */
    .byte 0,  0,    0,  0,  0,  0,  0,  0,  0,  0,  0,  0,    1,  2,  18, 0,  0,  3,  4,  0,  5,  6,  0,  0,  0,  0,  7  /* 8 ei     */
    .byte 0,  0,    0,  0,  0,  0,  0,  0,  0,  0,  0,  0,    1,  2,  0,  0,  0,  3,  4,  0,  5,  6,  0,  19, 0,  0,  7  /* 9 fi     */
    .byte 0,  0,    0,  0,  0,  0,  0,  0,  0,  0,  0,  0,    1,  2,  0,  0,  0,  12, 4,  0,  5,  6,  20, 0,  0,  0,  7  /* 10 fo    */
    .byte 0,  0,    0,  0,  0,  0,  0,  0,  0,  0,  0,  0,    1,  2,  0,  0,  0,  21, 4,  0,  5,  6,  0,  0,  0,  0,  7  /* 11 ni    */
    .byte 0,  0,    0,  0,  0,  0,  0,  0,  0,  0,  0,  0,    1,  2,  0,  0,  11, 3,  4,  0,  5,  6,  0,  0,  0,  0,  7  /* 12 on    */
    .byte 0,  0,    0,  0,  0,  0,  0,  0,  0,  0,  0,  0,    1,  2,  0,  0,  8,  3,  4,  0,  5,  6,  0,  22, 0,  0,  7  /* 13 se    */
    .byte 0,  0,    0,  0,  0,  0,  0,  0,  0,  0,  0,  0,    1,  2,  0,  0,  0,  3,  4,  0,  5,  6,  0,  0,  0,  0,  7  /* 14 si    */
    .byte 0,  0,    0,  0,  0,  0,  0,  0,  0,  0,  0,  0,    1,  2,  0,  0,  0,  3,  4,  23, 5,  6,  0,  0,  0,  0,  7  /* 15 th    */
    .byte 0,  0,    0,  0,  0,  0,  0,  0,  0,  0,  0,  0,    1,  2,  0,  0,  0,  3,  4,  0,  5,  6,  0,  0,  0,  0,  7  /* 16 tw    */
    .byte 0,  0,    0,  0,  0,  0,  0,  0,  0,  0,  0,  0,    1,  2,  0,  0,  8,  3,  4,  24, 5,  6,  0,  0,  0,  0,  7  /* 17 ze    */
    .byte 0,  0,    0,  0,  0,  0,  0,  0,  0,  0,  0,  0,    1,  2,  0,  25, 0,  3,  4,  0,  5,  6,  0,  0,  0,  0,  7  /* 18 eig   */
    .byte 0,  0,    0,  0,  0,  0,  0,  0,  0,  0,  0,  0,    1,  2,  0,  0,  0,  3,  4,  0,  5,  6,  0,  0,  0,  0,  7  /* 19 fiv   */
    .byte 0,  0,    0,  0,  0,  0,  0,  0,  0,  0,  0,  0,    1,  2,  0,  0,  0,  3,  4,  0,  5,  6,  0,  0,  0,  0,  7  /* 20 fou   */
    .byte 0,  0,    0,  0,  0,  0,  0,  0,  0,  0,  0,  0,    1,  2,  0,  0,  0,  3,  4,  0,  5,  6,  0,  0,  0,  0,  7  /* 21 nin   */
    .byte 0,  0,    0,  0,  0,  0,  0,  0,  0,  0,  0,  0,    26, 2,  0,  0,  0,  3,  4,  0,  5,  6,  0,  0,  0,  0,  7  /* 22 sev   */
    .byte 0,  0,    0,  0,  0,  0,  0,  0,  0,  0,  0,  0,    27, 2,  0,  0,  0,  3,  4,  0,  5,  6,  0,  0,  0,  0,  7  /* 23 thr   */
    .byte 0,  0,    0,  0,  0,  0,  0,  0,  0,  0,  0,  0,    1,  2,  0,  0,  0,  3,  4,  0,  5,  6,  0,  0,  0,  0,  7  /* 24 zer   */
    .byte 0,  0,    0,  0,  0,  0,  0,  0,  0,  0,  0,  0,    1,  2,  0,  0,  0,  3,  4,  0,  5,  6,  0,  0,  0,  0,  7  /* 25 eigh  */
    .byte 0,  0,    0,  0,  0,  0,  0,  0,  0,  0,  0,  0,    1,  2,  0,  0,  8,  3,  4,  0,  5,  6,  0,  0,  0,  0,  7  /* 26 seve  */
    .byte 0,  0,    0,  0,  0,  0,  0,  0,  0,  0,  0,  0,    1,  2,  0,  0,  8,  3,  4,  0,  5,  6,  0,  0,  0,  0,  7  /* 27 thre  */

/**
 * Outputs emitted according to active state and input.
 * values 0-9 are digit outputs
 * value 10 is a 'stop'
 * other values (should only be 11) are 'non-outputs' and not emitted
 */
parser_fsm_output_table:
    /*    *,  \n,   0,  1,  2,  3,  4,  5,  6,  7,  8,  9,    e,  f,  g,  h,  i,  n,  o,  r,  s,  t,  u,  v,  w,  x,  z              */
    .byte 11, 10,   0,  1,  2,  3,  4,  5,  6,  7,  8,  9,    11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11 /* 0 start  */
    .byte 11, 10,   0,  1,  2,  3,  4,  5,  6,  7,  8,  9,    11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11 /* 1 e      */
    .byte 11, 10,   0,  1,  2,  3,  4,  5,  6,  7,  8,  9,    11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11 /* 2 f      */
    .byte 11, 10,   0,  1,  2,  3,  4,  5,  6,  7,  8,  9,    11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11 /* 3 n      */
    .byte 11, 10,   0,  1,  2,  3,  4,  5,  6,  7,  8,  9,    11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11 /* 4 o      */
    .byte 11, 10,   0,  1,  2,  3,  4,  5,  6,  7,  8,  9,    11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11 /* 5 s      */
    .byte 11, 10,   0,  1,  2,  3,  4,  5,  6,  7,  8,  9,    11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11 /* 6 t      */
    .byte 11, 10,   0,  1,  2,  3,  4,  5,  6,  7,  8,  9,    11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11 /* 7 z      */
    .byte 11, 10,   0,  1,  2,  3,  4,  5,  6,  7,  8,  9,    11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11 /* 8 ei     */
    .byte 11, 10,   0,  1,  2,  3,  4,  5,  6,  7,  8,  9,    11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11 /* 9 fi     */
    .byte 11, 10,   0,  1,  2,  3,  4,  5,  6,  7,  8,  9,    11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11 /* 10 fo    */
    .byte 11, 10,   0,  1,  2,  3,  4,  5,  6,  7,  8,  9,    11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11 /* 11 ni    */
    .byte 11, 10,   0,  1,  2,  3,  4,  5,  6,  7,  8,  9,    1,  11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11 /* 12 on    */
    .byte 11, 10,   0,  1,  2,  3,  4,  5,  6,  7,  8,  9,    11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11 /* 13 se    */
    .byte 11, 10,   0,  1,  2,  3,  4,  5,  6,  7,  8,  9,    11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 6,  11 /* 14 si    */
    .byte 11, 10,   0,  1,  2,  3,  4,  5,  6,  7,  8,  9,    11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11 /* 15 th    */
    .byte 11, 10,   0,  1,  2,  3,  4,  5,  6,  7,  8,  9,    11, 11, 11, 11, 11, 11, 2,  11, 11, 11, 11, 11, 11, 11, 11 /* 16 tw    */
    .byte 11, 10,   0,  1,  2,  3,  4,  5,  6,  7,  8,  9,    11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11 /* 17 ze    */
    .byte 11, 10,   0,  1,  2,  3,  4,  5,  6,  7,  8,  9,    11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11 /* 18 eig   */
    .byte 11, 10,   0,  1,  2,  3,  4,  5,  6,  7,  8,  9,    5,  11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11 /* 19 fiv   */
    .byte 11, 10,   0,  1,  2,  3,  4,  5,  6,  7,  8,  9,    11, 11, 11, 11, 11, 11, 11, 4,  11, 11, 11, 11, 11, 11, 11 /* 20 fou   */
    .byte 11, 10,   0,  1,  2,  3,  4,  5,  6,  7,  8,  9,    9,  11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11 /* 21 nin   */
    .byte 11, 10,   0,  1,  2,  3,  4,  5,  6,  7,  8,  9,    11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11 /* 22 sev   */
    .byte 11, 10,   0,  1,  2,  3,  4,  5,  6,  7,  8,  9,    11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11 /* 23 thr   */
    .byte 11, 10,   0,  1,  2,  3,  4,  5,  6,  7,  8,  9,    11, 11, 11, 11, 11, 11, 0,  11, 11, 11, 11, 11, 11, 11, 11 /* 24 zer   */
    .byte 11, 10,   0,  1,  2,  3,  4,  5,  6,  7,  8,  9,    11, 11, 11, 11, 11, 11, 11, 11, 11, 8,  11, 11, 11, 11, 11 /* 25 eigh  */
    .byte 11, 10,   0,  1,  2,  3,  4,  5,  6,  7,  8,  9,    11, 11, 11, 11, 11, 7,  11, 11, 11, 11, 11, 11, 11, 11, 11 /* 26 seve  */
    .byte 11, 10,   0,  1,  2,  3,  4,  5,  6,  7,  8,  9,    3,  11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11 /* 27 thre  */

/**
 * Lookup table for converting ASCII bytes into FSM input indices. Characters which are
 * 'not useful' always map to index 0, which resets the FSM to the start state.
 */
parser_fsm_input_lookup:
    /*    _0h _1h _2h _3h _4h _5h _6h _7h _8h _9h _Ah _Bh _Ch _Dh _Eh _Fh       */
    .byte 0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  1,  0,  0,  0,  0,  0  /* 0_h */
    .byte 0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0  /* 1_h */
    .byte 0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0  /* 2_h */
    .byte 2,  3,  4,  5,  6,  7,  8,  9,  10, 11, 0,  0,  0,  0,  0,  0  /* 3_h */
    .byte 0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0  /* 4_h */
    .byte 0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0  /* 5_h */
    .byte 0,  0,  0,  0,  0,  12, 13, 14, 15, 16, 0,  0,  0,  0,  17, 18 /* 6_h */
    .byte 0,  0,  19, 20, 21, 22, 23, 24, 25, 0,  26, 0,  0,  0,  0,  0  /* 7_h */
    .byte 0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0  /* 8_h */
    .byte 0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0  /* 9_h */
    .byte 0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0  /* 0_h */
    .byte 0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0  /* B_h */
    .byte 0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0  /* C_h */
    .byte 0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0  /* D_h */
    .byte 0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0  /* E_h */
    .byte 0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0  /* F_h */
