.equ SYST_CSR, 0xe000e010			//SysTick control/status register
.equ SYST_RVR, 0xe000e014			//SysTick reload value
.equ SYST_CVR, 0xe000e018			//SysTick current value
.equ ICSR, 0xe000ed04				//to set PendSV to pending

.equ SYST_FREQ, 1000000				//systick clock frequency (1MHz)

