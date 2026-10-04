#import <CommonCrypto/CommonDigest.h>

#import "ECPackSync.h"

// Sincronización del pack (mods, resource packs, configs…). Especificación: docs/pack-sync.md.
// Debe comportarse igual que android/app/.../game/PackSync.kt.

static NSString *const ECPackPlatform = @"ios";
static NSString *const ECPackUserAgent = @"EclipseCobblemon/1.0";
static NSString *const ECFabricMeta = @"https://meta.fabricmc.net/v2";
static const NSInteger ECPackParallel = 6;

static NSError *ECPackError(NSString *format, ...) NS_FORMAT_FUNCTION(1, 2);
static NSError *ECPackError(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *msg = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    return [NSError errorWithDomain:@"ECPackSync" code:1 userInfo:@{NSLocalizedDescriptionKey: msg}];
}

static NSString *ECSHA1File(NSString *path) {
    NSInputStream *in = [NSInputStream inputStreamWithFileAtPath:path];
    if (!in) return nil;
    [in open];
    CC_SHA1_CTX ctx;
    CC_SHA1_Init(&ctx);
    uint8_t *buf = malloc(64 * 1024);
    NSInteger n;
    BOOL ok = YES;
    while ((n = [in read:buf maxLength:64 * 1024]) != 0) {
        if (n < 0) { ok = NO; break; }
        CC_SHA1_Update(&ctx, buf, (CC_LONG)n);
    }
    free(buf);
    [in close];
    if (!ok) return nil;
    unsigned char digest[CC_SHA1_DIGEST_LENGTH];
    CC_SHA1_Final(digest, &ctx);
    NSMutableString *hex = [NSMutableString stringWithCapacity:40];
    for (int i = 0; i < CC_SHA1_DIGEST_LENGTH; i++) [hex appendFormat:@"%02x", digest[i]];
    return hex;
}

#pragma mark - Manifiesto

@interface ECPackManifest ()
@property(nonatomic, readwrite) long long revision;
@property(nonatomic, readwrite) NSString *minecraft;
@property(nonatomic, readwrite, nullable) NSString *loaderVersion;
@property(nonatomic) NSString *objects;
@property(nonatomic) NSArray<NSString *> *exclusive;
/// path, sha1, size (NSNumber), mode ("sync"/"once"), platforms (NSArray o NSNull)
@property(nonatomic) NSArray<NSDictionary *> *files;
@property(nonatomic) NSData *text;
@property(nonatomic, nullable) NSString *etag;
@end

@implementation ECPackManifest

- (NSString *)versionId {
    return self.loaderVersion ? [NSString stringWithFormat:@"fabric-loader-%@-%@", self.loaderVersion, self.minecraft] : self.minecraft;
}

- (NSArray<NSDictionary *> *)filesForPlatform:(NSString *)platform {
    NSMutableArray *out = [NSMutableArray new];
    for (NSDictionary *f in self.files) {
        id platforms = f[@"platforms"];
        if (![platforms isKindOfClass:NSArray.class] || [platforms containsObject:platform]) [out addObject:f];
    }
    return out;
}

+ (nullable instancetype)parse:(NSData *)text etag:(nullable NSString *)etag error:(NSError **)error {
    NSString *problem = nil;
    ECPackManifest *m = [self parse:text problem:&problem];
    if (!m) {
        if (error) *error = ECPackError(@"Manifesto do pack inválido: %@", problem);
        return nil;
    }
    m.text = text;
    m.etag = etag;
    return m;
}

+ (nullable instancetype)parse:(NSData *)text problem:(NSString **)problem {
#define REQUIRE(cond, ...) if (!(cond)) { *problem = [NSString stringWithFormat:__VA_ARGS__]; return nil; }
    id json = [NSJSONSerialization JSONObjectWithData:text options:0 error:nil];
    REQUIRE([json isKindOfClass:NSDictionary.class], @"não é JSON");
    REQUIRE([json[@"format"] isKindOfClass:NSNumber.class] && [json[@"format"] intValue] == 1, @"formato %@ não suportado (esta app lê o 1)", json[@"format"]);
    REQUIRE([json[@"revision"] isKindOfClass:NSNumber.class], @"falta revision");
    REQUIRE([json[@"minecraft"] isKindOfClass:NSString.class], @"falta minecraft");
    REQUIRE([json[@"files"] isKindOfClass:NSArray.class], @"falta files");

    NSRegularExpression *sha1Re = [NSRegularExpression regularExpressionWithPattern:@"^[0-9a-f]{40}$" options:0 error:nil];
    NSMutableArray *files = [NSMutableArray new];
    NSMutableSet *seen = [NSMutableSet new];
    for (NSDictionary *f in json[@"files"]) {
        REQUIRE([f isKindOfClass:NSDictionary.class] && [f[@"path"] isKindOfClass:NSString.class], @"entrada sem path");
        NSString *path = f[@"path"];
        REQUIRE([ECPackSync isSafePath:path], @"caminho não permitido: %@", path);
        REQUIRE(![seen containsObject:path.lowercaseString], @"caminho repetido: %@", path);
        [seen addObject:path.lowercaseString];
        NSString *sha1 = [f[@"sha1"] isKindOfClass:NSString.class] ? [f[@"sha1"] lowercaseString] : @"";
        REQUIRE([sha1Re numberOfMatchesInString:sha1 options:0 range:NSMakeRange(0, sha1.length)] == 1, @"sha1 inválido em %@", path);
        REQUIRE([f[@"size"] isKindOfClass:NSNumber.class] && [f[@"size"] longLongValue] >= 0, @"tamanho inválido em %@", path);
        NSString *mode = f[@"mode"] ?: @"sync";
        REQUIRE([mode isEqual:@"sync"] || [mode isEqual:@"once"], @"modo desconhecido: %@", mode);
        id platforms = f[@"platforms"];
        REQUIRE(platforms == nil || [platforms isKindOfClass:NSArray.class], @"platforms inválido em %@", path);
        [files addObject:@{@"path": path, @"sha1": sha1, @"size": f[@"size"], @"mode": mode, @"platforms": platforms ?: NSNull.null}];
    }

    NSArray *exclusive = json[@"exclusive"] ?: @[];
    REQUIRE([exclusive isKindOfClass:NSArray.class], @"exclusive inválido");
    for (NSString *dir in exclusive) {
        REQUIRE([dir isKindOfClass:NSString.class] && [ECPackSync isSafePath:dir], @"pasta não permitida: %@", dir);
    }

    NSString *loaderVersion = nil;
    NSDictionary *loader = json[@"loader"];
    if (loader && ![loader isKindOfClass:NSNull.class]) {
        REQUIRE([loader isKindOfClass:NSDictionary.class] && [loader[@"type"] isEqual:@"fabric"], @"loader não suportado: %@", loader[@"type"]);
        loaderVersion = loader[@"version"];
        NSRegularExpression *verRe = [NSRegularExpression regularExpressionWithPattern:@"^[0-9A-Za-z.+_-]{1,64}$" options:0 error:nil];
        REQUIRE([loaderVersion isKindOfClass:NSString.class] &&
            [verRe numberOfMatchesInString:loaderVersion options:0 range:NSMakeRange(0, loaderVersion.length)] == 1,
            @"versão do loader inválida: %@", loaderVersion);
    }
#undef REQUIRE

    ECPackManifest *m = [ECPackManifest new];
    m.revision = [json[@"revision"] longLongValue];
    m.minecraft = json[@"minecraft"];
    m.loaderVersion = loaderVersion;
    m.objects = [json[@"objects"] isKindOfClass:NSString.class] ? json[@"objects"] : @"objects/";
    m.exclusive = exclusive;
    m.files = files;
    return m;
}

@end

#pragma mark - Sincronización

@interface ECPackSync ()
@property(nonatomic) NSString *gameDir;
@property(nonatomic) NSURL *manifestURL;
@property(nonatomic) NSURLSession *session;
@property(nonatomic) NSString *statePath, *cachePath, *stagingDir;
@end

@implementation ECPackSync

+ (BOOL)isSafePath:(NSString *)path {
    static NSSet *protected;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        protected = [NSSet setWithArray:@[
            @".eclipse", @"saves", @"screenshots", @"logs", @"crash-reports",
            @"versions", @"libraries", @"assets", @"accounts", @"controlmap",
            @"options.txt", @"launcher_profiles.json", @"launcher_preferences.plist"
        ]];
    });
    if (path.length == 0 || path.length > 512 || [path hasPrefix:@"/"] ||
        [path containsString:@"\\"] || [path containsString:@":"]) return NO;
    NSArray *parts = [path componentsSeparatedByString:@"/"];
    for (NSString *p in parts) {
        if (p.length == 0 || [p isEqualToString:@"."] || [p isEqualToString:@".."]) return NO;
    }
    return ![protected containsObject:[parts[0] lowercaseString]];
}

- (instancetype)initWithGameDir:(NSString *)gameDir manifestURL:(NSURL *)url {
    self = [super init];
    _gameDir = gameDir;
    _manifestURL = url;
    NSString *meta = [gameDir stringByAppendingPathComponent:@".eclipse"];
    _statePath = [meta stringByAppendingPathComponent:@"pack-state.json"];
    _cachePath = [meta stringByAppendingPathComponent:@"pack-manifest.json"];
    _stagingDir = [meta stringByAppendingPathComponent:@"staging"];
    NSURLSessionConfiguration *config = NSURLSessionConfiguration.ephemeralSessionConfiguration;
    config.timeoutIntervalForRequest = 30;
    config.HTTPAdditionalHeaders = @{@"User-Agent": ECPackUserAgent};
    config.HTTPMaximumConnectionsPerHost = ECPackParallel;
    _session = [NSURLSession sessionWithConfiguration:config];
    return self;
}

#pragma mark Red

/// Petición bloqueante; devuelve el cuerpo y la respuesta.
- (nullable NSData *)send:(NSURLRequest *)request response:(NSHTTPURLResponse **)response error:(NSError **)error {
    __block NSData *body;
    __block NSURLResponse *resp;
    __block NSError *err;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    [[self.session dataTaskWithRequest:request completionHandler:^(NSData *d, NSURLResponse *r, NSError *e) {
        body = d;
        resp = r;
        err = e;
        dispatch_semaphore_signal(sem);
    }] resume];
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    if (err || ![resp isKindOfClass:NSHTTPURLResponse.class]) {
        if (error) *error = err ?: ECPackError(@"Sem resposta de %@", request.URL.host);
        return nil;
    }
    *response = (NSHTTPURLResponse *)resp;
    return body ?: [NSData data];
}

/// Descarga bloqueante a `dest`.
- (BOOL)download:(NSURL *)url to:(NSString *)dest error:(NSError **)error {
    __block NSError *err;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    [[self.session downloadTaskWithURL:url completionHandler:^(NSURL *location, NSURLResponse *r, NSError *e) {
        NSInteger code = [r isKindOfClass:NSHTTPURLResponse.class] ? ((NSHTTPURLResponse *)r).statusCode : 0;
        if (e) {
            err = e;
        } else if (code < 200 || code > 299) {
            err = ECPackError(@"HTTP %ld em %@", (long)code, url.lastPathComponent);
        } else {
            // El archivo temporal desaparece al salir de este bloque
            NSFileManager *fm = NSFileManager.defaultManager;
            [fm removeItemAtPath:dest error:nil];
            NSError *moveErr;
            if (![fm moveItemAtURL:location toURL:[NSURL fileURLWithPath:dest] error:&moveErr]) err = moveErr;
        }
        dispatch_semaphore_signal(sem);
    }] resume];
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    if (err && error) *error = err;
    return err == nil;
}

- (nullable ECPackManifest *)fetch:(NSError **)error {
    NSDictionary *state = [self readState];
    BOOL haveCache = [NSFileManager.defaultManager fileExistsAtPath:self.cachePath];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:self.manifestURL
        cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:20];
    if (haveCache && [state[@"etag"] isKindOfClass:NSString.class]) {
        [req setValue:state[@"etag"] forHTTPHeaderField:@"If-None-Match"];
    }
    NSHTTPURLResponse *resp;
    NSError *netErr;
    NSData *body = [self send:req response:&resp error:&netErr];
    if (!body) {
        if (error) *error = ECPackError(@"Sem ligação ao servidor do pack. É preciso internet para jogar.");
        return nil;
    }
    if (resp.statusCode == 304 && haveCache) {
        return [ECPackManifest parse:[NSData dataWithContentsOfFile:self.cachePath] etag:state[@"etag"] error:error];
    }
    if (resp.statusCode < 200 || resp.statusCode > 299) {
        if (error) *error = ECPackError(@"Servidor do pack: HTTP %ld", (long)resp.statusCode);
        return nil;
    }
    return [ECPackManifest parse:body etag:[resp valueForHTTPHeaderField:@"ETag"] error:error];
}

- (nullable NSString *)installLoader:(ECPackManifest *)manifest error:(NSError **)error {
    if (!manifest.loaderVersion) return manifest.minecraft;
    NSString *versionId = manifest.versionId;
    NSString *path = [NSString stringWithFormat:@"%@/versions/%@/%@.json", self.gameDir, versionId, versionId];
    NSFileManager *fm = NSFileManager.defaultManager;
    if (![fm fileExistsAtPath:path]) {
        NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/versions/loader/%@/%@/profile/json",
            ECFabricMeta, manifest.minecraft, manifest.loaderVersion]];
        NSHTTPURLResponse *resp;
        NSData *body = [self send:[NSURLRequest requestWithURL:url] response:&resp error:error];
        if (!body) return nil;
        if (resp.statusCode != 200) {
            if (error) *error = ECPackError(@"Fabric Loader %@ não encontrado (HTTP %ld)", manifest.loaderVersion, (long)resp.statusCode);
            return nil;
        }
        [fm createDirectoryAtPath:path.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:nil];
        if (![body writeToFile:path options:NSDataWritingAtomic error:error]) return nil;
    }
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:path] options:0 error:nil];
    if (![json isKindOfClass:NSDictionary.class] || ![json[@"inheritsFrom"] isEqual:manifest.minecraft]) {
        [fm removeItemAtPath:path error:nil];
        if (error) *error = ECPackError(@"Perfil do Fabric inválido para %@", manifest.minecraft);
        return nil;
    }
    return versionId;
}

#pragma mark Aplicar

- (BOOL)apply:(ECPackManifest *)manifest
       verify:(BOOL)verify
          log:(void (^)(NSString *))log
     progress:(void (^)(int64_t, int64_t))progress
        error:(NSError **)error {
    NSFileManager *fm = NSFileManager.defaultManager;
    NSDictionary *state = [self readState];
    NSDictionary<NSString *, NSDictionary *> *oldFiles = [state[@"files"] isKindOfClass:NSDictionary.class] ? state[@"files"] : @{};
    if ([state[@"revision"] longLongValue] != manifest.revision) {
        log([NSString stringWithFormat:@"Pack: revisão %lld", manifest.revision]);
    }

    // 1. Plan
    NSArray<NSDictionary *> *wanted = [manifest filesForPlatform:ECPackPlatform];
    NSMutableSet<NSString *> *wantedPaths = [NSMutableSet new];
    for (NSDictionary *f in wanted) [wantedPaths addObject:f[@"path"]];
    NSMutableDictionary *newState = [NSMutableDictionary new];
    NSMutableArray<NSDictionary *> *toFetch = [NSMutableArray new];
    NSInteger upToDate = 0;
    for (NSDictionary *f in wanted) {
        NSString *target = [self.gameDir stringByAppendingPathComponent:f[@"path"]];
        NSDictionary *old = oldFiles[f[@"path"]];
        NSDictionary *attrs = [self regularFileAttributes:target];
        if (!attrs) {
            [toFetch addObject:f];
        } else if ([f[@"mode"] isEqual:@"once"]) {
            // Ya existe: es del jugador. Solo se recuerda si lo instaló el pack.
            upToDate++;
            if (old) newState[f[@"path"]] = [self entry:old withMode:f[@"mode"]];
        } else if (!verify && old && [old[@"sha1"] isEqual:f[@"sha1"]] &&
                   [old[@"size"] longLongValue] == attrs.fileSize &&
                   [old[@"mtime"] longLongValue] == [self mtime:attrs]) {
            upToDate++;
            newState[f[@"path"]] = [self entry:old withMode:f[@"mode"]];
        } else if ([ECSHA1File(target) isEqualToString:f[@"sha1"]]) {
            upToDate++;
            newState[f[@"path"]] = [self entryForFile:target spec:f];
        } else {
            [toFetch addObject:f];
        }
    }

    NSMutableOrderedSet<NSString *> *toDelete = [NSMutableOrderedSet new];
    for (NSString *path in oldFiles) {
        if ([wantedPaths containsObject:path] || ![ECPackSync isSafePath:path]) continue;
        NSString *file = [self.gameDir stringByAppendingPathComponent:path];
        if (![self regularFileAttributes:file]) continue;
        // Un "once" que el jugador modificó se queda
        if (![oldFiles[path][@"mode"] isEqual:@"once"] || [ECSHA1File(file) isEqualToString:oldFiles[path][@"sha1"]]) {
            [toDelete addObject:path];
        }
    }
    for (NSString *dir in manifest.exclusive) {
        NSString *root = [self.gameDir stringByAppendingPathComponent:dir];
        NSDirectoryEnumerator *e = [fm enumeratorAtPath:root];
        for (NSString *sub in e) {
            if (![e.fileAttributes.fileType isEqualToString:NSFileTypeRegular]) continue;
            NSString *rel = [dir stringByAppendingPathComponent:sub];
            if (![wantedPaths containsObject:rel]) [toDelete addObject:rel];
        }
    }

    // 2. Descargas: un objeto por hash aunque lo usen varias rutas
    NSMutableDictionary<NSString *, NSMutableArray<NSDictionary *> *> *byHash = [NSMutableDictionary new];
    NSMutableArray<NSString *> *hashOrder = [NSMutableArray new];
    for (NSDictionary *f in toFetch) {
        if (!byHash[f[@"sha1"]]) {
            byHash[f[@"sha1"]] = [NSMutableArray new];
            [hashOrder addObject:f[@"sha1"]];
        }
        [byHash[f[@"sha1"]] addObject:f];
    }
    int64_t total = 0;
    for (NSString *hash in hashOrder) total += [byHash[hash][0][@"size"] longLongValue];
    if (toFetch.count) {
        log([NSString stringWithFormat:@"Pack: %lu ficheiros para transferir (%.1f MB)", (unsigned long)toFetch.count, total / 1048576.0]);
    }
    progress(0, total);
    [fm createDirectoryAtPath:self.stagingDir withIntermediateDirectories:YES attributes:nil error:nil];

    __block int64_t done = 0;
    __block NSError *firstError;
    NSLock *lock = [NSLock new];
    dispatch_group_t group = dispatch_group_create();
    dispatch_semaphore_t gate = dispatch_semaphore_create(ECPackParallel);
    dispatch_queue_t queue = dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0);
    for (NSString *hash in hashOrder) {
        int64_t size = [byHash[hash][0][@"size"] longLongValue];
        // Se espera aquí (hilo de fondo) para no lanzar un hilo bloqueado por cada objeto
        dispatch_semaphore_wait(gate, DISPATCH_TIME_FOREVER);
        dispatch_group_async(group, queue, ^{
            [lock lock];
            BOOL skip = firstError != nil;
            [lock unlock];
            NSError *err;
            if (!skip && [self stage:hash size:size manifest:manifest error:&err]) {
                [lock lock];
                done += size;
                int64_t now = done;
                [lock unlock];
                progress(now, total);
            } else if (!skip) {
                [lock lock];
                if (!firstError) firstError = err;
                [lock unlock];
            }
            dispatch_semaphore_signal(gate);
        });
    }
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    if (firstError) {
        if (error) *error = firstError;
        return NO;
    }

    // 3. Aplicar
    for (NSString *hash in hashOrder) {
        NSString *staged = [self.stagingDir stringByAppendingPathComponent:hash];
        NSArray<NSDictionary *> *files = byHash[hash];
        for (NSUInteger i = 0; i < files.count; i++) {
            NSDictionary *f = files[i];
            NSString *target = [self.gameDir stringByAppendingPathComponent:f[@"path"]];
            BOOL isDir = NO;
            if ([fm fileExistsAtPath:target isDirectory:&isDir] && isDir) {
                if (error) *error = ECPackError(@"%@ existe como pasta", f[@"path"]);
                return NO;
            }
            [fm createDirectoryAtPath:target.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:nil];
            NSError *err;
            BOOL ok;
            if (i == files.count - 1) {
                ok = [self moveReplacing:staged to:target error:&err];
            } else {
                [fm removeItemAtPath:target error:nil];
                ok = [fm copyItemAtPath:staged toPath:target error:&err];
            }
            if (!ok) {
                if (error) *error = err;
                return NO;
            }
            newState[f[@"path"]] = [self entryForFile:target spec:f];
        }
    }
    for (NSString *path in toDelete) {
        if ([fm removeItemAtPath:[self.gameDir stringByAppendingPathComponent:path] error:nil]) {
            log([NSString stringWithFormat:@"Removido: %@", path]);
        }
    }
    [fm removeItemAtPath:self.stagingDir error:nil];

    NSMutableDictionary *stateOut = [@{@"revision": @(manifest.revision), @"files": newState} mutableCopy];
    if (manifest.etag) stateOut[@"etag"] = manifest.etag;
    NSData *stateData = [NSJSONSerialization dataWithJSONObject:stateOut options:NSJSONWritingSortedKeys error:nil];
    [stateData writeToFile:self.statePath options:NSDataWritingAtomic error:nil];
    [manifest.text writeToFile:self.cachePath options:NSDataWritingAtomic error:nil];

    log([NSString stringWithFormat:@"Pack revisão %lld: %lu transferidos, %lu removidos, %ld já estavam OK",
        manifest.revision, (unsigned long)toFetch.count, (unsigned long)toDelete.count, (long)upToDate]);
    return YES;
}

/// Descarga un objeto a staging (3 intentos); si ya estaba de un intento anterior y es válido, se reaprovecha.
- (BOOL)stage:(NSString *)hash size:(int64_t)size manifest:(ECPackManifest *)manifest error:(NSError **)error {
    NSString *staged = [self.stagingDir stringByAppendingPathComponent:hash];
    NSDictionary *attrs = [self regularFileAttributes:staged];
    if (attrs && (int64_t)attrs.fileSize == size && [ECSHA1File(staged) isEqualToString:hash]) return YES;
    NSString *rel = [NSString stringWithFormat:@"%@%@/%@", manifest.objects, [hash substringToIndex:2], hash];
    NSURL *url = [NSURL URLWithString:rel relativeToURL:self.manifestURL].absoluteURL;
    NSError *last;
    for (int attempt = 0; attempt < 3; attempt++) {
        if ([self download:url to:staged error:&last]) {
            attrs = [self regularFileAttributes:staged];
            if (attrs && (int64_t)attrs.fileSize == size && [ECSHA1File(staged) isEqualToString:hash]) return YES;
            last = ECPackError(@"Hash incorreto no objeto %@", hash);
        }
        [NSFileManager.defaultManager removeItemAtPath:staged error:nil];
    }
    if (error) *error = last;
    return NO;
}

- (BOOL)moveReplacing:(NSString *)src to:(NSString *)dest error:(NSError **)error {
    NSFileManager *fm = NSFileManager.defaultManager;
    if ([fm fileExistsAtPath:dest]) {
        return [fm replaceItemAtURL:[NSURL fileURLWithPath:dest] withItemAtURL:[NSURL fileURLWithPath:src]
            backupItemName:nil options:0 resultingItemURL:nil error:error];
    }
    return [fm moveItemAtPath:src toPath:dest error:error];
}

#pragma mark Estado

- (nullable NSDictionary *)regularFileAttributes:(NSString *)path {
    NSDictionary *attrs = [NSFileManager.defaultManager attributesOfItemAtPath:path error:nil];
    return [attrs.fileType isEqualToString:NSFileTypeRegular] ? attrs : nil;
}

/// Milisegundos, como File.lastModified() en Android.
- (long long)mtime:(NSDictionary *)attrs {
    return (long long)llround(attrs.fileModificationDate.timeIntervalSince1970 * 1000);
}

- (NSDictionary *)entryForFile:(NSString *)path spec:(NSDictionary *)f {
    NSDictionary *attrs = [self regularFileAttributes:path];
    return @{@"sha1": f[@"sha1"], @"size": @(attrs.fileSize), @"mtime": @([self mtime:attrs]), @"mode": f[@"mode"]};
}

- (NSDictionary *)entry:(NSDictionary *)old withMode:(NSString *)mode {
    NSMutableDictionary *e = [old mutableCopy];
    e[@"mode"] = mode;
    return e;
}

- (NSDictionary *)readState {
    NSData *data = [NSData dataWithContentsOfFile:self.statePath];
    id json = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
    return [json isKindOfClass:NSDictionary.class] ? json : @{};
}

@end
