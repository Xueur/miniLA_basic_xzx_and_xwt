#include <stdint.h>

#define MMIO32(address) (*(volatile uint32_t *)(address))

#define SWITCH_DATA  MMIO32(0xFFFF0000u)
#define LED_DATA     MMIO32(0xFFFF1000u)
#define DIG_DATA     MMIO32(0xFFFF2000u)
#define UART_RX      MMIO32(0xFFFF3000u)
#define UART_TX      MMIO32(0xFFFF3004u)
#define UART_STATUS  MMIO32(0xFFFF3008u)
#define UART_CTRL    MMIO32(0xFFFF300Cu)
#define TIMER_LOW    MMIO32(0xFFFF4000u)
#define TIMER_HIGH   MMIO32(0xFFFF4008u)

#define UART_RX_VALID 0x1u
#define UART_TX_READY 0x4u

static void uart_putc(char value) {
    while ((UART_STATUS & UART_TX_READY) == 0u) {
    }
    UART_TX = (uint32_t)(uint8_t)value;
}

static void uart_puts(const char *text) {
    while (*text != '\0') {
        uart_putc(*text++);
    }
}

int main(void) {
    UART_CTRL = 0x3u;
    UART_CTRL = 0x0u;
    uart_puts("miniRV pipeline SoC C_TEST ready\r\n");

    for (;;) {
        uint32_t switches = SWITCH_DATA;
        uint32_t timer_low = TIMER_LOW;
        uint32_t timer_high = TIMER_HIGH;

        LED_DATA = switches;
        DIG_DATA = (switches << 16) |
                   ((timer_high ^ timer_low) & 0xFFFFu);

        if ((UART_STATUS & UART_RX_VALID) != 0u) {
            uint8_t received = (uint8_t)UART_RX;
            uart_putc((char)received);
        }
    }
}
