#import <CoreText/CoreText.h>
#import "ECTheme.h"

static NSString *lexendName;

void ECRegisterFonts(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSURL *url = [NSBundle.mainBundle URLForResource:@"lexend" withExtension:@"ttf"];
        if (!url) return;
        CTFontManagerRegisterFontsForURL((__bridge CFURLRef)url, kCTFontManagerScopeProcess, NULL);
        NSArray *descs = CFBridgingRelease(CTFontManagerCreateFontDescriptorsFromURL((__bridge CFURLRef)url));
        CTFontDescriptorRef desc = (__bridge CTFontDescriptorRef)descs.firstObject;
        if (desc) {
            lexendName = CFBridgingRelease(CTFontDescriptorCopyAttribute(desc, kCTFontNameAttribute));
        }
    });
}

UIFont *ECFont(CGFloat size, CGFloat weight) {
    ECRegisterFonts();
    if (lexendName) {
        // Eje 'wght' de la fuente variable
        NSNumber *axis = @(0x77676874);
        UIFontDescriptor *d = [UIFontDescriptor fontDescriptorWithFontAttributes:@{
            UIFontDescriptorNameAttribute: lexendName,
            (__bridge NSString *)kCTFontVariationAttribute: @{axis: @(weight)}
        }];
        UIFont *font = [UIFont fontWithDescriptor:d size:size];
        if (font) return font;
    }
    UIFontWeight w = weight >= 700 ? UIFontWeightBold : weight >= 600 ? UIFontWeightSemibold :
        weight >= 500 ? UIFontWeightMedium : weight >= 400 ? UIFontWeightRegular : UIFontWeightLight;
    return [UIFont systemFontOfSize:size weight:w];
}

NSAttributedString *ECTracked(NSString *text, UIFont *font, UIColor *color, CGFloat em) {
    return [[NSAttributedString alloc] initWithString:text attributes:@{
        NSFontAttributeName: font,
        NSForegroundColorAttributeName: color,
        NSKernAttributeName: @(font.pointSize * em)
    }];
}

UIImage *ECSymbol(NSString *name, CGFloat pointSize, UIFontWeight weight) {
    UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:pointSize weight:weight];
    return [[UIImage systemImageNamed:name withConfiguration:cfg] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

UILabel *ECLabel(NSString *text, CGFloat size, CGFloat weight, UIColor *color) {
    UILabel *l = [UILabel new];
    l.text = text;
    l.font = ECFont(size, weight);
    l.textColor = color;
    return l;
}

UIImage *ECBackgroundImage(void) {
    static UIImage *image;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSString *path = [NSBundle.mainBundle pathForResource:@"fondo_eclipse" ofType:@"jpg"];
        image = [UIImage imageWithContentsOfFile:path];
    });
    return image;
}
