#include <stdint.h>
#include "rt0s.h"

//Debouncing USER button using rt0s semaphores.
//The PC9 LED is supposed to blink only once per button push, regardless of
//the number of bounces, while PC8 LED is supposed to blink for the rest of
//the bounces. The idea is to let two threads wait for the semaphores. Thread1
//catches a semaphore, blinks PC9 and yields for 1 second. Thread2, meanwhile,
//is allowed to catch the semaphores in a loop constantly, which makes PC8
//LED to bounce as many times as the USER button bounced minus one.

#define RCC_AHBENR 0x40021014
#define PORTC_MODER 0x48000800
#define PORTC_ODR 0x48000814
#define EXTI_IMR 0x40010400
#define EXTI_RTSI 0x40010408
#define EXTI_PR 0x40010414
#define NVIC_ISER 0xe000e100

static void int_init(void)
{
	//setup external interrupt on USER button
	volatile uint32_t *p = (uint32_t*)EXTI_IMR;
	*p = 1;
	p = (uint32_t*)EXTI_RTSI;
	*p = 1;
	p = (uint32_t*)NVIC_ISER;
	*p |= (1 << 5);
}

static void thr1(void)
{
	volatile uint32_t *p = (uint32_t*)PORTC_ODR;
	while(1)
	{
		//wait for semaphore 0
		rt0s_sem_wait(0);
		//blink led
		*p |= 0x00000200;
		rt0s_yield(20);
		*p &= ~0x00000200;
		//wait for a whole second while thread2 blinks out the bounces
		rt0s_yield(100);
	}
}

static void thr2(void)
{
	volatile uint32_t *p = (uint32_t*)PORTC_ODR;
	while(1)
	{
		//wait for semaphore 0
		rt0s_sem_wait(0);
		//blink the led fast
		*p |= 0x00000100;
		rt0s_yield(10);
		*p &= ~0x00000100;
		rt0s_yield(10);
	}
}

static void clock_init(void)
{
	//enable port C clock
	volatile uint32_t *p = (uint32_t*)RCC_AHBENR;
	*p = 0x00080000;
}

static void gpio_init(void)
{
	//PC8/PC9 output
	volatile uint32_t *p = (uint32_t*)PORTC_MODER;
	*p = 0x00050000;
}

void rt0s_init(void)
{
	//do all initializations and create threads
	//this function will be called by rt0s
	clock_init();
	gpio_init();
	int_init();
	rt0s_thread(&thr1);
	rt0s_thread(&thr2);
}

void __attribute__((interrupt("IRQ"))) irq_5(void)
{
	//on USER button interrupt
	volatile uint32_t *p = (uint32_t*)EXTI_PR;
	//clear interrupt
	*p |= 1;
	//increase semaphore 0
	rt0s_sem_signal(0);
}

