#include <Arduino.h>
#include <TFT_eSPI.h>

TFT_eSPI tft = TFT_eSPI();

void setup() {
    Serial.begin(115200);
    delay(3000);
    Serial.println("\n\n=== Minimal D1 R32 + 4\" ILI9486 - Matching OpenHASP TFT_eSPI ===");
    Serial.printf("Compiled: %s %s | Free heap: %u\n", __DATE__, __TIME__, ESP.getFreeHeap());

    pinMode(13, OUTPUT);
    digitalWrite(13, HIGH);
    Serial.println("Backlight HIGH");

    Serial.println("tft.init() starting...");
    tft.init();
    delay(100);

    tft.setRotation(1);   // Try 1 first, then change to 3 and re-flash if needed
    tft.fillScreen(TFT_BLACK);
    tft.setTextColor(TFT_WHITE, TFT_BLACK);
    tft.setTextSize(3);

    tft.drawString("OpenHASP worked", 40, 80);
    tft.drawString("This should too", 50, 140);

    Serial.println("init + draw commands completed");
    Serial.println("If still blank: change setRotation to 3 and re-flash");
}

void loop() {
    static uint32_t last = 0;
    if (millis() - last > 5000) {
        Serial.printf("[Uptime %lu s] Free heap: %u\n", millis()/1000, ESP.getFreeHeap());
        last = millis();
    }
}