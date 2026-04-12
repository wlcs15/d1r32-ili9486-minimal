#include "tft.h"
#include "hasp_conf.h"

#if defined(HASP_USE_SPI_TFT) && HASP_USE_SPI_TFT > 0

#include "ArduinoLog.h"
#include "driver/timer.h"

#ifdef USE_TFT_ESPI
#include <TFT_eSPI.h>

// Include the user setup file
#include <UserSetup.h>
#include "../user_setups/setup_ttgo_lolin32.h"    

TFT_eSPI tft = TFT_eSPI();

void tft_init()
{
    Serial.println("TFT init starting...");
    
    // Set backlight pin LOW initially
    pinMode(TFT_BCKL, OUTPUT);
    digitalWrite(TFT_BCKL, LOW);
    Serial.println("Backlight LOW");
    
    // Initialize TFT
    tft.begin();
    tft.setRotation(1);  // Set rotation directly here
    tft.fillScreen(TFT_BLACK);
    
    // Turn on backlight after initialization
    digitalWrite(TFT_BCKL, HIGH);
    Serial.println("Backlight HIGH");
    
    // Clear screen with a color to verify functionality
    tft.setCursor(0, 0);
    tft.setTextColor(TFT_WHITE);
    tft.setTextSize(2);
    tft.println("TFT Ready");
    
    // Add a delay to ensure display has time to show content
    delay(200);
    
    LOG_INFO(TAG_TFT, "TFT initialized");
    Serial.println("TFT init completed");
}

void tft_write_command(uint8_t cmd)
{
    tft.writecommand(cmd);
}

void tft_write_data(uint8_t data)
{
    tft.writedata(data);
}

#endif // USE_TFT_ESPI
#endif // HASP_USE_SPI_TFT
