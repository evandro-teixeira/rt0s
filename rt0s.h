#ifndef _RT0S_H
#define _RT0S_H

#include <stdint.h>

extern void rt0s_thread(void (*fp)(void));
extern void rt0s_yield(uint32_t ticks);
extern void rt0s_kill(void);
extern void rt0s_sem_signal(uint32_t id);
extern void rt0s_sem_wait(uint32_t id);

#endif

