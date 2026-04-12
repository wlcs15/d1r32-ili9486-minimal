#include <Arduino.h>
#include "hal/tft.h"

// Use the TFT instance from hal/tft.cpp
extern TFT_eSPI tft;

void setup() {
    Serial.begin(115200);
    delay(3000);
    Serial.println("\n\n=== Minimal D1 R32 + 4\" ILI9486 - Matching OpenHASP TFT_eSPI ===");
    Serial.printf("Compiled: %s %s | Free heap: %u\n", __DATE__, __TIME__, ESP.getFreeHeap());

    // Initialize TFT through HAL
    tft_init();
    
    // Wait a bit for display to stabilize
    delay(500);
    
    // Draw our content (screen already cleared in tft_init)
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
        
        // Add periodic screen refresh to ensure display is working
        tft.setCursor(0, 200);
        tft.setTextSize(2);
        tft.setTextColor(TFT_YELLOW, TFT_BLACK);
        tft.printf("Uptime: %lus", millis()/1000);
        
        last = millis();
    }
}
