//
	.section .init
	.globl _start
	.type _start,@function

_start:
    la 		$sp, _stack_top

	lu12i.w $t0, 0xFFFF
	ori  	$t0, $t0, 0x300
	slli.w 	$t0, $t0, 4
	ori  	$t1, $zero, 0x3
	st.w 	$t1, $t0, 0xC

	bl 		main
1: 	b    	1b
