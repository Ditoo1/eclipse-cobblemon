#import "ECSkin.h"

static NSString *const ECProfileBase = @"https://api.minecraftservices.com/minecraft/profile";

@implementation ECCape
@end

@implementation ECSkinProfile
- (ECCape *)activeCape {
    for (ECCape *c in self.capes) {
        if (c.active) return c;
    }
    return nil;
}
@end

@implementation ECSkinAPI

+ (NSMutableURLRequest *)request:(NSString *)url method:(NSString *)method token:(NSString *)token {
    NSMutableURLRequest *r = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
    r.HTTPMethod = method;
    r.timeoutInterval = 30;
    [r setValue:[@"Bearer " stringByAppendingString:token ?: @""] forHTTPHeaderField:@"Authorization"];
    [r setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    return r;
}

+ (void)send:(NSURLRequest *)request completion:(ECSkinCallback)completion {
    [[NSURLSession.sharedSession dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        ECSkinProfile *profile = nil;
        NSString *message = nil;
        NSInteger code = [(NSHTTPURLResponse *)response statusCode];
        NSDictionary *json = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
        if (![json isKindOfClass:NSDictionary.class]) json = nil;
        if (error) {
            message = [NSString stringWithFormat:@"Sem ligação: %@", error.localizedDescription];
        } else if (code < 200 || code >= 300) {
            NSString *detail = json[@"errorMessage"] ?: json[@"error"];
            switch (code) {
                case 400: message = [NSString stringWithFormat:@"Skin inválida: %@", detail ?: @"use um PNG de 64×64"]; break;
                case 401: message = @"Sessão expirada: inicie sessão novamente"; break;
                case 429: message = @"Demasiados pedidos. Aguarde um minuto e tente outra vez"; break;
                default: message = detail ? [NSString stringWithFormat:@"Erro da Mojang (%ld): %@", (long)code, detail]
                                          : [NSString stringWithFormat:@"Erro da Mojang (%ld)", (long)code];
            }
        } else {
            profile = [self parse:json];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(profile, message);
        });
    }] resume];
}

+ (ECSkinProfile *)parse:(NSDictionary *)o {
    ECSkinProfile *p = [ECSkinProfile new];
    for (NSDictionary *s in o[@"skins"]) {
        if ([s[@"state"] isEqualToString:@"ACTIVE"]) {
            p.skinUrl = [s[@"url"] stringByReplacingOccurrencesOfString:@"http://" withString:@"https://"];
            p.slim = [[s[@"variant"] uppercaseString] isEqualToString:@"SLIM"];
            break;
        }
    }
    NSMutableArray *capes = [NSMutableArray new];
    for (NSDictionary *c in o[@"capes"]) {
        ECCape *cape = [ECCape new];
        cape.capeId = c[@"id"];
        cape.alias = c[@"alias"] ?: @"Capa";
        cape.url = [c[@"url"] stringByReplacingOccurrencesOfString:@"http://" withString:@"https://"];
        cape.active = [c[@"state"] isEqualToString:@"ACTIVE"];
        [capes addObject:cape];
    }
    p.capes = capes;
    return p;
}

+ (void)profileWithToken:(NSString *)token completion:(ECSkinCallback)completion {
    [self send:[self request:ECProfileBase method:@"GET" token:token] completion:completion];
}

+ (void)uploadPNG:(NSData *)png slim:(BOOL)slim token:(NSString *)token completion:(ECSkinCallback)completion {
    NSMutableURLRequest *r = [self request:[ECProfileBase stringByAppendingString:@"/skins"] method:@"POST" token:token];
    NSString *boundary = [NSString stringWithFormat:@"----Eclipse%08X", arc4random()];
    [r setValue:[@"multipart/form-data; boundary=" stringByAppendingString:boundary] forHTTPHeaderField:@"Content-Type"];
    NSMutableData *body = [NSMutableData new];
    void (^add)(NSString *) = ^(NSString *s) { [body appendData:[s dataUsingEncoding:NSUTF8StringEncoding]]; };
    add([NSString stringWithFormat:@"--%@\r\nContent-Disposition: form-data; name=\"variant\"\r\n\r\n%@\r\n", boundary, slim ? @"slim" : @"classic"]);
    add([NSString stringWithFormat:@"--%@\r\nContent-Disposition: form-data; name=\"file\"; filename=\"skin.png\"\r\nContent-Type: image/png\r\n\r\n", boundary]);
    [body appendData:png];
    add([NSString stringWithFormat:@"\r\n--%@--\r\n", boundary]);
    r.HTTPBody = body;
    [self send:r completion:completion];
}

+ (void)changeVariantForURL:(NSString *)url slim:(BOOL)slim token:(NSString *)token completion:(ECSkinCallback)completion {
    NSMutableURLRequest *r = [self request:[ECProfileBase stringByAppendingString:@"/skins"] method:@"POST" token:token];
    [r setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    r.HTTPBody = [NSJSONSerialization dataWithJSONObject:@{@"variant": slim ? @"slim" : @"classic", @"url": url} options:0 error:nil];
    [self send:r completion:completion];
}

+ (void)resetWithToken:(NSString *)token completion:(ECSkinCallback)completion {
    [self send:[self request:[ECProfileBase stringByAppendingString:@"/skins/active"] method:@"DELETE" token:token] completion:completion];
}

+ (void)setCape:(NSString *)capeId token:(NSString *)token completion:(ECSkinCallback)completion {
    NSString *url = [ECProfileBase stringByAppendingString:@"/capes/active"];
    if (!capeId) {
        [self send:[self request:url method:@"DELETE" token:token] completion:completion];
        return;
    }
    NSMutableURLRequest *r = [self request:url method:@"PUT" token:token];
    [r setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    r.HTTPBody = [NSJSONSerialization dataWithJSONObject:@{@"capeId": capeId} options:0 error:nil];
    [self send:r completion:completion];
}

+ (void)downloadImage:(NSString *)url completion:(void (^)(UIImage *))completion {
    NSURL *u = url ? [NSURL URLWithString:url] : nil;
    if (!u) {
        completion(nil);
        return;
    }
    [[NSURLSession.sharedSession dataTaskWithURL:u completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSInteger code = [(NSHTTPURLResponse *)response statusCode];
        UIImage *image = (data && code >= 200 && code < 300) ? [UIImage imageWithData:data scale:1] : nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(image);
        });
    }] resume];
}

@end

@implementation ECSkinRender

/// Dibuja el rectángulo (sx, sy, w, h) de la textura en la celda (dx, dy), sin suavizado.
static void part(CGImageRef img, int scale, int sx, int sy, int w, int h, CGFloat dx, CGFloat dy, CGFloat px, CGPoint o) {
    CGImageRef crop = CGImageCreateWithImageInRect(img, CGRectMake(sx * scale, sy * scale, w * scale, h * scale));
    if (!crop) return;
    CGRect dst = CGRectMake(round(o.x + dx * px), round(o.y + dy * px), round(w * px), round(h * px));
    [[UIImage imageWithCGImage:crop] drawInRect:dst];
    CGImageRelease(crop);
}

+ (UIImage *)render:(CGSize)size draw:(void (^)(void))draw {
    UIGraphicsImageRendererFormat *fmt = [UIGraphicsImageRendererFormat preferredFormat];
    fmt.opaque = NO;
    UIGraphicsImageRenderer *r = [[UIGraphicsImageRenderer alloc] initWithSize:size format:fmt];
    return [r imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        CGContextSetInterpolationQuality(ctx.CGContext, kCGInterpolationNone);
        CGContextSetShouldAntialias(ctx.CGContext, NO);
        draw();
    }];
}

+ (UIImage *)headFromTexture:(UIImage *)texture size:(CGFloat)size {
    CGImageRef img = texture.CGImage;
    if (!img) return nil;
    int scale = MAX(1, (int)CGImageGetWidth(img) / 64);
    CGFloat px = size / 8;
    return [self render:CGSizeMake(size, size) draw:^{
        part(img, scale, 8, 8, 8, 8, 0, 0, px, CGPointZero);
        part(img, scale, 40, 8, 8, 8, 0, 0, px, CGPointZero);
    }];
}

+ (UIImage *)figureFromTexture:(UIImage *)texture slim:(BOOL)slim back:(BOOL)back cape:(UIImage *)cape pixel:(CGFloat)px {
    CGImageRef img = texture.CGImage;
    if (!img) return nil;
    int scale = MAX(1, (int)CGImageGetWidth(img) / 64);
    BOOL legacy = CGImageGetHeight(img) / scale == 32;
    int aw = slim ? 3 : 4;
    CGPoint o = CGPointZero;
    CGImageRef capeImg = cape.CGImage;
    return [self render:CGSizeMake(16 * px, 32 * px) draw:^{
        #define P(sx, sy, w, h, dx, dy) part(img, scale, sx, sy, w, h, dx, dy, px, o)
        if (!back) {
            P(8, 8, 8, 8, 4, 0); P(20, 20, 8, 12, 4, 8);
            P(44, 20, aw, 12, 4 - aw, 8);
            if (legacy) P(44, 20, aw, 12, 12, 8); else P(36, 52, aw, 12, 12, 8);
            P(4, 20, 4, 12, 4, 20);
            if (legacy) P(4, 20, 4, 12, 8, 20); else P(20, 52, 4, 12, 8, 20);
            P(40, 8, 8, 8, 4, 0);
            if (!legacy) {
                P(20, 36, 8, 12, 4, 8); P(44, 36, aw, 12, 4 - aw, 8); P(52, 52, aw, 12, 12, 8);
                P(4, 36, 4, 12, 4, 20); P(4, 52, 4, 12, 8, 20);
            }
        } else {
            int rx = slim ? 51 : 52;
            int lx = slim ? 43 : 44;
            P(24, 8, 8, 8, 4, 0); P(32, 20, 8, 12, 4, 8);
            P(rx, 20, aw, 12, 12, 8);
            if (legacy) P(rx, 20, aw, 12, 4 - aw, 8); else P(lx, 52, aw, 12, 4 - aw, 8);
            P(12, 20, 4, 12, 8, 20);
            if (legacy) P(12, 20, 4, 12, 4, 20); else P(28, 52, 4, 12, 4, 20);
            P(56, 8, 8, 8, 4, 0);
            if (!legacy) {
                P(32, 36, 8, 12, 4, 8); P(rx, 36, aw, 12, 12, 8); P(lx + 16, 52, aw, 12, 4 - aw, 8);
                P(12, 36, 4, 12, 8, 20); P(12, 52, 4, 12, 4, 20);
            }
            if (capeImg) {
                int cs = MAX(1, (int)CGImageGetWidth(capeImg) / 64);
                part(capeImg, cs, 1, 1, 10, 16, 3, 8, px, o);
            }
        }
        #undef P
    }];
}

+ (UIImage *)capeThumb:(UIImage *)cape pixel:(CGFloat)px {
    CGImageRef img = cape.CGImage;
    if (!img) return nil;
    int scale = MAX(1, (int)CGImageGetWidth(img) / 64);
    return [self render:CGSizeMake(10 * px, 16 * px) draw:^{
        part(img, scale, 1, 1, 10, 16, 0, 0, px, CGPointZero);
    }];
}

@end
