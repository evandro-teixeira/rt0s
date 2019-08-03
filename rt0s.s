.thumb
.syntax unified

.include "cfg.s"

.equ KERN_STACK_SZ, 100
.equ STACK_SZ, 25*4	//thread stack size (25 words/8 min needed)

.equ SYST_RELOAD, SYST_FREQ/100	//systick interrupt every 10ms

.equ MAX_THR, 5	//includes thr0
.equ MAX_SEM, 5

.equ THR_SZ, 5*4
.equ WAIT_YIELD, 1
.equ WAIT_SEM, 2
.equ WAIT_KILL, 4

.equ RT0S_STACK_END, RAMEND-KERN_STACK_SZ

.global rt0s_thread
.global rt0s_yield
.global rt0s_kill
.global rt0s_sem_signal
.global rt0s_sem_wait

.data
.start_data:
nthr:
	.4byte 0
active:
	.4byte 0
thrs:
	.rept MAX_THR
	.4byte 0	//SP
	.4byte 0	//yield ticks
	.4byte 0	//semaphore to wait on
	.4byte 0	//waiting
	.4byte 0	//idx
	//set THR_SZ accordingly
	.endr
sems:
	.rept MAX_SEM
	.4byte 0	//value
	.endr
self_preempt:
	.4byte 0
.end_data:

.altmacro
.macro IRQ_N n
	.if \n
		IRQ_N %(n-1)
	.endif
	.4byte irq_\n+1
.endm

.macro IRQ_N_DEF n
	.if \n
		IRQ_N_DEF %(n-1)
	.endif
	.weak irq_\n
	.thumb_set irq_\n, _default_irq
.endm

.text
vectors:
	.4byte RAMEND
	.4byte _start+1
	.4byte _nmi_irq+1
	.4byte _hardfault_irq+1
	.rept 7
	.4byte 0
	.endr
	.4byte _svcall_irq+1
	.4byte 0
	.4byte 0
	.4byte _pendsv_irq+1
	.4byte _systick_irq+1
	IRQ_N 31

//weakly define irq functions
IRQ_N_DEF 31

_thr_set_yield:
	//r0 = ptr
	//r1 = val
	//set yield counter
	str r1, [r0,#4]
	//set waiting
	//set the WAIT_YIELD bit
	ldr r1, =WAIT_YIELD
	ldr r2, [r0,#12]
	orrs r2, r1
	str r2, [r0,#12]
	bx lr

_thr_dec_yield:
	//r0 = ptr
	//read yield counter
	ldr r1, [r0,#4]
	//if zero, just exit
	cmp r1, #0
	beq _dec_yield_exit
	//decrease it by one
	subs r1, #1
	//if it just hit zero
	beq _clear_wait
	//otherwise store and exit
	str r1, [r0,#4]
	b _dec_yield_exit
_clear_wait:
	//store
	str r1, [r0,#4]
	//clear wait
	ldr r1, [r0,#12]
	//clear the WAIT_YIELD bit only
	ldr r2, =WAIT_YIELD
	bics r1, r2
	str r1, [r0,#12]
_dec_yield_exit:
	bx lr

_thr_set_killed:
	//r0 = ptr
	//set the WAIT_KILL bit
	ldr r1, =WAIT_KILL
	ldr r2, [r0,#12]
	orrs r2, r1
	str r2, [r0,#12]
	bx lr

_thr_sem_wait:
	//r0 = ptr
	//r1 = sem idx
	//set semaphore idx
	str r1, [r0,#8]
	//set the WAIT_SEM flag
	ldr r1, [r0,#12]
	ldr r2, =WAIT_SEM
	orrs r1, r2
	str r1, [r0,#12]
	bx lr

_thr_sem_check:
	//r0 = ptr
	//check if it is waiting at all
	ldr r1, [r0,#12]
	ldr r2, =WAIT_SEM
	tst r1, r2
	beq _sem_check_exit
	//read semaphore idx it is waiting on
	ldr r1, [r0,#8]
	//check that semaphore's value
	ldr r3, =sems
	movs r2, #4	//sizeof(sem)
	muls r1, r2
	//read
	ldr r2, [r3,r1]
	//check if bigger than 0
	cmp r2, #0
	bgt _sem_acquire
	//no sem available
	bx lr
_sem_acquire:
	//decrease sem value and write back
	subs r2, #1
	str r2, [r3,r1]
	dmb
	//clear the WAIT_SEM bit only
	ldr r1, [r0,#12]
	ldr r2, =WAIT_SEM
	bics r1, r2
	str r1, [r0,#12]
_sem_check_exit:
	bx lr

_nmi_irq:
_hardfault_irq:
_fault:
	wfi
	b _fault

.macro GO_RETP
	//discard MSP
	mrs r0, MSP
	adds r0, #32
	msr MSP, r0
	//setup fake stack for returning to _retp
	ldr r0, =0x01000000
	push {r0}	//xPSR
	ldr r0, =_retp
	push {r0}	//PC
	push {r0}	//LR
	movs r0, #0
	push {r0}	//r12
	push {r0}	//r3
	push {r0}	//r2
	push {r0}	//r1
	push {r0}	//r0
	//return to _retp
	ldr r0, =0xfffffff1
	bx r0
.endm

_svcall_irq:
	ldr r0, =self_preempt
	movs r1, #1
	str r1, [r0]
	GO_RETP

_pendsv_irq:
	//resume thr: the magic lr value
	ldr r0, =0xfffffffd
	bx r0

_systick_irq:
	//decrease yield counter for all threads
	ldr r2, =nthr
	ldr r5, [r2]
	movs r4, #0
_check_states:
	movs r0, r4
	bl _idx_to_thr_ptr
	movs r6, r1
	movs r0, r6
	bl _thr_dec_yield
	movs r0, r6
	bl _thr_sem_check
	adds r4, #1
	cmp r4, r5
	blt _check_states
	GO_RETP

_default_irq:
	ldr r0, =0xfffffffd
	bx r0

_systick_init:
	ldr r0, =SYST_RVR
	ldr r1, =SYST_RELOAD
	str r1, [r0]
	ldr r0, =SYST_CVR
	str r1, [r0]
	//
	ldr r0, =SYST_CSR
	movs r1, #0x03	//enable, interrupt enable
	str r1, [r0]
	bx lr

_idx_to_thr_ptr:
	//r0 = idx
	ldr r1, =thrs
	ldr r2, =THR_SZ
	muls r0, r2
	//r1 = ptr
	adds r1, r0
	bx lr

_start:
	cpsid i
	ldr r0, =.start_data
	ldr r1, =.end_data
	movs r2, #0
_zero_data:
	str r2, [r0]
	adds r0, #4
	cmp r0, r1
	ble _zero_data
	ldr r0, =_rt0s_thr0
	bl rt0s_thread
	//defined in userspace
	bl rt0s_init
	bl _systick_init
	//get active thread for _no_psp_save
	//set it to thr0
	ldr r7, =active
	ldr r0, =thrs
	str r0, [r7]
	//no PSP update required on init
	b _no_psp_save
_retp:
	cpsid i
	//see if we need to skip thr switch
	ldr r0, =self_preempt
	ldr r1, [r0]
	cmp r1, #2
	beq _skip_switch
	//if not, see if we need to skip it next time
	cmp r1, #1
	bne _save_ctx
	adds r1, #1
	str r1, [r0]
	b _save_ctx
_skip_switch:
	//reset skip-thr flag
	movs r1, #0
	str r1, [r0]
	b _run_thread
_save_ctx:
	//push r4-r7 on PSP stack
	movs r0, #2
	msr CONTROL, r0
	isb
	push {r4-r7}
	//back to kernel mode
	movs r0, #0
	msr CONTROL, r0
	isb
	//get active thread
	ldr r7, =active
	//update preempted thread's PSP
	ldr r0, [r7]
	mrs r1, PSP
	str r1, [r0,#0]
_no_psp_save:
	ldr r0, [r7]
	bl _next
	//update ptr
	str r1, [r7,#0]
	//load and restore new thread's SP
	ldr r0, [r1,#0]
	msr PSP, r0
	//restore its r4-r7 because IRQs don't do that
	movs r0, #2
	msr CONTROL, r0
	isb
	pop {r4-r7}
	//back to kernel mode
	movs r0, #0
	msr CONTROL, r0
	isb
_run_thread:
	cpsie i
	//run thread
	ldr r0, =ICSR
	ldr r1, [r0]
	ldr r2, =0x10000000
	orrs r1, r2
	str r1, [r0]
	dsb
_wpsv:
	wfi
	b _wpsv

_next:
	push {r5-r7, LR}
	//r0 = current ptr
	movs r1, r0
	//load its idx
	ldr r0, [r1,#16]
	//max thrs to check, nthr-1
	ldr r1, =nthr
	ldr r7, [r1]
	//current being check, idx+1
	movs r6, r0
	adds r6, #1
	//copy of r0
	movs r5, r0
_next_find_left:
	//if current == original, schedule thr0
	cmp r6, r5
	beq _next_sched_thr0
	//if current > max, reset to to 1 and retry
	cmp r6, r7
	bge _next_sched_reset_1
	//check if waiting
	movs r0, r6
	bl _idx_to_thr_ptr
	ldr r0, [r1,#12]
	cmp r0, #0
	//if rdy, run it
	beq _next_exit
	//not ready, increase and retry
	adds r6, #1
	b _next_find_left
_next_sched_reset_1:
	//start finding from 1
	//but if thr0 was scheduled before all began, reschedule it
	cmp r5, #0
	beq _next_sched_thr0
	movs r6, #1
	b _next_find_left
_next_sched_thr0:
	movs r6, #0
_next_exit:
	//put ptr in r1
	movs r0, r6
	bl _idx_to_thr_ptr
	pop {r5-r7, PC}
	bx lr

rt0s_thread:
	ldr r1, =nthr
	ldr r2, =MAX_THR
	ldr r3, [r1]
	cmp r3, r2
	blt _create_thr
	bx lr
_create_thr:
	//gonna change LR
	push {r4-r5, LR}
	movs r4, r0
	//r4 should have the address
	//nthr++
	ldr r0, =nthr
	ldr r1, [r0]
	adds r1, #1
	str r1, [r0]
	//r0 = idx
	movs r0, r1
	//idx is 0-based
	subs r0, #1
	movs r5, r0
	//allocate fixed size stack
	ldr r2, =RT0S_STACK_END
	ldr r3, =STACK_SZ
	muls r3, r5
	subs r2, r3
	//r2 = PSP
	//populate stack with init values
	//switch to PSP for fast push
	movs r0, #2
	msr CONTROL, r0
	isb
	msr PSP, r2
	ldr r0, =0x01000000
	push {r0}	//xPSR
	movs r0, r4
	push {r0}	//PC
	push {r0}	//LR
	movs r0, #0
	push {r0}	//r12
	push {r0}	//r3
	push {r0}	//r2
	push {r0}	//r1
	push {r0}	//r0
	push {r0}	//r7
	push {r0}	//r6
	push {r0}	//r5
	push {r0}	//r4
	//back to kernel mode
	movs r0, #0
	msr CONTROL, r0
	isb
	//idx to ptr
	movs r0, r5
	bl _idx_to_thr_ptr
	//set its idx
	str r5, [r1,#16]
	//write back new SP
	mrs r0, PSP
	str r0, [r1,#0]
	pop {r4-r5, PC}

rt0s_yield:
	push {LR}
	//r0 = target
	movs r1, r0
	ldr r2, =active
	//ptr
	ldr r0, [r2]
	//set yield counter
	bl _thr_set_yield
	svc 0xaa
	pop {PC}

rt0s_kill:
	push {LR}
	ldr r1, =active
	//ptr
	ldr r0, [r1]
	//set WAIT_KILL flag
	bl _thr_set_killed
	svc 0xaa
	//we will never come back here
	pop {PC}

_rt0s_thr0:
	dsb
	wfi
	b _rt0s_thr0

.weak rt0s_init
	bx lr

rt0s_sem_signal:
	//r0 = sem idx
	ldr r1, =sems
	movs r2, #4
	muls r0, r2
	//read sem value
	ldr r3, [r0,r1]
	//increase it
	adds r3, #1
	//store back
	str r3, [r0,r1]
	dmb
	bx lr

rt0s_sem_wait:
	push {LR}
	//r0 = sem idx
	movs r1, r0
	ldr r2, =active
	//ptr
	ldr r0, [r2]
	//wait for semaphore
	bl _thr_sem_wait
	svc 0xaa
	pop {PC}

