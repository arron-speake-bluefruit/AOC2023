.global exit
.global print_unsigned
.global open_file
.global close_file
.global read_byte_from_file

.section .text

/**
 * Exit the process with exit code 0.
 * rdi: status
 * Does not return.
 */
exit:
    mov $60, %rax /* exit syscall number */
    syscall /* trigger exit(%rdi) syscall */

/**
 * Print the provided integer to stdout, followed by a newline.
 * rdi: value
 * return value undefined
 */
print_unsigned:
    /*** push the integer digits onto the stack ***/
    /*
    push newline (ASCII '\n') onto stack

    let NUMBER be the unsigned integer to be digitized
    let LENGTH be the count of pushed characters (initially 1)

    while NUMBER is not 0:
        (quotient, remainder) = NUMBER / 10
        set NUMBER to quotient
        convert remainder from numeral to ASCII (+ '0')
        push remainder character onto stack
        increment LENGTH

    NOTE: It's safe to use the (128B) red zone here, since a 64-bit integer is at most 20 digits.
    */

    dec %rsp /* as below */
    movb $10, (%rsp) /* write '\n' onto the stack */

    mov %rdi, %rax /* input number is in RAX */
    mov $1, %r8 /* use RBX as length of string */

    print_unsigned__while_number_nonzero:
        mov $10, %rdi /* prepare to divide by 10 */
        mov $0, %rdx /* clear upper bits of dividend, lower bits are RAX */
        div %rdi /* quotient in RAX (replace prev. number), remainder in RDX */

        add $48, %rdx /* add '0' to remainder numeral, converts to ASCII */
        dec %rsp /* as below */
        movb %dl, (%rsp) /* push the remainder character onto the stack */

        inc %r8 /* increment length counter */

        test %rax, %rax /* loop condition */
        jnz print_unsigned__while_number_nonzero /* as above */

    /*** write the constructed string to stdout ***/
    mov $1, %rdi /* write into STDOUT */
    mov %rsp, %rsi /* write from stack pointer */
    mov %r8, %rdx /* write LENGTH number of bytes */
    mov $1, %rax /* write syscall number */
    syscall /* syscall write(%rdi, %rsi, %rdx) */

    /*** clean up stack and preserved registers ***/
    add %r8, %rsp
    ret

/**
 * Attempt to open a file for reading.
 * rdi: address of null-terminated string, path of file to open
 * returns (rax) non-negative file descriptor on success, negative status on failure
 */
open_file:
    mov $2, %rax /* open syscall number */
    mov $0, %rsi /* set the open mode to O_RDONLY */
    mov $0, %rdx /* 0 mode argument */
    syscall /* syscall open(%rdi, %rsi, %rdx) */
    ret

/**
 * Close a file by its file descriptor.
 * rdi: file descriptor of the file to close
 * returns (rax) 0 on success, negative status on failure
 */
close_file:
    mov $3, %rax /* close syscall number */
    syscall /* syscall close(%rdi) */
    ret

/**
 * Read a single byte from a file.
 * rdi: the file descriptor to read from
 * returns (rax) 1 if the byte was read, 0 if the file is empty, or a negative error on failure
 * if read, the byte is stored in DL (lowest byte of RDX).
 */
read_byte_from_file:
    dec %rsp /* reserve space for a byte on the stack */

    /* trigger the read syscall */
    mov $0, %rax /* read syscall number */
    /* rdi is the file descriptor, set by argument */
    mov %rsp, %rsi /* read into the stack */
    mov $1, %rdx /* read 1 byte */
    syscall /* syscall read(%rdi, %rsi, %rdx) */

    mov (%rsp), %dl /* read the byte into DL */

    /* clean up and return */
    inc %rsp /* free the reserved stack space */
    ret
