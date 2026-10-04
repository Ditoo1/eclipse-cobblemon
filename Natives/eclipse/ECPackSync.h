#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Manifiesto del pack publicado en el panel (formato 1, ver docs/pack-sync.md).
@interface ECPackManifest : NSObject
@property(nonatomic, readonly) long long revision;
@property(nonatomic, readonly) NSString *minecraft;
/// Versión de Fabric Loader; nil = vanilla.
@property(nonatomic, readonly, nullable) NSString *loaderVersion;
/// Versión que hay que lanzar: el perfil de Fabric o la vanilla.
@property(nonatomic, readonly) NSString *versionId;
@end

/// Sincroniza el .minecraft con el pack del servidor. Mismas reglas que PackSync.kt (Android).
/// Los métodos son bloqueantes: llamarlos fuera del hilo principal.
@interface ECPackSync : NSObject

- (instancetype)initWithGameDir:(NSString *)gameDir manifestURL:(NSURL *)url;

/// Baja y valida el manifiesto (con ETag). Sin conexión devuelve nil: no se juega sin verificar el pack.
- (nullable ECPackManifest *)fetch:(NSError **)error;

/// Descarga el perfil de Fabric si el pack lo pide. Devuelve la versión que hay que lanzar.
- (nullable NSString *)installLoader:(ECPackManifest *)manifest error:(NSError **)error;

/// Deja los archivos igual que el manifiesto. Si algo falla, el .minecraft queda como estaba.
/// `verify` relee el SHA-1 de todo sin fiarse del estado guardado.
- (BOOL)apply:(ECPackManifest *)manifest
       verify:(BOOL)verify
          log:(void (^)(NSString *message))log
     progress:(void (^)(int64_t done, int64_t total))progress
        error:(NSError **)error;

+ (BOOL)isSafePath:(NSString *)path;

@end

NS_ASSUME_NONNULL_END
