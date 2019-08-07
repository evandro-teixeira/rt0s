rt0s is a preemptive, multithreaded, realtime OS built for ARM Cortex-M0

### Usable Features
- Create threads at runtime using `rt0s_thread`
- Threads can yield using `rt0s_yield`
- Threads can quit using `rt0s_kill`
- Increase semaphore count using `rt0s_sem_signal`
- Threads can wait on a semaphore using `rt0s_sem_wait`

See `rt0s.h` file for the function signatures.

### Design Notes
- Kernel fits under 1k bytes, 1k assembly lines
- 100 bytes allocated for kernel stack
- Kernel RAM usage = `20*(Max threads) + 4*(Max semaphores) + 3` bytes
- Max number of threads and semaphores are known at compile-time
- Thread stack size is known at compile-time (same for all threads)
- Static memory usage / no dynamic memory allocation
- Round-robin pre-emptive scheduling
- All threads have same priority
- Thread switch latency = `192 + 50.4*(Number of threads created)` cycles
	- For demo board STM32F0308-DISCO with 8MHz crystal, and for `N=10`, the
	thread latency is 696 cycles / 87 microseconds
- Interrupts are disabled during thread switching

### Attempt at a scheduling overview diagram
```
              +----------+                             +----------+
        +-----+ Thread N +-----------+                 |Thread N+1|
        |     +-------+--+           |                 +-----+----+
        |             |              |                       ^
        |             |              |                       |
        v             v              v                       |
+-------+------+   +--+--+     +-----+-----+           +-----+----+
|Wait Semaphore|   |Yield|     |SysTick IRQ|           |PendSV IRQ|
+-------+------+   +---+-+     +-------+---+           +-----+----+
        |              |               |                     ^
        |    +-------+ |               |                     |
        +--->+SVC IRQ+<+               |                     |
             +---+---+                 v                     |
                 |               +-----+-------+             |
                 +-------------->+Schedule Next+-------------+
                                 +-------------+

```

### Demo code
Code for STM32F0308-DISCO board has been added to boards/ folder. The demo
code uses semaphores and yield function to debounce a button.

You can add your board into the boards/ folder. Create a folder with your
board's name and add these files into it:
- linker.ld: with correct addresses/sizes for flash and RAM.
- cfg.s: SysTick clock frequency.
- main.c: actual application code.

Then change the `BOARD` value in Makefile to your board's name, and run `make`.
Flash rt0s.elf or rt0s.hex.

