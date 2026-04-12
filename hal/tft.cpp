#include "tft.h"
#include "hasp_conf.h"

#if defined(HASP_USE_SPI_TFT) && HASP_USE_SPI_TFT > 0

#include "ArduinoLog.h"
#include "driver/timer.h"

#ifdef USE_TFT_ESPI
#include <TFT_eSPI.h>

// Include the user setup file
#include <UserSetup.h>

TFT_eSPI tft = TFT_eSPI();

void tft_init()
{
    tft.begin();
    tft.setRotation(TFT_ROTATION);
    pinMode(TFT_BCKL, OUTPUT);
    digitalWrite(TFT_BCKL, HIGH); // Turn on backlight
    
    // Clear screen with a color to verify functionality
    tft.fillScreen(TFT_BLACK);
    tft.setCursor(0, 0);
    tft.setTextColor(TFT_WHITE);
    tft.setTextSize(2);
    tft.println("Initializing...");
    
    LOG_INFO(TAG_TFT, "TFT initialized");
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
