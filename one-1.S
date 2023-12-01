.extern exit
.extern print_unsigned
.global open_file
.global close_file
.global read_byte_from_file

.global _start

/*
open problem input as FILE

set "sum" to 0
(sum is the accumulated value from ever line parsed so far)

set "first digit" to 10
(the first digit seen on a line, a value >=10 mean no digit has been seen yet)

set "current digit" to 0
(the most recently seen digit)

read next char from FILE:
- if exhausted, break
- elif digit:
  - set current digit to numeric value
  - if first digit is 10 (magic number):
    - set first digit to current digit
- elif newline:
  - concat first & current digit to a new number (first + 10*current)
  - increment sum by new number

print sum

close FILE
exit 0
*/

.section .text

_start:
    lea input_path(%rip), %rdi
    call open_file
    mov %rax, %rbx /* preserve the file descriptor */

    mov $0, %r12 /* move 0 into "sum" accumulator */
    mov $10, %r13 /* move magic number 10 into "first digit" register */
    mov $0, %r14 /* move 0 into "current digit" register */

    _start__while_file_not_empty:
        mov %rbx, %rdi /* prepare to read from the input data file */
        call read_byte_from_file /* status -> RAX, byte -> RDX */

        /* check if the read succeeded */
        mov $1, %rdi
        cmp %rax, %rdi /* see below & function docs in common.S */
        jne _start__read_failed /* if we failed to load a byte, jump to end */

        /* check if RDI (read char) is ASCII 10 '\n' */
        cmp $10, %rdx
        je _start__char_is_newline /* if so, handle a newline! */

        /* check if RDI is in range [48, 57] (ASCII '0' .. '9') */
        sub $48, %rdx
        cmp $9, %rdx
        ja _start__while_file_not_empty /* not a newline or digit, move on to next char */

        /* char is a digit, the value is in RDI. */
        mov %rdx, %r14 /* store the value in the current digit register */

        mov $10, %rax
        cmp %r13, %rax /* compare first digit against 10 */
        jne _start__while_file_not_empty /* already seen a digit, nothing more to do */
        mov %r14, %r13 /* the current digit is the first digit */
        /* move onto next character */
        jmp _start__while_file_not_empty

        _start__char_is_newline:
            /* concatenate first and last digits. x86 sucks, man */
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
    .ascii "data/one-1.txt\0"
