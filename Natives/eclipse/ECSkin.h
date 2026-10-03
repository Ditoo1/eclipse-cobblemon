#import <UIKit/UIKit.h>

@interface ECCape : NSObject
@property(nonatomic, copy) NSString *capeId, *alias, *url;
@property(nonatomic) BOOL active;
@property(nonatomic) UIImage *texture;
@end

/// Perfil de skin y capas de una cuenta Microsoft.
@interface ECSkinProfile : NSObject
@property(nonatomic, copy) NSString *skinUrl;
@property(nonatomic) BOOL slim;
@property(nonatomic) NSArray<ECCape *> *capes;
@property(nonatomic, readonly) ECCape *activeCape;
@end

typedef void (^ECSkinCallback)(ECSkinProfile *profile, NSString *error);

/// API oficial de Minecraft Services (igual que SkinApi.kt en Android).
@interface ECSkinAPI : NSObject
+ (void)profileWithToken:(NSString *)token completion:(ECSkinCallback)completion;
+ (void)uploadPNG:(NSData *)png slim:(BOOL)slim token:(NSString *)token completion:(ECSkinCallback)completion;
+ (void)changeVariantForURL:(NSString *)url slim:(BOOL)slim token:(NSString *)token completion:(ECSkinCallback)completion;
+ (void)resetWithToken:(NSString *)token completion:(ECSkinCallback)completion;
+ (void)setCape:(NSString *)capeId token:(NSString *)token completion:(ECSkinCallback)completion;
/// Descarga una imagen; completion en el hilo principal.
+ (void)downloadImage:(NSString *)url completion:(void (^)(UIImage *image))completion;
@end

/// Recortes de la textura en pixel art, sin suavizado.
@interface ECSkinRender : NSObject
/// Cabeza (con la capa del sombrero) a tamaño `size` puntos.
+ (UIImage *)headFromTexture:(UIImage *)texture size:(CGFloat)size;
/// Jugador completo 16×32 de frente o espalda, escalado a `pixel` puntos por píxel.
+ (UIImage *)figureFromTexture:(UIImage *)texture slim:(BOOL)slim back:(BOOL)back cape:(UIImage *)cape pixel:(CGFloat)pixel;
/// Parte trasera de la capa para el selector.
+ (UIImage *)capeThumb:(UIImage *)cape pixel:(CGFloat)pixel;
@end
