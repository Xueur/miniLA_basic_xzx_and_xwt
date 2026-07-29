//
	.section .init
	.globl _start
	.type _start,@function

_start:
	la		$sp, _stack_top

	// ---- UART init: clear RX/TX FIFO ----
	lu12i.w	$t0, 0xFFFF
	ori		$t0, $t0, 0x300
	slli.w	$t0, $t0, 4
	ori		$t1, $zero, 0x3
	st.w	$t1, $t0, 0xC

	// ---- Zero .bss section ----
	la		$t0, _bss_start
	la		$t1, _bss_end
1:	beq		$t0, $t1, 2f
	st.w	$zero, $t0, 0
	addi.w	$t0, $t0, 4
	b		1b
2:

	bl		main
3:	b		3b
