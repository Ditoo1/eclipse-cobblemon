#include <CommonCrypto/CommonDigest.h>
#import "BaseAuthenticator.h"

@implementation LocalAuthenticator

/// UUID de jugador offline, igual que el servidor: UUID v3 de "OfflinePlayer:<nombre>".
+ (NSString *)offlineUUIDForName:(NSString *)name {
    NSData *data = [[@"OfflinePlayer:" stringByAppendingString:name] dataUsingEncoding:NSUTF8StringEncoding];
    unsigned char md5[CC_MD5_DIGEST_LENGTH];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    CC_MD5(data.bytes, (CC_LONG)data.length, md5);
#pragma clang diagnostic pop
    md5[6] = (md5[6] & 0x0f) | 0x30;
    md5[8] = (md5[8] & 0x3f) | 0x80;
    NSMutableString *hex = [NSMutableString new];
    for (int i = 0; i < 16; i++) {
        if (i == 4 || i == 6 || i == 8 || i == 10) [hex appendString:@"-"];
        [hex appendFormat:@"%02x", md5[i]];
    }
    return hex;
}

- (void)loginWithCallback:(Callback)callback {
    self.authData[@"oldusername"] = self.authData[@"username"] = self.authData[@"input"];
    self.authData[@"profileId"] = [LocalAuthenticator offlineUUIDForName:self.authData[@"input"]];
    callback(nil, [super saveChanges]);
}

- (void)refreshTokenWithCallback:(Callback)callback {
    // Nothing to do
    callback(nil, YES);
}

@end
