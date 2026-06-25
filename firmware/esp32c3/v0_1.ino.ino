// ============================================================
// Récepteur trame UART DE10-Lite → ESP32-C3
// Format : 0xAA | 0x02 | LSB | MSB | CHECKSUM(XOR)
// Sortie Serial (USB) : "0,valeur" ou "1,valeur" pour Python
// ============================================================

#define BAUD_RATE    115200
#define HEADER       0xAA
#define SERIAL1_RX   20      // D7 sur XIAO ESP32-C3
#define SERIAL1_TX   21      // D6 sur XIAO ESP32-C3

typedef enum {
    WAIT_HEADER,
    WAIT_LEN,
    WAIT_DATA,
    WAIT_CHECKSUM
} rx_state_t;

rx_state_t rx_state     = WAIT_HEADER;
uint8_t    payload[8];
uint8_t    byte_idx     = 0;
uint8_t    expected_len = 0;
uint8_t    checksum_acc = 0;
bool       ch_toggle    = false;

// Statistiques
uint32_t frames_ok  = 0;
uint32_t frames_err = 0;

void setup() {
    Serial.begin(115200);
    unsigned long t = millis();
    while (!Serial && millis() - t < 2000);

    Serial1.begin(BAUD_RATE, SERIAL_8N1, SERIAL1_RX, SERIAL1_TX);

    Serial.println("=== UART Framer Receiver ===");
    Serial.print("RX=GPIO"); Serial.print(SERIAL1_RX);
    Serial.print(" TX=GPIO"); Serial.println(SERIAL1_TX);
    Serial.println("Format sortie : canal,valeur");
    Serial.println("============================");
}

void loop() {
    while (Serial1.available()) {
        uint8_t b = (uint8_t) Serial1.read();

        switch (rx_state) {

            case WAIT_HEADER:
                if (b == HEADER) rx_state = WAIT_LEN;
                break;

            case WAIT_LEN:
                expected_len = b;
                byte_idx     = 0;
                checksum_acc = 0;
                rx_state     = WAIT_DATA;
                break;

            case WAIT_DATA:
                payload[byte_idx++] = b;
                checksum_acc ^= b;
                if (byte_idx == expected_len) rx_state = WAIT_CHECKSUM;
                break;

            case WAIT_CHECKSUM:
                if (b == checksum_acc) {
                    // Reconstruction valeur 12 bits (LSB en payload[0], MSB en payload[1])
                    uint16_t val = (((uint16_t)payload[1] << 8) | payload[0]) & 0x0FFF;
                    Serial.print(ch_toggle ? "1," : "0,");
                    Serial.println(val);
                    ch_toggle = !ch_toggle;
                    frames_ok++;
                } else {
                    // Checksum invalide : trame corrompue
                    frames_err++;
                    // Décommenter pour debug :
                    // Serial.print("ERR CS got=0x");
                    // Serial.print(b, HEX);
                    // Serial.print(" exp=0x");
                    // Serial.println(checksum_acc, HEX);
                }
                rx_state = WAIT_HEADER;
                break;
        }
    }
}