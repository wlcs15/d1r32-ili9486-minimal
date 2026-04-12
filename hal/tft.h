#ifndef TFT_H
#define TFT_H

#ifdef __cplusplus
#include <TFT_eSPI.h>
extern TFT_eSPI tft;
void tft_init(void);
#else
// C-compatible declarations
extern void tft_init(void);
#endif

#endif // TFT_H
