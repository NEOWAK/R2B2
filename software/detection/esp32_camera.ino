#include <Suprematy-project-1_inferencing.h>
#include "edge-impulse-sdk/dsp/image/image.hpp"
#include "esp_camera.h"

// Pins XIAO ESP32S3
#define PWDN_GPIO_NUM     -1
#define RESET_GPIO_NUM    -1
#define XCLK_GPIO_NUM     10
#define SIOD_GPIO_NUM     40
#define SIOC_GPIO_NUM     39
#define Y9_GPIO_NUM       48
#define Y8_GPIO_NUM       11
#define Y7_GPIO_NUM       12
#define Y6_GPIO_NUM       14
#define Y5_GPIO_NUM       16
#define Y4_GPIO_NUM       18
#define Y3_GPIO_NUM       17
#define Y2_GPIO_NUM       15
#define VSYNC_GPIO_NUM    38
#define HREF_GPIO_NUM     47
#define PCLK_GPIO_NUM     13

// --- LED ---
#define LED_PIN           2   // ← ajuste selon ton câblage

// --- SEUILS ---
const int   BBOX_PROCHE   = 20;  // ← ta valeur calibrée (T_FILT à 20cm)
const int   ANGLE_TOL     = 10;  // ± pixels autour du centre

#define EI_CAMERA_RAW_FRAME_BUFFER_COLS  320
#define EI_CAMERA_RAW_FRAME_BUFFER_ROWS  240
#define EI_CAMERA_FRAME_BYTE_SIZE        3

static bool is_initialised = false;
uint8_t *snapshot_buf;
float t_filtered = 0;
const float ALPHA = 0.1;

static camera_config_t camera_config = {
    .pin_pwdn  = PWDN_GPIO_NUM,
    .pin_reset = RESET_GPIO_NUM,
    .pin_xclk  = XCLK_GPIO_NUM,
    .pin_sccb_sda = SIOD_GPIO_NUM,
    .pin_sccb_scl = SIOC_GPIO_NUM,
    .pin_d7 = Y9_GPIO_NUM, .pin_d6 = Y8_GPIO_NUM,
    .pin_d5 = Y7_GPIO_NUM, .pin_d4 = Y6_GPIO_NUM,
    .pin_d3 = Y5_GPIO_NUM, .pin_d2 = Y4_GPIO_NUM,
    .pin_d1 = Y3_GPIO_NUM, .pin_d0 = Y2_GPIO_NUM,
    .pin_vsync = VSYNC_GPIO_NUM,
    .pin_href  = HREF_GPIO_NUM,
    .pin_pclk  = PCLK_GPIO_NUM,
    .xclk_freq_hz = 20000000,
    .ledc_timer   = LEDC_TIMER_0,
    .ledc_channel = LEDC_CHANNEL_0,
    .pixel_format = PIXFORMAT_JPEG,
    .frame_size   = FRAMESIZE_QVGA,
    .jpeg_quality = 12,
    .fb_count     = 1,
    .fb_location  = CAMERA_FB_IN_PSRAM,
    .grab_mode    = CAMERA_GRAB_WHEN_EMPTY,
};

bool ei_camera_init(void);
bool ei_camera_capture(uint32_t img_width, uint32_t img_height, uint8_t *out_buf);

bool ei_camera_init(void) {
    if (is_initialised) return true;
    esp_err_t err = esp_camera_init(&camera_config);
    if (err != ESP_OK) {
        Serial.printf("Camera init failed: 0x%x\n", err);
        return false;
    }
    sensor_t *s = esp_camera_sensor_get();
    s->set_vflip(s, 1);
    s->set_hmirror(s, 0);
    s->set_saturation(s, 2);
    is_initialised = true;
    return true;
}

bool ei_camera_capture(uint32_t img_width, uint32_t img_height, uint8_t *out_buf) {
    if (!is_initialised) return false;
    camera_fb_t *fb = esp_camera_fb_get();
    if (!fb) return false;
    bool converted = fmt2rgb888(fb->buf, fb->len, PIXFORMAT_JPEG, snapshot_buf);
    esp_camera_fb_return(fb);
    if (!converted) return false;
    if ((img_width != EI_CAMERA_RAW_FRAME_BUFFER_COLS)
        || (img_height != EI_CAMERA_RAW_FRAME_BUFFER_ROWS)) {
        ei::image::processing::crop_and_interpolate_rgb888(
            out_buf,
            EI_CAMERA_RAW_FRAME_BUFFER_COLS,
            EI_CAMERA_RAW_FRAME_BUFFER_ROWS,
            out_buf, img_width, img_height);
    }
    return true;
}

static int ei_camera_get_data(size_t offset, size_t length, float *out_ptr) {
    size_t pixel_ix    = offset * 3;
    size_t pixels_left = length;
    size_t out_ptr_ix  = 0;
    while (pixels_left != 0) {
        out_ptr[out_ptr_ix] = (snapshot_buf[pixel_ix + 2] << 16)
                            + (snapshot_buf[pixel_ix + 1] << 8)
                            +  snapshot_buf[pixel_ix];
        out_ptr_ix++;
        pixel_ix += 3;
        pixels_left--;
    }
    return 0;
}

void setup() {
    Serial.begin(115200);
    delay(1000);

    pinMode(LED_PIN, OUTPUT);
    digitalWrite(LED_PIN, LOW);

    if (ei_camera_init() == false) {
        Serial.println("Erreur camera !");
    } else {
        Serial.println("Camera OK - pret !");
    }
    delay(2000);
}

void loop() {
    snapshot_buf = (uint8_t*)malloc(EI_CAMERA_RAW_FRAME_BUFFER_COLS *
                                    EI_CAMERA_RAW_FRAME_BUFFER_ROWS *
                                    EI_CAMERA_FRAME_BYTE_SIZE);
    if (snapshot_buf == nullptr) {
        Serial.println("ERR: malloc");
        delay(500);
        return;
    }

    ei::signal_t signal;
    signal.total_length = EI_CLASSIFIER_INPUT_WIDTH * EI_CLASSIFIER_INPUT_HEIGHT;
    signal.get_data = &ei_camera_get_data;

    if (ei_camera_capture((size_t)EI_CLASSIFIER_INPUT_WIDTH,
                          (size_t)EI_CLASSIFIER_INPUT_HEIGHT,
                          snapshot_buf) == false) {
        free(snapshot_buf);
        delay(500);
        return;
    }

    ei_impulse_result_t result = { 0 };
    EI_IMPULSE_ERROR err = run_classifier(&signal, &result, false);
    if (err != EI_IMPULSE_OK) {
        free(snapshot_buf);
        delay(500);
        return;
    }

#if EI_CLASSIFIER_OBJECT_DETECTION == 1
    // Trouve la meilleure balle
    int best_score = -9999;
    int best_idx   = -1;

    for (uint32_t i = 0; i < result.bounding_boxes_count; i++) {
        ei_impulse_result_bounding_box_t bb = result.bounding_boxes[i];
        if (bb.value < 0.3) continue;
        int cx      = bb.x + bb.width / 2;
        int offsetX = abs(cx - (EI_CLASSIFIER_INPUT_WIDTH / 2));
        int score   = (int)bb.width - offsetX;
        if (score > best_score) {
            best_score = score;
            best_idx   = i;
        }
    }

    if (best_idx >= 0) {
        ei_impulse_result_bounding_box_t bb = result.bounding_boxes[best_idx];
        int cx      = bb.x + bb.width / 2;
        int taille  = bb.width;
        int offsetX = abs(cx - (EI_CLASSIFIER_INPUT_WIDTH / 2));

        // Filtre
        if (t_filtered == 0) t_filtered = taille;
        t_filtered = ALPHA * taille + (1.0 - ALPHA) * t_filtered;

        // Condition ramassage : balle proche ET centrée
        bool proche  = (t_filtered >= BBOX_PROCHE);
        bool centree = (offsetX <= ANGLE_TOL);

        if (proche && centree) {
            digitalWrite(LED_PIN, HIGH);  // LED allumée → position ramassage !
            Serial.println(">>> POSITION RAMASSAGE <<<");
        } else {
            digitalWrite(LED_PIN, LOW);
            if (!centree)
                Serial.printf("Recentrer : offsetX=%d\n", offsetX);
            else
                Serial.printf("Approcher : T_FILT=%.1f\n", t_filtered);
        }

        Serial.printf("Taille:%d T_FILT:%.1f OffsetX:%d Score:%.2f\n",
                      taille, t_filtered, offsetX, bb.value);
    } else {
        digitalWrite(LED_PIN, LOW);
        t_filtered = 0;
        Serial.println("Aucune balle");
    }
#endif

    free(snapshot_buf);
    delay(100);
}

#if !defined(EI_CLASSIFIER_SENSOR) || EI_CLASSIFIER_SENSOR != EI_CLASSIFIER_SENSOR_CAMERA
#error "Invalid model for current sensor"
#endif