#include <Arduino.h>
#include <TFT_eSPI.h>

extern TFT_eSPI tft; // Use the TFT instance from hal/tft.cpp

void setup() {
    Serial.begin(115200);
    delay(3000);
    Serial.println("\n\n=== Minimal D1 R32 + 4\" ILI9486 - Matching OpenHASP TFT_eSPI ===");
    Serial.printf("Compiled: %s %s | Free heap: %u\n", __DATE__, __TIME__, ESP.getFreeHeap());

    // Initialize TFT through HAL
    extern void tft_init(); // Declare the function from hal/tft.cpp
    tft_init();
    
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
