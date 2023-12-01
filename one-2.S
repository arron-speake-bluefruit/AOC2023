.extern exit
.extern print_unsigned
.extern open_file
.extern close_file
.extern read_byte_from_file

.global _start

.section .text

_start:
    mov $0, %rdi
    call exit

.section .rodata

input_path:
    .ascii "data/one.txt\0"
