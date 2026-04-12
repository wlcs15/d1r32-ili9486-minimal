#ifndef TFT_H
#define TFT_H

#include <TFT_eSPI.h>

#ifdef __cplusplus
extern "C" {
#endif

extern TFT_eSPI tft;

void tft_init(void);

#ifdef __cplusplus
}
#endif

#endif // TFT_H
