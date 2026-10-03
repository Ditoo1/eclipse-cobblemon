#import <UIKit/UIKit.h>

// Paleta de eclipse/diseno/TOKENS.md (copiada de la app Android).
#define EC_HEX(h, a) [UIColor colorWithRed:(((h) >> 16) & 0xFF) / 255.0 green:(((h) >> 8) & 0xFF) / 255.0 blue:((h) & 0xFF) / 255.0 alpha:(a)]

#define ECGold      EC_HEX(0xF5C542, 1)
#define ECGoldHi    EC_HEX(0xF8D46A, 1)
#define ECGoldLo    EC_HEX(0xE5B33A, 1)
#define ECNight     EC_HEX(0x07070A, 1)
#define ECSurface   EC_HEX(0x0F0E13, 1)
#define ECSheetBg   EC_HEX(0x111015, 1)
#define ECIvory     EC_HEX(0xF3EEDF, 1)
#define ECMuted     EC_HEX(0xA39C88, 1)
#define ECDim       EC_HEX(0x6E6858, 1)
#define ECHair      EC_HEX(0xF3EEDF, 0.10)
#define ECOnline    EC_HEX(0x7BD88F, 1)
#define ECDanger    EC_HEX(0xE07A6B, 1)
#define ECInk       EC_HEX(0x15110A, 1)

/// Registra lexend.ttf (fuente variable) del bundle. Llamar una vez al arrancar.
void ECRegisterFonts(void);

/// Lexend con el peso indicado (300–700). Si la fuente no está, usa la del sistema.
UIFont *ECFont(CGFloat size, CGFloat weight);

/// Texto con espaciado entre letras (tracking en em, como en Compose).
NSAttributedString *ECTracked(NSString *text, UIFont *font, UIColor *color, CGFloat em);

/// Icono SF Symbols en plantilla.
UIImage *ECSymbol(NSString *name, CGFloat pointSize, UIFontWeight weight);

/// Etiqueta con fuente, color y texto.
UILabel *ECLabel(NSString *text, CGFloat size, CGFloat weight, UIColor *color);

/// Imagen del castillo (fondo_eclipse) del bundle.
UIImage *ECBackgroundImage(void);
