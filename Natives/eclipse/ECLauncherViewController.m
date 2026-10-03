#import <AuthenticationServices/AuthenticationServices.h>
#import <CommonCrypto/CommonDigest.h>
#import <PhotosUI/PhotosUI.h>
#include <sys/time.h>
#include <sys/utsname.h>
#import <objc/runtime.h>

#import "authenticator/BaseAuthenticator.h"
#import "AFNetworking.h"
#import "LauncherNavigationController.h"
#import "LauncherPreferences.h"
#import "LauncherSplitViewController.h"
#import "MinecraftResourceDownloadTask.h"
#import "MinecraftResourceUtils.h"
#import "PLProfiles.h"
#import "ios_uikit_bridge.h"
#import "utils.h"

#import "ECLauncherViewController.h"
#import "ECSkin.h"
#import "ECTheme.h"
#import "ECViews.h"

static NSString *const ECVersion = @"1.21.1";
static NSString *const ECServerName = @"Eclipse Cobblemon";
/// Dirección del servidor; nil mientras no esté abierto.
static NSString *const ECServerAddress = nil;
static NSString *const ECProfileName = @"Eclipse Cobblemon";
static NSString *const ECRendererLabel = @"Metal (ANGLE)";
static NSString *const ECNotificationLog = @"ECLogChanged";
static void *ECProgressContext = &ECProgressContext;

#pragma mark - Registo

static NSMutableArray<NSString *> *ECLogLines(void) {
    static NSMutableArray *lines;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ lines = [NSMutableArray new]; });
    return lines;
}

void ECLog(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *msg = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    NSLog(@"[Eclipse] %@", msg);
    static NSDateFormatter *fmt;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        fmt = [NSDateFormatter new];
        fmt.dateFormat = @"HH:mm:ss";
    });
    NSString *line = [NSString stringWithFormat:@"[%@] %@", [fmt stringFromDate:NSDate.date], msg];
    dispatch_async(dispatch_get_main_queue(), ^{
        NSMutableArray *lines = ECLogLines();
        [lines addObject:line];
        if (lines.count > 300) [lines removeObjectsInRange:NSMakeRange(0, lines.count - 300)];
        [NSNotificationCenter.defaultCenter postNotificationName:ECNotificationLog object:nil];
    });
}

#pragma mark - Dispositivo

typedef NS_ENUM(NSInteger, ECTier) {
    ECTierOptimal,
    ECTierRecommended,
    ECTierMinimum,
    ECTierNotRecommended
};

static double ECDeviceRAMGB(void) {
    return NSProcessInfo.processInfo.physicalMemory / 1073741824.0;
}

/// Nivel automático según la RAM (INSTRUCCIONES_IA.md §4.11). iOS reporta algo menos que la RAM nominal.
static ECTier ECDeviceTier(void) {
    double gb = ECDeviceRAMGB();
    if (gb >= 7.0) return ECTierOptimal;
    if (gb >= 5.0) return ECTierRecommended;
    if (gb >= 3.5) return ECTierMinimum;
    return ECTierNotRecommended;
}

static NSString *ECTierName(ECTier tier) {
    switch (tier) {
        case ECTierOptimal: return @"Ótimo";
        case ECTierRecommended: return @"Recomendado";
        case ECTierMinimum: return @"Mínimo";
        default: return @"Não recomendado";
    }
}

static int ECRecommendedRAM(void) {
    switch (ECDeviceTier()) {
        case ECTierOptimal: return 3072;
        case ECTierRecommended: return 2560;
        case ECTierMinimum: return 1536;
        default: return 1024;
    }
}

static int ECMaxRAM(void) {
    int mb = (int)(ECDeviceRAMGB() * 1024 * 0.6) / 256 * 256;
    return MAX(1024, MIN(6144, mb));
}

static int ECRenderDistance(void) {
    switch (ECDeviceTier()) {
        case ECTierOptimal: return 8;
        case ECTierRecommended: return 6;
        case ECTierMinimum: return 4;
        default: return 2;
    }
}

static NSString *ECDeviceModel(void) {
    struct utsname info;
    uname(&info);
    return @(info.machine);
}

#pragma mark - Estado

typedef NS_ENUM(NSInteger, ECStage) {
    ECStageIdle,
    ECStageVersion,
    ECStageFiles,
    ECStageJava,
    ECStageLaunching
};

typedef NS_ENUM(NSInteger, ECSheetKind) {
    ECSheetNone,
    ECSheetProfile,
    ECSheetSettings
};

@interface ECLauncherViewController () <ASWebAuthenticationPresentationContextProviding, UITextFieldDelegate, PHPickerViewControllerDelegate, UIDocumentPickerDelegate>

// Acceso
@property(nonatomic) UIView *loginView;
@property(nonatomic) UIView *loginPanel;
@property(nonatomic) NSLayoutConstraint *loginPanelBottom;
@property(nonatomic) ECButton *msButton;
@property(nonatomic) UITextField *nameField;
@property(nonatomic) UIButton *goButton;
@property(nonatomic) UILabel *nameHint;
@property(nonatomic) ASWebAuthenticationSession *authSession;
@property(nonatomic) BOOL loggingIn;

// Inicio
@property(nonatomic) UIView *homeView;
@property(nonatomic) UIButton *avatarButton;
@property(nonatomic) UIImageView *heroImage;
@property(nonatomic) UIView *heroVeil;
@property(nonatomic) UIView *chipDot;
@property(nonatomic) ECPlayControl *playControl;
@property(nonatomic) UILabel *statusTitle, *statusSub;
@property(nonatomic) ECStarStrip *stars;
@property(nonatomic) UILabel *stepsLabel;

// Lanzamiento
@property(nonatomic) UIView *launchingView;

// Paneles
@property(nonatomic) ECSheet *sheet;
@property(nonatomic) ECSheetKind sheetKind;
@property(nonatomic) NSInteger profileTab;
@property(nonatomic) BOOL showLog;
@property(nonatomic) UITextView *logView;

// Juego
@property(nonatomic) ECStage stage;
@property(nonatomic) BOOL busy;
@property(nonatomic) BOOL launchAfterDownload;
@property(nonatomic) BOOL taskFinished;
@property(nonatomic) CGFloat progress;
@property(nonatomic) NSInteger filesDone, filesTotal;
@property(nonatomic) MinecraftResourceDownloadTask *task;
@property(nonatomic) NSTimeInterval launchedAt;

// Cuenta y memoria (accesores propios)
@property(nonatomic, readonly) BaseAuthenticator *account;
@property(nonatomic, readonly) BOOL isPremium;
@property(nonatomic, readonly) NSString *username;
@property(nonatomic) int ramMb;

// Skin
@property(nonatomic) UIImage *skinTexture;
@property(nonatomic) ECSkinProfile *skinProfile;
@property(nonatomic) UIImage *pendingSkin;
@property(nonatomic) NSData *pendingPNG;
@property(nonatomic) BOOL skinBusy;
@property(nonatomic) BOOL slimSelection;
@property(nonatomic, copy) NSString *skinMessage;
@property(nonatomic, copy) NSString *skinOwner;

@end

@implementation ECLauncherViewController

#pragma mark - Ciclo de vida

- (void)viewDidLoad {
    [super viewDidLoad];
    ECRegisterFonts();
    self.view.backgroundColor = ECNight;
    self.view.tintColor = ECGold;
    if (@available(iOS 13.0, *)) {
        self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    }

    [self buildHome];
    [self buildLogin];
    [self buildLaunching];

    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(logChanged) name:ECNotificationLog object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(keyboardWillChange:) name:UIKeyboardWillChangeFrameNotification object:nil];

    ECLog(@"EclipseCobblemon %@ · Runtime Amethyst", NSBundle.mainBundle.infoDictionary[@"CFBundleShortVersionString"]);
    ECLog(@"%@ · iOS %@ · %.1f GB → nível %@", ECDeviceModel(), UIDevice.currentDevice.systemVersion, ECDeviceRAMGB(), ECTierName(ECDeviceTier()));
    ECLog(@"JIT: %@", isJITEnabled(false) ? @"ativo" : @"inativo (será pedido ao jogar)");
    ECLog(@"Diretório: %s", getenv("POJAV_GAME_DIR"));

    [self installControls];
    [self ensureProfile];
    [self applyAccountEnvironment];
    [self showLoggedIn:self.account != nil animated:NO];
    [self refreshAll];
    [self loadSkin];
    [self refreshMicrosoftSession];
    [self applyPreviewEnvironment];
}

/// Solo para las capturas automáticas del CI (simulador): EC_PREVIEW_USER y EC_PREVIEW_SHEET.
- (void)applyPreviewEnvironment {
    const char *user = getenv("EC_PREVIEW_USER");
    const char *sheet = getenv("EC_PREVIEW_SHEET");
    if (user && !self.account) {
        self.nameField.text = @(user);
        [self loginOffline];
    }
    if (!sheet) return;
    NSString *kind = @(sheet);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if ([kind isEqualToString:@"settings"] || [kind isEqualToString:@"log"]) {
            self.showLog = [kind isEqualToString:@"log"];
            [self openSettings];
        } else if ([kind isEqualToString:@"profile"] || [kind isEqualToString:@"skin"]) {
            self.profileTab = [kind isEqualToString:@"skin"] ? 1 : 0;
            [self openProfile];
        } else if ([kind isEqualToString:@"progress"]) {
            self.busy = YES;
            self.stage = ECStageFiles;
            self.filesDone = 1234;
            self.filesTotal = 3412;
            self.progress = 0.42;
            [self refreshAll];
        } else if ([kind isEqualToString:@"launching"]) {
            self.busy = YES;
            self.stage = ECStageLaunching;
            [self refreshAll];
        }
    });
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    // Al volver del juego (o si no llegó a abrirse) la pantalla de lanzamiento se cierra.
    if (self.stage == ECStageLaunching && NSDate.date.timeIntervalSince1970 - self.launchedAt > 1.5) {
        self.stage = ECStageIdle;
        self.busy = NO;
        [self refreshAll];
    }
    [self warnLowMemoryOnce];
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

- (BOOL)prefersHomeIndicatorAutoHidden {
    return NO;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad ? UIInterfaceOrientationMaskAll : UIInterfaceOrientationMaskPortrait;
}

#pragma mark - Cuenta

- (BaseAuthenticator *)account {
    return BaseAuthenticator.current;
}

- (BOOL)isPremium {
    return [self.account isKindOfClass:MicrosoftAuthenticator.class];
}

- (NSString *)username {
    NSString *name = self.account.authData[@"username"];
    return [name hasPrefix:@"Demo."] ? [name substringFromIndex:5] : name;
}

/// Igual que Amethyst: las cuentas Microsoft sin el juego usan el modo demo con su propia carpeta.
- (void)applyAccountEnvironment {
    BOOL demo = [self.account.authData[@"username"] hasPrefix:@"Demo."];
    BOOL wasDemo = getenv("DEMO_LOCK") != NULL;
    unsetenv("DEMO_LOCK");
    setenv("POJAV_GAME_DIR", [NSString stringWithFormat:@"%s/Library/Application Support/minecraft", getenv("POJAV_HOME")].UTF8String, 1);
    if (demo) {
        setenv("DEMO_LOCK", "1", 1);
        setenv("POJAV_GAME_DIR", [NSString stringWithFormat:@"%s/.demo", getenv("POJAV_HOME")].UTF8String, 1);
    }
    if (demo != wasDemo) {
        [PLProfiles updateCurrent];
        [self ensureProfile];
    }
}

- (void)refreshMicrosoftSession {
    if (!self.isPremium) return;
    [self.account refreshTokenWithCallback:^(id status, BOOL success) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!success) {
                ECLog(@"Não foi possível renovar a sessão: %@", [status description]);
            }
        });
    }];
}

- (void)didLogin {
    setPrefObject(@"internal.selected_account", self.account.authData[@"username"]);
    [self applyAccountEnvironment];
    self.skinOwner = nil;
    [self loadSkin];
    [self showLoggedIn:YES animated:YES];
    [self refreshAll];
}

- (void)loginOffline {
    NSString *name = [self.nameField.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    if (![self isValidName:name]) return;
    [self.nameField resignFirstResponder];
    [[[LocalAuthenticator alloc] initWithInput:name] loginWithCallback:^(id status, BOOL success) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!success) {
                ECLog(@"Erro ao guardar a conta offline");
                return;
            }
            ECLog(@"Sessão sem ligação: %@ (%@)", name, self.account.authData[@"profileId"]);
            self.nameField.text = @"";
            [self nameChanged];
            [self didLogin];
        });
    }];
}

- (void)loginMicrosoft {
    if (self.loggingIn) return;
    NSURL *url = [NSURL URLWithString:@"https://login.live.com/oauth20_authorize.srf?client_id=00000000402b5328&response_type=code&scope=service%3A%3Auser.auth.xboxlive.com%3A%3AMBI_SSL&redirect_url=https%3A%2F%2Flogin.live.com%2Foauth20_desktop.srf"];
    __weak ECLauncherViewController *weakSelf = self;
    self.authSession = [[ASWebAuthenticationSession alloc] initWithURL:url callbackURLScheme:@"ms-xal-00000000402b5328" completionHandler:^(NSURL *callbackURL, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf handleMicrosoftCallback:callbackURL error:error];
        });
    }];
    self.authSession.prefersEphemeralWebBrowserSession = YES;
    self.authSession.presentationContextProvider = self;
    if (![self.authSession start]) {
        [self alert:@"Erro" message:@"Não foi possível abrir o início de sessão da Microsoft."];
    }
}

- (void)handleMicrosoftCallback:(NSURL *)callbackURL error:(NSError *)error {
    if (!callbackURL) {
        if (error.code != ASWebAuthenticationSessionErrorCodeCanceledLogin) {
            ECLog(@"Login Microsoft: %@", error.localizedDescription);
            [self alert:@"Erro" message:error.localizedDescription];
        } else {
            ECLog(@"Login Microsoft: cancelado");
        }
        return;
    }
    NSMutableDictionary *query = [NSMutableDictionary new];
    for (NSURLQueryItem *item in [NSURLComponents componentsWithURL:callbackURL resolvingAgainstBaseURL:NO].queryItems) {
        if (item.value) query[item.name] = item.value;
    }
    if (!query[@"code"]) {
        if (![query[@"error"] hasPrefix:@"access_denied"]) {
            [self alert:@"Erro" message:query[@"error_description"] ?: @"Resposta inválida da Microsoft."];
        }
        return;
    }
    self.loggingIn = YES;
    [self refreshLogin];
    [[[MicrosoftAuthenticator alloc] initWithInput:query[@"code"]] loginWithCallback:^(id status, BOOL success) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (success && [status isKindOfClass:NSString.class]) {
                if ([status isEqualToString:@"DEMO"]) {
                    [self alert:@"Conta sem Minecraft" message:@"Esta conta Microsoft não tem o Minecraft: Java Edition. Vai jogar a versão de demonstração."];
                } else {
                    ECLog(@"Login Microsoft: %@", status);
                }
                return;
            }
            self.loggingIn = NO;
            [self refreshLogin];
            if (!success) {
                // La sesión a medias no se guarda: vuelve a la cuenta guardada (si la hay)
                BaseAuthenticator.current = nil;
                NSString *message = [status isKindOfClass:NSError.class] ? [status localizedDescription] : [status description];
                NSData *data = [status isKindOfClass:NSError.class] ? ((NSError *)status).userInfo[AFNetworkingOperationFailingURLResponseDataErrorKey] : nil;
                if (data) {
                    NSString *body = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                    ECLog(@"Login Microsoft (resposta): %@", body);
                }
                ECLog(@"Erro: %@", message);
                [self alert:@"Não foi possível iniciar sessão" message:message ?: @"Erro desconhecido"];
                return;
            }
            ECLog(@"Sessão Microsoft: %@", self.username);
            [self didLogin];
        });
    }];
}

- (ASPresentationAnchor)presentationAnchorForWebAuthenticationSession:(ASWebAuthenticationSession *)session {
    return self.view.window;
}

- (void)logout {
    if (self.busy) return;
    NSDictionary *data = self.account.authData;
    NSString *name = data[@"username"];
    if (name) {
        NSString *path = [NSString stringWithFormat:@"%s/accounts/%@.json", getenv("POJAV_HOME"), name];
        [NSFileManager.defaultManager removeItemAtPath:path error:nil];
    }
    if (data[@"xuid"]) {
        [MicrosoftAuthenticator clearTokenDataOfProfile:data[@"xuid"]];
    }
    BaseAuthenticator.current = nil;
    setPrefObject(@"internal.selected_account", @"");
    [self applyAccountEnvironment];
    self.skinTexture = nil;
    self.skinProfile = nil;
    self.skinOwner = nil;
    [self clearPendingSkin];
    ECLog(@"Sessão encerrada");
    [self.sheet dismiss];
    [self showLoggedIn:NO animated:YES];
    [self refreshAll];
}

#pragma mark - Perfil de lanzamiento y controles

/// Perfil fijo de Amethyst con la versión del servidor; JavaLauncher lo lee al lanzar.
- (void)ensureProfile {
    PLProfiles *profiles = PLProfiles.current;
    NSMutableDictionary *all = [profiles.profiles mutableCopy] ?: [NSMutableDictionary new];
    NSMutableDictionary *mine = [all[ECProfileName] mutableCopy] ?: [NSMutableDictionary new];
    BOOL changed = ![mine[@"lastVersionId"] isEqualToString:ECVersion] || ![profiles.selectedProfileName isEqualToString:ECProfileName];
    mine[@"name"] = ECProfileName;
    mine[@"lastVersionId"] = ECVersion;
    all[ECProfileName] = mine;
    profiles.profileDict[@"profiles"] = all;
    if (changed) {
        profiles.selectedProfileName = ECProfileName;
    } else {
        [profiles save];
    }
}

/// Instala el layout táctil del servidor y lo deja por defecto la primera vez.
- (void)installControls {
    NSString *src = [NSBundle.mainBundle pathForResource:@"Controles_Eclipse" ofType:@"json"];
    if (!src) return;
    NSString *dir = [@(getenv("POJAV_HOME")) stringByAppendingPathComponent:@"controlmap"];
    NSString *dst = [dir stringByAppendingPathComponent:@"Controles_Eclipse.json"];
    NSFileManager *fm = NSFileManager.defaultManager;
    [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    if (![fm fileExistsAtPath:dst]) {
        [fm copyItemAtPath:src toPath:dst error:nil];
    }
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    if (![d boolForKey:@"eclipse.controls_default"]) {
        setPrefObject(@"control.default_ctrl", @"Controles_Eclipse.json");
        [d setBool:YES forKey:@"eclipse.controls_default"];
    }
}

- (int)ramMb {
    NSInteger v = [NSUserDefaults.standardUserDefaults integerForKey:@"eclipse.ram_mb"];
    return v > 0 ? (int)MIN(v, ECMaxRAM()) : ECRecommendedRAM();
}

- (void)setRamMb:(int)ramMb {
    [NSUserDefaults.standardUserDefaults setInteger:ramMb forKey:@"eclipse.ram_mb"];
}

/// Opciones iniciales del juego según el nivel del dispositivo (solo si aún no existen).
- (void)prepareGameOptions {
    NSString *path = [@(getenv("POJAV_GAME_DIR")) stringByAppendingPathComponent:@"options.txt"];
    if ([NSFileManager.defaultManager fileExistsAtPath:path]) return;
    int rd = ECRenderDistance();
    NSString *opts = [NSString stringWithFormat:@"renderDistance:%d\nsimulationDistance:%d\nlang:pt_pt\nguiScale:2\n", rd, MAX(5, rd)];
    [opts writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
    ECLog(@"options.txt criado: distância de visão %d", rd);
}

- (void)warnLowMemoryOnce {
    if (ECDeviceTier() != ECTierNotRecommended) return;
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    if ([d boolForKey:@"eclipse.low_ram_warned"]) return;
    [d setBool:YES forKey:@"eclipse.low_ram_warned"];
    [self alert:@"Dispositivo não recomendado"
        message:[NSString stringWithFormat:@"Este iPhone tem %.0f GB de memória. O Minecraft com Cobblemon pode fechar sozinho ou ficar lento. Recomendado: iPhone 12 Pro, 13 Pro, 14 ou superior · Mínimo: iPhone XS.", ceil(ECDeviceRAMGB())]];
}

#pragma mark - Jogar

- (void)play {
    [self runLaunching:YES];
}

- (void)verifyFiles {
    [self runLaunching:NO];
}

- (void)runLaunching:(BOOL)launch {
    if (self.busy) return;
    if (!self.account) {
        [self showLoggedIn:NO animated:YES];
        return;
    }
    self.busy = YES;
    self.launchAfterDownload = launch;
    self.progress = -1;
    self.filesDone = self.filesTotal = 0;
    self.stage = ECStageVersion;
    [self refreshAll];
    UIApplication.sharedApplication.idleTimerDisabled = YES;

    [self ensureProfile];
    setPrefBool(@"java.auto_ram", NO);
    setPrefInt(@"java.allocated_memory", self.ramMb);
    ECLog(@"Memória Java: %d MB", self.ramMb);

    if (self.isPremium) {
        ECLog(@"A verificar a sessão da Microsoft…");
        [self.account refreshTokenWithCallback:^(id status, BOOL success) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (!success) {
                    [self failWith:[NSString stringWithFormat:@"Sessão da Microsoft: %@", [status isKindOfClass:NSError.class] ? [status localizedDescription] : status]];
                } else if (status == nil) {
                    [self fetchVersionList];
                }
            });
        }];
    } else {
        [self fetchVersionList];
    }
}

- (void)fetchVersionList {
    if ([MinecraftResourceUtils findVersion:ECVersion inList:remoteVersionList]) {
        [self startDownload];
        return;
    }
    ECLog(@"A obter a lista de versões…");
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    [manager GET:@"https://piston-meta.mojang.com/mc/game/version_manifest_v2.json" parameters:nil headers:nil progress:nil success:^(NSURLSessionTask *task, NSDictionary *response) {
        remoteVersionList = [NSMutableArray arrayWithArray:@[
            @{@"id": @"latest-release", @"type": @"release"},
            @{@"id": @"latest-snapshot", @"type": @"snapshot"}
        ]];
        [remoteVersionList addObjectsFromArray:response[@"versions"]];
        setPrefObject(@"internal.latest_version", response[@"latest"]);
        [self startDownload];
    } failure:^(NSURLSessionTask *operation, NSError *error) {
        ECLog(@"Sem lista de versões (%@); a usar ficheiros locais", error.localizedDescription);
        [self startDownload];
    }];
}

- (void)startDownload {
    ECLog(@"A preparar o Minecraft %@…", ECVersion);
    NSDictionary *version = (NSDictionary *)[MinecraftResourceUtils findVersion:ECVersion inList:remoteVersionList] ?: @{@"id": ECVersion, @"type": @"release"};
    self.taskFinished = NO;
    MinecraftResourceDownloadTask *task = [MinecraftResourceDownloadTask new];
    self.task = task;
    __weak ECLauncherViewController *weakSelf = self;
    task.handleError = ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf failWith:nil];
        });
    };
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        [task downloadVersion:version];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (weakSelf.task != task || task.progress.cancelled) return;
            [task.progress addObserver:weakSelf forKeyPath:@"fractionCompleted" options:NSKeyValueObservingOptionInitial context:ECProgressContext];
            objc_setAssociatedObject(task, @selector(startDownload), @YES, OBJC_ASSOCIATION_RETAIN);
        });
    });
}

- (void)stopObserving:(MinecraftResourceDownloadTask *)task {
    if ([objc_getAssociatedObject(task, @selector(startDownload)) boolValue]) {
        objc_setAssociatedObject(task, @selector(startDownload), nil, OBJC_ASSOCIATION_RETAIN);
        [task.progress removeObserver:self forKeyPath:@"fractionCompleted" context:ECProgressContext];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context != ECProgressContext) {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
        return;
    }
    MinecraftResourceDownloadTask *task = self.task;
    NSProgress *progress = object;
    double fraction = progress.fractionCompleted;
    BOOL finished = progress.finished && !progress.cancelled;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.task != task || self.taskFinished) return;
        NSInteger total = task.fileList.count;
        NSInteger done = 0;
        for (NSProgress *p in [task.progressList copy]) {
            if (p.finished || p.fractionCompleted >= 1) done++;
        }
        // Sin metadatos aún no ha terminado: el JSON de la versión todavía se está procesando.
        BOOL complete = finished && task.metadata != nil;
        if (total > 0) {
            self.stage = ECStageFiles;
            self.filesTotal = total;
            self.filesDone = MIN(done, total);
            self.progress = fraction;
        }
        if (complete) {
            self.taskFinished = YES;
            [self stopObserving:task];
            [self downloadFinished:task];
        } else {
            [self refreshStatus];
        }
    });
}

- (void)downloadFinished:(MinecraftResourceDownloadTask *)task {
    NSDictionary *metadata = task.metadata;
    self.task = nil;
    if (self.filesTotal > 0) {
        ECLog(@"%ld ficheiros transferidos", (long)self.filesTotal);
    }
    if (!metadata) {
        [self failWith:@"Não foi possível ler a versão do Minecraft."];
        return;
    }
    if (!self.launchAfterDownload) {
        ECLog(@"Ficheiros verificados");
        [self finishBusy];
        return;
    }

    // Java: os runtimes vêm dentro da app; só se verifica que existe o necessário.
    self.stage = ECStageJava;
    self.progress = 0;
    [self refreshAll];
    int javaVersion = [metadata[@"javaVersion"][@"majorVersion"] intValue] ?: 8;
    NSString *javaHome = getSelectedJavaHome(javaVersion <= 8 ? @"1_16_5_older" : @"1_17_newer", javaVersion);
    if (!javaHome) {
        [self failWith:[NSString stringWithFormat:@"O Java %d não está instalado nesta app.", javaVersion]];
        return;
    }
    ECLog(@"Java %d: %@", javaVersion, javaHome.lastPathComponent);
    [self animateJavaThen:^{
        [self prepareGameOptions];
        [self launchWithMetadata:metadata];
    }];
}

- (void)animateJavaThen:(void (^)(void))next {
    __block int step = 0;
    [NSTimer scheduledTimerWithTimeInterval:0.03 repeats:YES block:^(NSTimer *timer) {
        step++;
        self.progress = MIN(1, step / 20.0);
        [self refreshStatus];
        if (step >= 20) {
            [timer invalidate];
            next();
        }
    }];
}

- (void)launchWithMetadata:(NSDictionary *)metadata {
    ECLog(@"A iniciar o Minecraft %@…", ECVersion);
    self.stage = ECStageLaunching;
    self.launchedAt = NSDate.date.timeIntervalSince1970;
    [self refreshAll];
    [self invokeAfterJITEnabled:^{
        ECLog(@"JIT ativo; a abrir o jogo");
        UIKit_launchMinecraftSurfaceVC(self.view.window, metadata);
    }];
}

- (void)failWith:(NSString *)message {
    if (self.task) {
        [self stopObserving:self.task];
        self.task = nil;
    }
    if (message) {
        ECLog(@"Erro: %@", message);
        [self alert:@"Erro" message:message];
    }
    [self finishBusy];
}

- (void)finishBusy {
    self.busy = NO;
    self.stage = ECStageIdle;
    self.progress = -1;
    UIApplication.sharedApplication.idleTimerDisabled = NO;
    [self refreshAll];
}

/// Copiado de LauncherNavigationController: espera a que el JIT esté activo antes de lanzar.
- (void)invokeAfterJITEnabled:(void (^)(void))handler {
    BOOL hasTrollStoreJIT = getEntitlementValue(@"jb.pmap_cs.custom_trust");
    if (isJITEnabled(false)) {
        handler();
        return;
    } else if (hasTrollStoreJIT) {
        NSURL *jitURL = [NSURL URLWithString:[NSString stringWithFormat:@"apple-magnifier://enable-jit?bundle-id=%@", NSBundle.mainBundle.bundleIdentifier]];
        [UIApplication.sharedApplication openURL:jitURL options:@{} completionHandler:nil];
    } else if (getPrefBool(@"debug.debug_skip_wait_jit")) {
        ECLog(@"Aviso: a espera do JIT foi ignorada (depuração)");
        handler();
        return;
    } else if (@available(iOS 17.4, *)) {
        NSString *script = @"";
        if (DeviceHasJITFlags(JIT_FLAG_FORCE_MIRRORED | JIT_FLAG_HAS_TXM)) {
            NSData *data = [NSData dataWithContentsOfFile:[NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:@"UniversalJIT26.js"]];
            script = [@"&script-data=" stringByAppendingString:[data base64EncodedStringWithOptions:0]];
        }
        NSString *url = [NSString stringWithFormat:@"stikjit://enable-jit?bundle-id=%@&pid=%d%@", NSBundle.mainBundle.bundleIdentifier, getpid(), script];
        [UIApplication.sharedApplication openURL:[NSURL URLWithString:url] options:@{} completionHandler:nil];
    } else {
        NSString *url = [NSString stringWithFormat:@"sidestore://sidejit-enable?pid=%d", getpid()];
        [UIApplication.sharedApplication openURL:[NSURL URLWithString:url] options:@{} completionHandler:nil];
    }

    ECLog(@"À espera do JIT…");
    NSString *message = hasTrollStoreJIT
        ? @"Se continuar a ver esta mensagem, ative o esquema de URL no TrollStore."
        : @"O Minecraft precisa do JIT para funcionar. Ative-o com o StikDebug, SideStore ou AltStore e volte a esta app.";
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"À espera do JIT" message:message preferredStyle:UIAlertControllerStyleAlert];
    __block BOOL cancelled = NO;
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancelar" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
        cancelled = YES;
        ECLog(@"Lançamento cancelado");
        [self finishBusy];
    }]];
    [self presentViewController:alert animated:YES completion:nil];

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        while (!isJITEnabled(false) && !cancelled) {
            usleep(1000 * 200);
        }
        if (cancelled) return;
        dispatch_async(dispatch_get_main_queue(), ^{
            [alert dismissViewControllerAnimated:YES completion:handler];
        });
    });
}

#pragma mark - Apagar dados

- (unsigned long long)gameDataSize {
    NSString *dir = [@(getenv("POJAV_GAME_DIR")) stringByResolvingSymlinksInPath];
    unsigned long long total = 0;
    NSDirectoryEnumerator *e = [NSFileManager.defaultManager enumeratorAtURL:[NSURL fileURLWithPath:dir]
        includingPropertiesForKeys:@[NSURLFileSizeKey, NSURLIsRegularFileKey] options:0 errorHandler:nil];
    for (NSURL *url in e) {
        NSNumber *isFile, *size;
        [url getResourceValue:&isFile forKey:NSURLIsRegularFileKey error:nil];
        if (!isFile.boolValue) continue;
        [url getResourceValue:&size forKey:NSURLFileSizeKey error:nil];
        total += size.unsignedLongLongValue;
    }
    return total;
}

- (void)confirmWipe {
    if (self.busy) return;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        unsigned long long size = [self gameDataSize];
        dispatch_async(dispatch_get_main_queue(), ^{
            NSString *msg = [NSString stringWithFormat:@"Serão apagadas versões, bibliotecas, recursos, mundos, mods e definições do jogo (%.1f MB). A sua conta e o Java mantêm-se instalados. Esta ação não pode ser anulada.", size / 1048576.0];
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Apagar dados do Minecraft?" message:msg preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"Cancelar" style:UIAlertActionStyleCancel handler:nil]];
            [alert addAction:[UIAlertAction actionWithTitle:@"Apagar tudo" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
                [self wipeGameData];
            }]];
            [self presentViewController:alert animated:YES completion:nil];
        });
    });
}

- (void)wipeGameData {
    ECLog(@"A apagar os dados do Minecraft…");
    self.busy = YES;
    [self refreshAll];
    NSString *dir = [@(getenv("POJAV_GAME_DIR")) stringByResolvingSymlinksInPath];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSFileManager *fm = NSFileManager.defaultManager;
        for (NSString *name in [fm contentsOfDirectoryAtPath:dir error:nil]) {
            [fm removeItemAtPath:[dir stringByAppendingPathComponent:name] error:nil];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [PLProfiles updateCurrent];
            [self ensureProfile];
            ECLog(@"Dados do Minecraft apagados");
            [self finishBusy];
        });
    });
}

#pragma mark - Skin

- (void)freshTokenThen:(void (^)(NSString *token))next {
    if (!self.isPremium) {
        next(nil);
        return;
    }
    NSString *xuid = self.account.authData[@"xuid"];
    [self.account refreshTokenWithCallback:^(id status, BOOL success) {
        if (status != nil && success) return; // pasos intermedios
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!success) {
                [self skinDone:@"Sessão expirada: inicie sessão novamente"];
                return;
            }
            next([MicrosoftAuthenticator tokenDataOfProfile:xuid][@"accessToken"]);
        });
    }];
}

- (void)loadSkin {
    if (!self.account) return;
    NSString *owner = self.account.authData[@"username"];
    if ([self.skinOwner isEqualToString:owner] && self.skinTexture) return;
    self.skinOwner = owner;
    self.skinBusy = YES;
    if (self.isPremium) {
        [self freshTokenThen:^(NSString *token) {
            [ECSkinAPI profileWithToken:token completion:^(ECSkinProfile *profile, NSString *error) {
                if (error) {
                    ECLog(@"Skin: %@", error);
                    [self loadFallbackSkin];
                    return;
                }
                [self applyProfile:profile message:nil];
            }];
        }];
    } else {
        [self loadFallbackSkin];
    }
}

- (void)loadFallbackSkin {
    NSString *key = self.isPremium ? [self.account.authData[@"profileId"] stringByReplacingOccurrencesOfString:@"-" withString:@""] : self.username;
    [ECSkinAPI downloadImage:[NSString stringWithFormat:@"https://mc-heads.net/skin/%@", key] completion:^(UIImage *image) {
        self.skinTexture = image;
        [self skinDone:nil];
    }];
}

- (void)applyProfile:(ECSkinProfile *)profile message:(NSString *)message {
    self.skinProfile = profile;
    self.slimSelection = profile.slim;
    dispatch_group_t group = dispatch_group_create();
    __block UIImage *texture = nil;
    if (profile.skinUrl) {
        dispatch_group_enter(group);
        [ECSkinAPI downloadImage:profile.skinUrl completion:^(UIImage *image) {
            texture = image;
            dispatch_group_leave(group);
        }];
    }
    for (ECCape *cape in profile.capes) {
        dispatch_group_enter(group);
        [ECSkinAPI downloadImage:cape.url completion:^(UIImage *image) {
            cape.texture = image;
            dispatch_group_leave(group);
        }];
    }
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        if (texture) {
            self.skinTexture = texture;
            [self skinDone:message];
        } else {
            [self loadFallbackSkin];
        }
    });
}

- (void)skinDone:(NSString *)message {
    self.skinBusy = NO;
    if (message) self.skinMessage = message;
    [self refreshAll];
}

- (void)skinTask:(void (^)(NSString *token, ECSkinCallback done))block success:(NSString *)success log:(NSString *)log {
    if (self.skinBusy) return;
    self.skinBusy = YES;
    self.skinMessage = nil;
    [self refreshAll];
    [self freshTokenThen:^(NSString *token) {
        block(token, ^(ECSkinProfile *profile, NSString *error) {
            if (error) {
                ECLog(@"Skin: %@", error);
                [self skinDone:error];
                return;
            }
            if (log) ECLog(@"%@", log);
            [self clearPendingSkin];
            [self applyProfile:profile message:success];
        });
    }];
}

- (void)applySkin {
    BOOL slim = self.slimSelection;
    NSData *png = self.pendingPNG;
    NSString *url = self.skinProfile.skinUrl;
    if (!png && !url) return;
    [self skinTask:^(NSString *token, ECSkinCallback done) {
        if (png) [ECSkinAPI uploadPNG:png slim:slim token:token completion:done];
        else [ECSkinAPI changeVariantForURL:url slim:slim token:token completion:done];
    } success:@"Skin atualizada" log:[NSString stringWithFormat:@"Skin atualizada (%@)", slim ? @"fino" : @"clássico"]];
}

- (void)resetSkin {
    [self skinTask:^(NSString *token, ECSkinCallback done) {
        [ECSkinAPI resetWithToken:token completion:done];
    } success:@"Skin reposta" log:@"Skin reposta para a predefinida"];
}

- (void)setCape:(NSString *)capeId {
    [self skinTask:^(NSString *token, ECSkinCallback done) {
        [ECSkinAPI setCape:capeId token:token completion:done];
    } success:nil log:capeId ? @"Capa alterada" : @"Capa removida"];
}

- (void)clearPendingSkin {
    self.pendingSkin = nil;
    self.pendingPNG = nil;
}

- (void)pickSkin {
    if (@available(iOS 14.0, *)) {
        PHPickerConfiguration *cfg = [PHPickerConfiguration new];
        cfg.filter = PHPickerFilter.imagesFilter;
        cfg.selectionLimit = 1;
        PHPickerViewController *picker = [[PHPickerViewController alloc] initWithConfiguration:cfg];
        picker.delegate = self;
        [self presentViewController:picker animated:YES completion:nil];
    }
}

- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results API_AVAILABLE(ios(14)) {
    [picker dismissViewControllerAnimated:YES completion:nil];
    NSItemProvider *provider = results.firstObject.itemProvider;
    if (!provider) return;
    NSString *type = [provider hasItemConformingToTypeIdentifier:@"public.png"] ? @"public.png" : @"public.image";
    [provider loadDataRepresentationForTypeIdentifier:type completionHandler:^(NSData *data, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self usePickedSkinData:data];
        });
    }];
}

- (void)usePickedSkinData:(NSData *)data {
    UIImage *image = data ? [UIImage imageWithData:data scale:1] : nil;
    CGImageRef cg = image.CGImage;
    size_t w = cg ? CGImageGetWidth(cg) : 0, h = cg ? CGImageGetHeight(cg) : 0;
    if (!image) {
        self.skinMessage = @"Não foi possível ler a imagem";
    } else if (w != 64 || (h != 64 && h != 32)) {
        self.skinMessage = [NSString stringWithFormat:@"A skin tem de ser um PNG de 64×64 (esta tem %zu×%zu)", w, h];
    } else {
        const unsigned char *bytes = data.bytes;
        BOOL isPNG = data.length > 8 && bytes[0] == 0x89 && bytes[1] == 'P';
        self.pendingPNG = isPNG ? data : UIImagePNGRepresentation(image);
        self.pendingSkin = image;
        self.skinMessage = nil;
    }
    [self refreshAll];
}

#pragma mark - Construcción: acceso

- (void)buildLogin {
    UIView *v = [UIView new];
    v.backgroundColor = ECNight;
    v.frame = self.view.bounds;
    v.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:v];
    self.loginView = v;

    UIImageView *bg = [[UIImageView alloc] initWithImage:ECBackgroundImage()];
    bg.contentMode = UIViewContentModeScaleAspectFill;
    bg.clipsToBounds = YES;
    bg.transform = CGAffineTransformMakeScale(1.08, 1.08);
    bg.frame = v.bounds;
    bg.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [v addSubview:bg];

    UIView *shade = [UIView new];
    shade.frame = v.bounds;
    shade.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    CAGradientLayer *g = [CAGradientLayer layer];
    g.colors = @[(id)[ECNight colorWithAlphaComponent:.55].CGColor, (id)[ECNight colorWithAlphaComponent:.1].CGColor,
                 (id)[ECNight colorWithAlphaComponent:.35].CGColor, (id)ECNight.CGColor];
    g.locations = @[@0, @.25, @.5, @.7];
    g.frame = CGRectMake(0, 0, 4000, 4000);
    g.name = @"shade";
    [shade.layer addSublayer:g];
    [v addSubview:shade];

    ECMoonView *moon = [ECMoonView new];
    moon.cutColor = EC_HEX(0x0C0C12, 1);
    UILabel *brand = [UILabel new];
    brand.attributedText = ECTracked(@"ECLIPSE COBBLEMON", ECFont(20, 600), ECGold, .18);
    brand.adjustsFontSizeToFitWidth = YES;
    brand.textAlignment = NSTextAlignmentCenter;
    UILabel *sub = ECLabel([NSString stringWithFormat:@"Minecraft %@ · Cobblemon", ECVersion], 13, 400, [ECIvory colorWithAlphaComponent:.7]);
    UIStackView *top = [[UIStackView alloc] initWithArrangedSubviews:@[moon, ECSpacer(16), brand, ECSpacer(6), sub]];
    top.axis = UILayoutConstraintAxisVertical;
    top.alignment = UIStackViewAlignmentCenter;
    top.translatesAutoresizingMaskIntoConstraints = NO;
    [v addSubview:top];

    // Panel fijo de acceso
    UIView *panel = [UIView new];
    panel.backgroundColor = ECSheetBg;
    panel.layer.cornerRadius = 28;
    panel.layer.cornerCurve = kCACornerCurveContinuous;
    panel.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
    panel.layer.borderWidth = 1;
    panel.layer.borderColor = ECHair.CGColor;
    panel.translatesAutoresizingMaskIntoConstraints = NO;
    [v addSubview:panel];
    self.loginPanel = panel;

    UILabel *title = ECLabel(@"Iniciar sessão", 22, 600, ECIvory);
    UILabel *desc = ECLabel(@"Use a sua conta do Minecraft: Java Edition ou jogue sem ligação.", 13.5, 400, ECMuted);
    desc.numberOfLines = 0;

    __weak ECLauncherViewController *weakSelf = self;
    self.msButton = [ECButton buttonWithStyle:ECButtonStyleGold title:@"Continuar com a Microsoft" symbol:@"lock.fill" action:^{
        [weakSelf loginMicrosoft];
    }];

    UIView *lineL = ECDivider(), *lineR = ECDivider();
    UILabel *orLabel = ECLabel(@"ou sem ligação", 12, 400, ECDim);
    [orLabel setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    UIStackView *orRow = [[UIStackView alloc] initWithArrangedSubviews:@[lineL, orLabel, lineR]];
    orRow.spacing = 12;
    orRow.alignment = UIStackViewAlignmentCenter;
    [lineL.widthAnchor constraintEqualToAnchor:lineR.widthAnchor].active = YES;

    UITextField *field = [UITextField new];
    field.attributedPlaceholder = [[NSAttributedString alloc] initWithString:@"Nome do jogador" attributes:@{NSForegroundColorAttributeName: ECDim, NSFontAttributeName: ECFont(16, 400)}];
    field.font = ECFont(16, 400);
    field.textColor = ECIvory;
    field.tintColor = ECGold;
    field.autocorrectionType = UITextAutocorrectionTypeNo;
    field.autocapitalizationType = UITextAutocapitalizationTypeNone;
    field.spellCheckingType = UITextSpellCheckingTypeNo;
    field.returnKeyType = UIReturnKeyDone;
    field.keyboardAppearance = UIKeyboardAppearanceDark;
    field.delegate = self;
    field.layer.cornerRadius = 16;
    field.layer.borderWidth = 1;
    field.layer.borderColor = ECHair.CGColor;
    field.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 16, 10)];
    field.leftViewMode = UITextFieldViewModeAlways;
    [field addTarget:self action:@selector(nameChanged) forControlEvents:UIControlEventEditingChanged];
    [field.heightAnchor constraintEqualToConstant:56].active = YES;
    self.nameField = field;

    UIButton *go = [UIButton buttonWithType:UIButtonTypeCustom];
    [go setImage:ECSymbol(@"arrow.right", 18, UIFontWeightSemibold) forState:UIControlStateNormal];
    go.layer.cornerRadius = 16;
    go.layer.borderWidth = 1;
    go.accessibilityLabel = @"Entrar sem ligação";
    [go addTarget:self action:@selector(loginOffline) forControlEvents:UIControlEventTouchUpInside];
    [go.widthAnchor constraintEqualToConstant:56].active = YES;
    [go.heightAnchor constraintEqualToConstant:56].active = YES;
    self.goButton = go;

    UIStackView *fieldRow = [[UIStackView alloc] initWithArrangedSubviews:@[field, go]];
    fieldRow.spacing = 10;
    fieldRow.alignment = UIStackViewAlignmentCenter;

    UILabel *hint = ECLabel(@"", 12, 400, ECDim);
    hint.numberOfLines = 0;
    self.nameHint = hint;

    UIStackView *form = [[UIStackView alloc] initWithArrangedSubviews:@[title, ECSpacer(6), desc, ECSpacer(20), self.msButton, ECSpacer(18), orRow, ECSpacer(18), fieldRow, ECSpacer(10), hint]];
    form.axis = UILayoutConstraintAxisVertical;
    form.translatesAutoresizingMaskIntoConstraints = NO;
    [panel addSubview:form];

    self.loginPanelBottom = [panel.bottomAnchor constraintEqualToAnchor:v.bottomAnchor constant:1];
    [NSLayoutConstraint activateConstraints:@[
        [moon.widthAnchor constraintEqualToConstant:56],
        [moon.heightAnchor constraintEqualToConstant:56],
        [top.topAnchor constraintEqualToAnchor:v.safeAreaLayoutGuide.topAnchor constant:56],
        [top.centerXAnchor constraintEqualToAnchor:v.centerXAnchor],
        [top.leadingAnchor constraintGreaterThanOrEqualToAnchor:v.leadingAnchor constant:20],

        [panel.leadingAnchor constraintEqualToAnchor:v.leadingAnchor],
        [panel.trailingAnchor constraintEqualToAnchor:v.trailingAnchor],
        self.loginPanelBottom,
        [form.topAnchor constraintEqualToAnchor:panel.topAnchor constant:26],
        [form.leadingAnchor constraintEqualToAnchor:panel.safeAreaLayoutGuide.leadingAnchor constant:24],
        [form.trailingAnchor constraintEqualToAnchor:panel.safeAreaLayoutGuide.trailingAnchor constant:-24],
        [form.bottomAnchor constraintEqualToAnchor:panel.safeAreaLayoutGuide.bottomAnchor constant:-20],
    ]];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:field action:@selector(resignFirstResponder)];
    tap.cancelsTouchesInView = NO;
    [v addGestureRecognizer:tap];
    [self nameChanged];
}

- (BOOL)isValidName:(NSString *)name {
    static NSRegularExpression *re;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        re = [NSRegularExpression regularExpressionWithPattern:@"^[A-Za-z0-9_]{3,16}$" options:0 error:nil];
    });
    return name && [re numberOfMatchesInString:name options:0 range:NSMakeRange(0, name.length)] == 1;
}

- (void)nameChanged {
    NSString *name = self.nameField.text ?: @"";
    if (name.length > 16) {
        name = [name substringToIndex:16];
        self.nameField.text = name;
    }
    BOOL valid = [self isValidName:name];
    BOOL bad = name.length > 0 && !valid;
    self.goButton.enabled = valid;
    self.goButton.tintColor = valid ? ECGold : ECDim;
    self.goButton.layer.borderColor = [ECGold colorWithAlphaComponent:valid ? .5 : .15].CGColor;
    self.nameField.layer.borderColor = (self.nameField.isFirstResponder ? [ECGold colorWithAlphaComponent:.6] : ECHair).CGColor;
    self.nameHint.text = bad ? @"3–16 caracteres: letras, números ou _" : @"Sem ligação: um jogador e servidores não premium.";
    self.nameHint.textColor = bad ? ECGoldLo : ECDim;
}

- (void)textFieldDidBeginEditing:(UITextField *)textField { [self nameChanged]; }
- (void)textFieldDidEndEditing:(UITextField *)textField { [self nameChanged]; }

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if ([self isValidName:textField.text]) [self loginOffline];
    else [textField resignFirstResponder];
    return YES;
}

- (void)keyboardWillChange:(NSNotification *)n {
    CGRect end = [n.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect local = [self.view convertRect:end fromView:nil];
    CGFloat overlap = MAX(0, CGRectGetMaxY(self.view.bounds) - CGRectGetMinY(local));
    if (overlap > 0) overlap -= self.view.safeAreaInsets.bottom - 8;
    self.loginPanelBottom.constant = 1 - MAX(0, overlap);
    double duration = [n.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    [UIView animateWithDuration:duration animations:^{
        [self.loginView layoutIfNeeded];
    }];
}

- (void)refreshLogin {
    self.msButton.title = self.loggingIn ? @"A verificar a conta…" : @"Continuar com a Microsoft";
    self.msButton.loading = self.loggingIn;
}

- (void)showLoggedIn:(BOOL)loggedIn animated:(BOOL)animated {
    UIView *show = loggedIn ? self.homeView : self.loginView;
    UIView *hide = loggedIn ? self.loginView : self.homeView;
    if (!loggedIn) [self.view bringSubviewToFront:self.loginView];
    if (animated) {
        show.hidden = NO;
        show.alpha = 0;
        [UIView animateWithDuration:0.45 animations:^{
            show.alpha = 1;
            hide.alpha = 0;
        } completion:^(BOOL finished) {
            hide.hidden = YES;
            hide.alpha = 1;
        }];
    } else {
        show.hidden = NO;
        show.alpha = 1;
        hide.hidden = YES;
    }
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    for (CALayer *l in self.loginView.subviews[1].layer.sublayers) {
        if ([l.name isEqualToString:@"shade"]) l.frame = self.loginView.bounds;
    }
    for (CALayer *l in self.heroImage.superview.layer.sublayers) {
        if ([l.name isEqualToString:@"heroShade"]) l.frame = self.heroImage.superview.bounds;
    }
}

#pragma mark - Construcción: inicio

- (void)buildHome {
    UIView *v = [UIView new];
    v.backgroundColor = ECNight;
    v.frame = self.view.bounds;
    v.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:v];
    self.homeView = v;
    __weak ECLauncherViewController *weakSelf = self;

    // Cabecera
    ECMoonView *moon = [ECMoonView new];
    UILabel *brand = [UILabel new];
    brand.attributedText = ECTracked(@"ECLIPSE COBBLEMON", ECFont(16, 600), ECGold, .16);
    brand.adjustsFontSizeToFitWidth = YES;
    brand.minimumScaleFactor = 0.7;
    UIButton *avatar = [UIButton buttonWithType:UIButtonTypeCustom];
    avatar.layer.cornerRadius = 10;
    avatar.layer.cornerCurve = kCACornerCurveContinuous;
    avatar.layer.borderWidth = 1;
    avatar.layer.borderColor = [ECGold colorWithAlphaComponent:.45].CGColor;
    avatar.clipsToBounds = YES;
    avatar.imageView.contentMode = UIViewContentModeScaleAspectFill;
    avatar.titleLabel.font = ECFont(15, 700);
    [avatar setTitleColor:ECGold forState:UIControlStateNormal];
    avatar.accessibilityLabel = @"Perfil";
    [avatar addTarget:self action:@selector(openProfile) forControlEvents:UIControlEventTouchUpInside];
    self.avatarButton = avatar;
    UIView *flex = [UIView new];
    [flex setContentHuggingPriority:1 forAxis:UILayoutConstraintAxisHorizontal];
    UIStackView *header = [[UIStackView alloc] initWithArrangedSubviews:@[moon, brand, flex, avatar]];
    header.spacing = 12;
    header.alignment = UIStackViewAlignmentCenter;
    header.translatesAutoresizingMaskIntoConstraints = NO;
    [v addSubview:header];

    // Tarjeta del castillo
    UIView *card = [UIView new];
    card.layer.cornerRadius = 26;
    card.layer.cornerCurve = kCACornerCurveContinuous;
    card.layer.borderWidth = 1;
    card.layer.borderColor = [ECGold colorWithAlphaComponent:.32].CGColor;
    card.clipsToBounds = YES;
    card.translatesAutoresizingMaskIntoConstraints = NO;
    [v addSubview:card];

    UIImageView *hero = [[UIImageView alloc] initWithImage:ECBackgroundImage()];
    hero.contentMode = UIViewContentModeScaleAspectFill;
    hero.transform = CGAffineTransformMakeScale(1.08, 1.08);
    hero.translatesAutoresizingMaskIntoConstraints = NO;
    // La imagen no impone su tamaño: la tarjeta ocupa el espacio que dejan los demás
    for (NSNumber *axis in @[@(UILayoutConstraintAxisHorizontal), @(UILayoutConstraintAxisVertical)]) {
        [hero setContentCompressionResistancePriority:1 forAxis:axis.integerValue];
        [hero setContentHuggingPriority:1 forAxis:axis.integerValue];
    }
    [card addSubview:hero];
    self.heroImage = hero;
    CAGradientLayer *shade = [CAGradientLayer layer];
    shade.name = @"heroShade";
    shade.colors = @[(id)[ECNight colorWithAlphaComponent:.25].CGColor, (id)UIColor.clearColor.CGColor,
                     (id)UIColor.clearColor.CGColor, (id)[ECNight colorWithAlphaComponent:.8].CGColor];
    shade.locations = @[@0, @.3, @.55, @1];
    [card.layer addSublayer:shade];
    UIView *veil = [UIView new];
    veil.backgroundColor = ECNight;
    veil.alpha = 0;
    veil.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:veil];
    self.heroVeil = veil;

    // Chip del servidor
    UIView *chip = [UIView new];
    chip.backgroundColor = [ECNight colorWithAlphaComponent:.62];
    chip.layer.cornerRadius = 14;
    chip.layer.borderWidth = 1;
    chip.layer.borderColor = ECHair.CGColor;
    chip.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:chip];
    UIView *dot = [UIView new];
    dot.layer.cornerRadius = 4;
    dot.backgroundColor = ECServerAddress ? ECOnline : ECDim;
    self.chipDot = dot;
    UILabel *chipTitle = ECLabel(ECServerName, 13, 700, ECIvory);
    UILabel *chipSub = ECLabel(ECServerAddress ?: @"Servidor oficial · em breve", 11.5, 400, ECMuted);
    UIStackView *chipText = [[UIStackView alloc] initWithArrangedSubviews:@[chipTitle, chipSub]];
    chipText.axis = UILayoutConstraintAxisVertical;
    UIStackView *chipRow = [[UIStackView alloc] initWithArrangedSubviews:@[dot, chipText]];
    chipRow.spacing = 10;
    chipRow.alignment = UIStackViewAlignmentCenter;
    chipRow.translatesAutoresizingMaskIntoConstraints = NO;
    [chip addSubview:chipRow];

    // Jugar
    ECPlayControl *play = [ECPlayControl new];
    play.progress = -1;
    play.translatesAutoresizingMaskIntoConstraints = NO;
    [play addTarget:self action:@selector(play) forControlEvents:UIControlEventTouchUpInside];
    [v addSubview:play];
    self.playControl = play;

    // Estado
    self.statusTitle = ECLabel(@"", 15, 600, ECIvory);
    self.statusSub = ECLabel(@"", 12.5, 400, ECMuted);
    self.statusTitle.textAlignment = self.statusSub.textAlignment = NSTextAlignmentCenter;
    self.statusTitle.text = self.statusSub.text = @" ";
    for (UILabel *l in @[self.statusTitle, self.statusSub]) {
        [l setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
    }
    self.stars = [ECStarStrip new];
    self.stepsLabel = [UILabel new];
    self.stepsLabel.textAlignment = NSTextAlignmentCenter;
    UIStackView *status = [[UIStackView alloc] initWithArrangedSubviews:@[self.statusTitle, ECSpacer(3), self.statusSub, ECSpacer(10), self.stars, self.stepsLabel]];
    status.axis = UILayoutConstraintAxisVertical;
    status.alignment = UIStackViewAlignmentCenter;
    status.translatesAutoresizingMaskIntoConstraints = NO;
    [v addSubview:status];

    // Barra inferior
    UIView *nav = [UIView new];
    nav.backgroundColor = ECSurface;
    nav.layer.cornerRadius = 18;
    nav.layer.cornerCurve = kCACornerCurveContinuous;
    nav.layer.borderWidth = 1;
    nav.layer.borderColor = ECHair.CGColor;
    nav.clipsToBounds = YES;
    nav.translatesAutoresizingMaskIntoConstraints = NO;
    [v addSubview:nav];
    UIButton *(^navItem)(NSString *, NSString *, SEL) = ^UIButton *(NSString *title, NSString *symbol, SEL sel) {
        UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
        [b setImage:ECSymbol(symbol, 16, UIFontWeightSemibold) forState:UIControlStateNormal];
        [b setAttributedTitle:[[NSAttributedString alloc] initWithString:title attributes:@{NSFontAttributeName: ECFont(14, 600), NSForegroundColorAttributeName: ECIvory}] forState:UIControlStateNormal];
        b.tintColor = ECGold;
        b.imageEdgeInsets = UIEdgeInsetsMake(0, -4, 0, 4);
        b.titleEdgeInsets = UIEdgeInsetsMake(0, 4, 0, -4);
        [b addTarget:weakSelf action:sel forControlEvents:UIControlEventTouchUpInside];
        return b;
    };
    UIView *sep = [UIView new];
    sep.backgroundColor = ECHair;
    UIButton *navProfile = navItem(@"Perfil", @"person.fill", @selector(openProfile));
    UIButton *navSettings = navItem(@"Definições", @"gearshape.fill", @selector(openSettings));
    for (UIView *x in @[navProfile, sep, navSettings]) {
        x.translatesAutoresizingMaskIntoConstraints = NO;
        [nav addSubview:x];
    }

    NSLayoutConstraint *starsWidth = [self.stars.widthAnchor constraintEqualToConstant:300];
    starsWidth.priority = UILayoutPriorityDefaultHigh;
    starsWidth.active = YES;

    UILayoutGuide *safe = v.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [header.topAnchor constraintEqualToAnchor:safe.topAnchor constant:10],
        [header.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:20],
        [header.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-20],
        [header.heightAnchor constraintEqualToConstant:44],
        [moon.widthAnchor constraintEqualToConstant:30],
        [moon.heightAnchor constraintEqualToConstant:30],
        [avatar.widthAnchor constraintEqualToConstant:40],
        [avatar.heightAnchor constraintEqualToConstant:40],

        [card.topAnchor constraintEqualToAnchor:header.bottomAnchor constant:14],
        [card.leadingAnchor constraintEqualToAnchor:header.leadingAnchor],
        [card.trailingAnchor constraintEqualToAnchor:header.trailingAnchor],
        [hero.topAnchor constraintEqualToAnchor:card.topAnchor],
        [hero.bottomAnchor constraintEqualToAnchor:card.bottomAnchor],
        [hero.leadingAnchor constraintEqualToAnchor:card.leadingAnchor],
        [hero.trailingAnchor constraintEqualToAnchor:card.trailingAnchor],
        [veil.topAnchor constraintEqualToAnchor:card.topAnchor],
        [veil.bottomAnchor constraintEqualToAnchor:card.bottomAnchor],
        [veil.leadingAnchor constraintEqualToAnchor:card.leadingAnchor],
        [veil.trailingAnchor constraintEqualToAnchor:card.trailingAnchor],

        [chip.topAnchor constraintEqualToAnchor:card.topAnchor constant:14],
        [chip.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:14],
        [chip.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-14],
        [chipRow.topAnchor constraintEqualToAnchor:chip.topAnchor constant:10],
        [chipRow.bottomAnchor constraintEqualToAnchor:chip.bottomAnchor constant:-10],
        [chipRow.leadingAnchor constraintEqualToAnchor:chip.leadingAnchor constant:14],
        [chipRow.trailingAnchor constraintEqualToAnchor:chip.trailingAnchor constant:-14],
        [dot.widthAnchor constraintEqualToConstant:8],
        [dot.heightAnchor constraintEqualToConstant:8],

        // El botón de jugar va montado sobre el borde inferior de la tarjeta
        [play.widthAnchor constraintEqualToConstant:112],
        [play.heightAnchor constraintEqualToConstant:112],
        [play.centerXAnchor constraintEqualToAnchor:card.centerXAnchor],
        [play.centerYAnchor constraintEqualToAnchor:card.bottomAnchor],

        [status.topAnchor constraintEqualToAnchor:play.bottomAnchor constant:16],
        [status.leadingAnchor constraintEqualToAnchor:header.leadingAnchor],
        [status.trailingAnchor constraintEqualToAnchor:header.trailingAnchor],
        [self.stars.widthAnchor constraintLessThanOrEqualToAnchor:status.widthAnchor],
        [self.stars.heightAnchor constraintEqualToConstant:40],
        [self.stepsLabel.heightAnchor constraintEqualToConstant:22],

        [nav.topAnchor constraintEqualToAnchor:status.bottomAnchor constant:12],
        [nav.leadingAnchor constraintEqualToAnchor:header.leadingAnchor],
        [nav.trailingAnchor constraintEqualToAnchor:header.trailingAnchor],
        [nav.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-10],
        [nav.heightAnchor constraintEqualToConstant:58],
        [navProfile.topAnchor constraintEqualToAnchor:nav.topAnchor],
        [navProfile.bottomAnchor constraintEqualToAnchor:nav.bottomAnchor],
        [navProfile.leadingAnchor constraintEqualToAnchor:nav.leadingAnchor],
        [sep.leadingAnchor constraintEqualToAnchor:navProfile.trailingAnchor],
        [sep.topAnchor constraintEqualToAnchor:nav.topAnchor],
        [sep.bottomAnchor constraintEqualToAnchor:nav.bottomAnchor],
        [sep.widthAnchor constraintEqualToConstant:1],
        [navSettings.leadingAnchor constraintEqualToAnchor:sep.trailingAnchor],
        [navSettings.topAnchor constraintEqualToAnchor:nav.topAnchor],
        [navSettings.bottomAnchor constraintEqualToAnchor:nav.bottomAnchor],
        [navSettings.trailingAnchor constraintEqualToAnchor:nav.trailingAnchor],
        [navSettings.widthAnchor constraintEqualToAnchor:navProfile.widthAnchor],
    ]];
}

#pragma mark - Construcción: lanzamiento

- (void)buildLaunching {
    UIView *v = [UIView new];
    v.backgroundColor = ECNight;
    v.frame = self.view.bounds;
    v.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    v.hidden = YES;
    [self.view addSubview:v];
    self.launchingView = v;

    // Estrellas de fondo
    for (int i = 0; i < 26; i++) {
        CGFloat s = 1 + arc4random_uniform(100) / 100.0 + 1;
        UIView *star = [UIView new];
        star.backgroundColor = ECIvory;
        star.layer.cornerRadius = s / 2;
        star.bounds = CGRectMake(0, 0, s, s);
        star.tag = 100 + i;
        star.alpha = .15 + .45 * (arc4random_uniform(100) / 100.0);
        [v addSubview:star];
        CABasicAnimation *tw = [CABasicAnimation animationWithKeyPath:@"opacity"];
        tw.fromValue = @.15;
        tw.toValue = @.6;
        tw.duration = 2 + arc4random_uniform(200) / 100.0;
        tw.autoreverses = YES;
        tw.repeatCount = HUGE_VALF;
        tw.timeOffset = arc4random_uniform(400) / 100.0;
        [star.layer addAnimation:tw forKey:@"tw"];
    }

    // Luna dibujada con estrellas que laten en secuencia
    UIView *constellation = [UIView new];
    constellation.translatesAutoresizingMaskIntoConstraints = NO;
    CGFloat s = 220;
    NSMutableArray *pts = [NSMutableArray new];
    for (int k = 0; k < 18; k++) {
        CGFloat a = (50 + k * 260.0 / 17) * M_PI / 180;
        [pts addObject:[NSValue valueWithCGPoint:CGPointMake(s / 2 + cos(a) * s * .42, s / 2 + sin(a) * s * .42)]];
    }
    for (int k = 0; k < 9; k++) {
        CGFloat a = (100 + k * 20.0) * M_PI / 180;
        [pts addObject:[NSValue valueWithCGPoint:CGPointMake(s * .46 + cos(a) * s * .30, s / 2 + sin(a) * s * .30)]];
    }
    UIBezierPath *outline = [UIBezierPath bezierPath];
    for (int i = 0; i < 18; i++) {
        CGPoint p = [pts[i] CGPointValue];
        if (i == 0) [outline moveToPoint:p]; else [outline addLineToPoint:p];
    }
    CAShapeLayer *line = [CAShapeLayer layer];
    line.path = outline.CGPath;
    line.strokeColor = [ECGold colorWithAlphaComponent:.18].CGColor;
    line.fillColor = UIColor.clearColor.CGColor;
    line.lineWidth = 1;
    [constellation.layer addSublayer:line];
    for (NSUInteger k = 0; k < pts.count; k++) {
        CGPoint p = [pts[k] CGPointValue];
        CALayer *glow = [CALayer layer];
        glow.frame = CGRectMake(p.x - 7, p.y - 7, 14, 14);
        glow.cornerRadius = 7;
        glow.backgroundColor = [ECGold colorWithAlphaComponent:.18].CGColor;
        CALayer *dot = [CALayer layer];
        dot.frame = CGRectMake(4, 4, 6, 6);
        dot.cornerRadius = 3;
        dot.backgroundColor = ECGold.CGColor;
        [glow addSublayer:dot];
        [constellation.layer addSublayer:glow];
        CABasicAnimation *pulse = [CABasicAnimation animationWithKeyPath:@"opacity"];
        pulse.fromValue = @.55;
        pulse.toValue = @1;
        pulse.duration = 2.1;
        pulse.autoreverses = YES;
        pulse.repeatCount = HUGE_VALF;
        pulse.beginTime = CACurrentMediaTime() + k * .23;
        [glow addAnimation:pulse forKey:@"pulse"];
    }

    UILabel *title = ECLabel(@"A entrar no mundo", 20, 600, ECIvory);
    UILabel *sub = ECLabel([NSString stringWithFormat:@"Minecraft %@ · %@", ECVersion, ECRendererLabel], 13, 400, ECMuted);
    UIView *bar = [UIView new];
    bar.backgroundColor = [ECIvory colorWithAlphaComponent:.08];
    bar.clipsToBounds = YES;
    UIView *shimmer = [UIView new];
    shimmer.backgroundColor = ECGold;
    shimmer.frame = CGRectMake(-64, 0, 64, 2);
    [bar addSubview:shimmer];
    CABasicAnimation *move = [CABasicAnimation animationWithKeyPath:@"position.x"];
    move.fromValue = @(-32);
    move.toValue = @(160 + 32);
    move.duration = 1.6;
    move.repeatCount = HUGE_VALF;
    [shimmer.layer addAnimation:move forKey:@"move"];

    UIStackView *mid = [[UIStackView alloc] initWithArrangedSubviews:@[constellation, ECSpacer(40), title, ECSpacer(8), sub, ECSpacer(20), bar]];
    mid.axis = UILayoutConstraintAxisVertical;
    mid.alignment = UIStackViewAlignmentCenter;
    mid.translatesAutoresizingMaskIntoConstraints = NO;
    [v addSubview:mid];

    UILabel *tip = ECLabel(@"Dica: pode editar os controlos táteis no menu do jogo.", 12.5, 400, ECDim);
    tip.numberOfLines = 0;
    tip.textAlignment = NSTextAlignmentCenter;
    tip.translatesAutoresizingMaskIntoConstraints = NO;
    [v addSubview:tip];

    [NSLayoutConstraint activateConstraints:@[
        [constellation.widthAnchor constraintEqualToConstant:s],
        [constellation.heightAnchor constraintEqualToConstant:s],
        [bar.widthAnchor constraintEqualToConstant:160],
        [bar.heightAnchor constraintEqualToConstant:2],
        [mid.centerXAnchor constraintEqualToAnchor:v.centerXAnchor],
        [mid.centerYAnchor constraintEqualToAnchor:v.centerYAnchor],
        [tip.leadingAnchor constraintEqualToAnchor:v.leadingAnchor constant:36],
        [tip.trailingAnchor constraintEqualToAnchor:v.trailingAnchor constant:-36],
        [tip.bottomAnchor constraintEqualToAnchor:v.safeAreaLayoutGuide.bottomAnchor constant:-40],
    ]];
}

- (void)layoutLaunchingStars {
    CGSize size = self.launchingView.bounds.size;
    for (UIView *star in self.launchingView.subviews) {
        if (star.tag < 100) continue;
        srand48(star.tag);
        star.center = CGPointMake(drand48() * size.width, drand48() * size.height);
    }
}

#pragma mark - Refresco

- (void)refreshAll {
    BOOL loggedIn = self.account != nil;
    if (loggedIn == self.homeView.hidden) {
        [self showLoggedIn:loggedIn animated:NO];
    }
    [self refreshLogin];
    [self refreshHeader];
    [self refreshStatus];

    BOOL launching = self.stage == ECStageLaunching;
    if (launching == self.launchingView.hidden) {
        [self layoutLaunchingStars];
        [self.view bringSubviewToFront:self.launchingView];
        if (launching) self.launchingView.alpha = 0;
        self.launchingView.hidden = NO;
        [UIView animateWithDuration:launching ? 0.5 : 0.4 animations:^{
            self.launchingView.alpha = launching ? 1 : 0;
        } completion:^(BOOL finished) {
            if (self.stage != ECStageLaunching) self.launchingView.hidden = YES;
        }];
    }
    [self reloadSheet];
}

- (void)refreshHeader {
    UIImage *head = self.skinTexture ? [ECSkinRender headFromTexture:self.skinTexture size:40] : nil;
    [self.avatarButton setImage:head forState:UIControlStateNormal];
    NSString *name = self.username;
    [self.avatarButton setTitle:head ? nil : (name.length ? [name substringToIndex:1].uppercaseString : nil) forState:UIControlStateNormal];
}

- (void)refreshStatus {
    BOOL busy = self.busy && self.stage != ECStageLaunching && self.stage != ECStageIdle;
    NSString *title, *sub;
    NSNumberFormatter *nf = [NSNumberFormatter new];
    nf.numberStyle = NSNumberFormatterDecimalStyle;
    nf.groupingSeparator = @".";
    nf.usesGroupingSeparator = YES;
    if (busy && self.stage == ECStageFiles) {
        title = @"A transferir ficheiros";
        sub = [NSString stringWithFormat:@"%@ de %@", [nf stringFromNumber:@(self.filesDone)], [nf stringFromNumber:@(self.filesTotal)]];
    } else if (busy && self.stage == ECStageJava) {
        title = @"A preparar o Java";
        sub = [NSString stringWithFormat:@"A verificar o runtime · %d %%", (int)(MAX(0, self.progress) * 100)];
    } else if (busy) {
        title = [NSString stringWithFormat:@"A preparar o Minecraft %@", ECVersion];
        sub = @"A ler a versão…";
    } else if (!self.account) {
        title = @"Bem-vindo";
        sub = @"Inicie sessão para jogar";
    } else {
        title = [NSString stringWithFormat:@"Minecraft %@", ECVersion];
        sub = [NSString stringWithFormat:@"%@ · pronto para jogar", self.username];
    }
    self.statusTitle.text = title;
    self.statusSub.text = sub;

    self.playControl.busy = busy;
    self.playControl.progress = (self.stage == ECStageFiles || self.stage == ECStageJava) ? self.progress : -1;
    self.playControl.enabled = !self.busy;
    [UIView animateWithDuration:0.6 animations:^{
        self.heroVeil.alpha = busy ? .5 : 0;
    }];
    self.stars.idle = !busy;
    self.stars.lit = busy ? MAX(0, self.progress) : 0;

    if (busy) {
        NSArray *steps = @[@"Versão", @"Ficheiros", @"Java", @"Iniciar"];
        NSMutableAttributedString *t = [NSMutableAttributedString new];
        for (NSInteger i = 0; i < steps.count; i++) {
            ECStage s = (ECStage)(i + 1);
            BOOL done = s < self.stage, current = s == self.stage;
            NSString *text = [NSString stringWithFormat:@"%@%@%@", i ? @"     " : @"", done ? @"✓ " : @"", steps[i]];
            [t appendAttributedString:[[NSAttributedString alloc] initWithString:text attributes:@{
                NSFontAttributeName: ECFont(11.5, current ? 700 : 500),
                NSForegroundColorAttributeName: done ? ECGold : current ? ECIvory : ECDim
            }]];
        }
        self.stepsLabel.attributedText = t;
    } else {
        self.stepsLabel.attributedText = nil;
    }
}

#pragma mark - Paneles

- (void)openProfile {
    if (!self.account) return;
    self.skinMessage = nil;
    [self openSheet:ECSheetProfile];
    [self loadSkin];
}

- (void)openSettings {
    [self openSheet:ECSheetSettings];
}

- (void)openSheet:(ECSheetKind)kind {
    if (self.sheet) {
        // Cambiar de panel: se cierra el actual y se abre el nuevo
        ECSheet *old = self.sheet;
        old.onDismiss = nil;
        self.sheet = nil;
        [old dismiss];
    }
    self.sheetKind = kind;
    ECSheet *sheet = [ECSheet new];
    __weak ECLauncherViewController *weakSelf = self;
    __weak ECSheet *weakSheet = sheet;
    sheet.onDismiss = ^{
        if (weakSelf.sheet == weakSheet) {
            weakSelf.sheet = nil;
            weakSelf.sheetKind = ECSheetNone;
            weakSelf.logView = nil;
        }
    };
    self.sheet = sheet;
    [self reloadSheet];
    [sheet presentInView:self.view];
}

- (void)reloadSheet {
    ECSheet *sheet = self.sheet;
    if (!sheet) return;
    for (UIView *v in sheet.stack.arrangedSubviews) {
        [v removeFromSuperview];
    }
    self.logView = nil;
    if (self.sheetKind == ECSheetProfile) {
        if (!self.account) {
            [sheet dismiss];
            return;
        }
        [self buildProfileInto:sheet.stack];
    } else if (self.sheetKind == ECSheetSettings) {
        [self buildSettingsInto:sheet.stack];
    }
}

- (UILabel *)sheetTitle:(NSString *)text {
    return ECLabel(text, 22, 600, ECIvory);
}

- (UIView *)tileWithSymbol:(NSString *)symbol label:(NSString *)label value:(NSString *)value {
    UIControl *tile = [UIControl new];
    tile.layer.cornerRadius = 18;
    tile.layer.cornerCurve = kCACornerCurveContinuous;
    tile.layer.borderWidth = 1;
    tile.layer.borderColor = ECHair.CGColor;
    [tile addTarget:self action:@selector(openSettings) forControlEvents:UIControlEventTouchUpInside];
    UIImageView *icon = [[UIImageView alloc] initWithImage:ECSymbol(symbol, 16, UIFontWeightSemibold)];
    icon.tintColor = ECGold;
    icon.contentMode = UIViewContentModeLeft;
    UILabel *l = ECLabel(label, 11.5, 400, ECMuted);
    UILabel *val = ECLabel(value, value.length > 9 ? 13 : 15, 700, ECIvory);
    val.adjustsFontSizeToFitWidth = YES;
    val.minimumScaleFactor = 0.7;
    UIStackView *col = [[UIStackView alloc] initWithArrangedSubviews:@[icon, ECSpacer(8), l, val]];
    col.axis = UILayoutConstraintAxisVertical;
    col.userInteractionEnabled = NO;
    col.translatesAutoresizingMaskIntoConstraints = NO;
    [tile addSubview:col];
    [NSLayoutConstraint activateConstraints:@[
        [col.topAnchor constraintEqualToAnchor:tile.topAnchor constant:14],
        [col.bottomAnchor constraintEqualToAnchor:tile.bottomAnchor constant:-14],
        [col.leadingAnchor constraintEqualToAnchor:tile.leadingAnchor constant:14],
        [col.trailingAnchor constraintEqualToAnchor:tile.trailingAnchor constant:-10],
    ]];
    return tile;
}

- (void)buildProfileInto:(UIStackView *)stack {
    __weak ECLauncherViewController *weakSelf = self;

    // Cabeza + nombre
    UIImageView *head = [UIImageView new];
    head.backgroundColor = ECSurface;
    head.layer.cornerRadius = 12;
    head.layer.cornerCurve = kCACornerCurveContinuous;
    head.layer.borderWidth = 1;
    head.layer.borderColor = [ECGold colorWithAlphaComponent:.45].CGColor;
    head.clipsToBounds = YES;
    head.image = self.skinTexture ? [ECSkinRender headFromTexture:self.skinTexture size:60] : nil;
    [head.widthAnchor constraintEqualToConstant:60].active = YES;
    [head.heightAnchor constraintEqualToConstant:60].active = YES;
    if (!head.image) {
        UILabel *initial = ECLabel(self.username.length ? [self.username substringToIndex:1].uppercaseString : @"", 22, 700, ECGold);
        initial.textAlignment = NSTextAlignmentCenter;
        initial.frame = CGRectMake(0, 0, 60, 60);
        [head addSubview:initial];
    }
    UILabel *name = ECLabel(self.username, 18, 600, ECIvory);
    UILabel *type = ECLabel(self.isPremium ? @"Microsoft" : @"Offline", 12.5, 400, self.isPremium ? ECGold : ECMuted);
    UIStackView *names = [[UIStackView alloc] initWithArrangedSubviews:@[name, type]];
    names.axis = UILayoutConstraintAxisVertical;
    UIStackView *who = [[UIStackView alloc] initWithArrangedSubviews:@[head, names]];
    who.spacing = 14;
    who.alignment = UIStackViewAlignmentCenter;
    [stack addArrangedSubview:who];
    [stack addArrangedSubview:ECSpacer(18)];

    ECSegmented *tabs = [[ECSegmented alloc] initWithItems:@[@"Conta", @"Skin"]];
    tabs.selectedIndex = self.profileTab;
    tabs.onSelect = ^(NSInteger index) {
        weakSelf.profileTab = index;
        weakSelf.skinMessage = nil;
        [weakSelf reloadSheet];
    };
    [stack addArrangedSubview:tabs];
    [stack addArrangedSubview:ECSpacer(16)];

    if (self.profileTab == 1) {
        [self buildSkinInto:stack];
        return;
    }

    UIStackView *tiles = ECRow(@[
        [self tileWithSymbol:@"star.fill" label:@"Versão" value:ECVersion],
        [self tileWithSymbol:@"memorychip" label:@"Memória" value:[NSString stringWithFormat:@"%d MB", self.ramMb]],
        [self tileWithSymbol:@"wrench.fill" label:@"Renderer" value:@"Metal"],
    ], 10);
    [stack addArrangedSubview:tiles];
    [stack addArrangedSubview:ECSpacer(18)];
    ECButton *logout = [ECButton buttonWithStyle:ECButtonStyleOutline title:@"Terminar sessão" symbol:@"arrow.right.square" action:^{
        [weakSelf logout];
    }];
    logout.enabled = !self.busy;
    [stack addArrangedSubview:logout];
}

- (void)buildSkinInto:(UIStackView *)stack {
    __weak ECLauncherViewController *weakSelf = self;
    ECSkinProfile *current = self.skinProfile;
    UIImage *shown = self.pendingSkin ?: self.skinTexture;
    UIImage *cape = current.activeCape.texture;

    // Vista previa: frente y espalda
    UIView *preview = [UIView new];
    preview.backgroundColor = ECSurface;
    preview.layer.cornerRadius = 20;
    preview.layer.cornerCurve = kCACornerCurveContinuous;
    preview.layer.borderWidth = 1;
    preview.layer.borderColor = ECHair.CGColor;
    [preview.heightAnchor constraintEqualToConstant:230].active = YES;
    if (shown) {
        CGFloat px = 6;
        UIImageView *front = [[UIImageView alloc] initWithImage:[ECSkinRender figureFromTexture:shown slim:self.slimSelection back:NO cape:nil pixel:px]];
        UIImageView *back = [[UIImageView alloc] initWithImage:[ECSkinRender figureFromTexture:shown slim:self.slimSelection back:YES cape:cape pixel:px]];
        UIStackView *figs = [[UIStackView alloc] initWithArrangedSubviews:@[front, back]];
        figs.spacing = 36;
        figs.translatesAutoresizingMaskIntoConstraints = NO;
        [preview addSubview:figs];
        [NSLayoutConstraint activateConstraints:@[
            [figs.centerXAnchor constraintEqualToAnchor:preview.centerXAnchor],
            [figs.centerYAnchor constraintEqualToAnchor:preview.centerYAnchor],
        ]];
    } else {
        UIView *placeholder;
        if (self.skinBusy) {
            UIActivityIndicatorView *spin = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
            spin.color = ECGold;
            [spin startAnimating];
            placeholder = spin;
        } else {
            placeholder = ECLabel(@"Skin indisponível", 13, 400, ECDim);
        }
        placeholder.translatesAutoresizingMaskIntoConstraints = NO;
        [preview addSubview:placeholder];
        [NSLayoutConstraint activateConstraints:@[
            [placeholder.centerXAnchor constraintEqualToAnchor:preview.centerXAnchor],
            [placeholder.centerYAnchor constraintEqualToAnchor:preview.centerYAnchor],
        ]];
    }
    if (self.pendingSkin) {
        UILabel *badge = ECLabel(@"  Nova · por aplicar  ", 11, 700, ECNight);
        badge.backgroundColor = ECGold;
        badge.layer.cornerRadius = 10;
        badge.clipsToBounds = YES;
        badge.translatesAutoresizingMaskIntoConstraints = NO;
        [preview addSubview:badge];
        [NSLayoutConstraint activateConstraints:@[
            [badge.topAnchor constraintEqualToAnchor:preview.topAnchor constant:12],
            [badge.leadingAnchor constraintEqualToAnchor:preview.leadingAnchor constant:12],
            [badge.heightAnchor constraintEqualToConstant:20],
        ]];
    }
    [stack addArrangedSubview:preview];

    if (!self.isPremium) {
        [stack addArrangedSubview:ECSpacer(14)];
        UILabel *note = ECLabel(@"As contas offline não têm skin na Mojang: a pré-visualização mostra a skin associada a este nome. Em breve poderá escolher a sua skin no servidor Eclipse.", 13, 400, ECMuted);
        note.numberOfLines = 0;
        [stack addArrangedSubview:note];
        return;
    }

    [stack addArrangedSubview:ECSpacer(16)];
    [stack addArrangedSubview:ECLabel(@"Modelo", 13, 400, ECMuted)];
    [stack addArrangedSubview:ECSpacer(8)];
    ECSegmented *model = [[ECSegmented alloc] initWithItems:@[@"Clássico", @"Fino"]];
    model.selectedIndex = self.slimSelection ? 1 : 0;
    model.enabled = !self.skinBusy && shown != nil;
    model.onSelect = ^(NSInteger index) {
        weakSelf.slimSelection = index == 1;
        [weakSelf reloadSheet];
    };
    [stack addArrangedSubview:model];
    [stack addArrangedSubview:ECSpacer(14)];

    ECButton *choose = [ECButton buttonWithStyle:ECButtonStyleOutline title:@"Escolher imagem" symbol:@"plus" action:^{
        [weakSelf pickSkin];
    }];
    ECButton *reset = [ECButton buttonWithStyle:ECButtonStyleOutline title:@"Repor" symbol:@"arrow.clockwise" action:^{
        [weakSelf resetSkin];
    }];
    choose.enabled = reset.enabled = !self.skinBusy;
    [stack addArrangedSubview:ECRow(@[choose, reset], 10)];
    [stack addArrangedSubview:ECSpacer(10)];

    BOOL dirty = self.pendingSkin != nil || (current && self.slimSelection != current.slim);
    ECButton *apply = [ECButton buttonWithStyle:ECButtonStyleGold title:(self.skinBusy && dirty) ? @"A aplicar…" : @"Aplicar skin" symbol:@"checkmark" action:^{
        [weakSelf applySkin];
    }];
    apply.enabled = dirty;
    apply.loading = self.skinBusy && dirty;
    [stack addArrangedSubview:apply];
    if (self.pendingSkin) {
        UIButton *discard = [UIButton buttonWithType:UIButtonTypeSystem];
        [discard setAttributedTitle:[[NSAttributedString alloc] initWithString:@"Descartar" attributes:@{NSFontAttributeName: ECFont(14, 500), NSForegroundColorAttributeName: ECMuted}] forState:UIControlStateNormal];
        [discard addTarget:self action:@selector(discardPending) forControlEvents:UIControlEventTouchUpInside];
        [stack addArrangedSubview:discard];
    }

    if (current.capes.count > 0) {
        [stack addArrangedSubview:ECSpacer(18)];
        [stack addArrangedSubview:ECLabel(@"Capa", 13, 400, ECMuted)];
        [stack addArrangedSubview:ECSpacer(8)];
        NSMutableArray *options = [NSMutableArray arrayWithObject:NSNull.null];
        [options addObjectsFromArray:current.capes];
        for (NSUInteger i = 0; i < options.count; i += 4) {
            NSMutableArray *row = [NSMutableArray new];
            for (NSUInteger j = i; j < i + 4; j++) {
                if (j < options.count) {
                    id c = options[j];
                    ECCape *capeObj = c == NSNull.null ? nil : c;
                    [row addObject:[self capeChip:capeObj selected:capeObj ? capeObj.active : current.activeCape == nil]];
                } else {
                    [row addObject:[UIView new]];
                }
            }
            [stack addArrangedSubview:ECRow(row, 10)];
            [stack addArrangedSubview:ECSpacer(10)];
        }
    }

    if (self.skinMessage) {
        [stack addArrangedSubview:ECSpacer(12)];
        UILabel *msg = ECLabel(self.skinMessage, 12.5, 400, [self.skinMessage hasPrefix:@"Skin "] ? ECOnline : ECGoldLo);
        msg.numberOfLines = 0;
        [stack addArrangedSubview:msg];
    }
    [stack addArrangedSubview:ECSpacer(10)];
    UILabel *note = ECLabel(@"As alterações aplicam-se à sua conta Microsoft: verá a nova skin em todos os servidores e no PC.", 12, 400, ECDim);
    note.numberOfLines = 0;
    [stack addArrangedSubview:note];
}

- (void)discardPending {
    [self clearPendingSkin];
    self.slimSelection = self.skinProfile.slim;
    [self reloadSheet];
}

- (UIView *)capeChip:(ECCape *)cape selected:(BOOL)selected {
    UIControl *chip = [UIControl new];
    chip.layer.cornerRadius = 14;
    chip.layer.cornerCurve = kCACornerCurveContinuous;
    chip.layer.borderWidth = 1;
    chip.layer.borderColor = (selected ? [ECGold colorWithAlphaComponent:.7] : ECHair).CGColor;
    chip.enabled = !self.skinBusy && !selected;
    objc_setAssociatedObject(chip, @selector(capeChip:selected:), cape.capeId ?: @"", OBJC_ASSOCIATION_COPY);
    [chip addTarget:self action:@selector(capeTapped:) forControlEvents:UIControlEventTouchUpInside];

    UIView *thumb;
    if (cape.texture) {
        UIImageView *iv = [[UIImageView alloc] initWithImage:[ECSkinRender capeThumb:cape.texture pixel:3]];
        iv.contentMode = UIViewContentModeCenter;
        thumb = iv;
    } else {
        thumb = ECLabel(@"—", 18, 400, ECDim);
        ((UILabel *)thumb).textAlignment = NSTextAlignmentCenter;
    }
    [thumb.heightAnchor constraintEqualToConstant:48].active = YES;
    UILabel *label = ECLabel(cape ? cape.alias : @"Nenhuma", 11, 400, selected ? ECGold : ECMuted);
    label.textAlignment = NSTextAlignmentCenter;
    label.adjustsFontSizeToFitWidth = YES;
    label.minimumScaleFactor = 0.7;
    UIStackView *col = [[UIStackView alloc] initWithArrangedSubviews:@[thumb, ECSpacer(6), label]];
    col.axis = UILayoutConstraintAxisVertical;
    col.userInteractionEnabled = NO;
    col.translatesAutoresizingMaskIntoConstraints = NO;
    [chip addSubview:col];
    [NSLayoutConstraint activateConstraints:@[
        [col.topAnchor constraintEqualToAnchor:chip.topAnchor constant:10],
        [col.bottomAnchor constraintEqualToAnchor:chip.bottomAnchor constant:-10],
        [col.leadingAnchor constraintEqualToAnchor:chip.leadingAnchor constant:6],
        [col.trailingAnchor constraintEqualToAnchor:chip.trailingAnchor constant:-6],
    ]];
    return chip;
}

- (void)capeTapped:(UIControl *)chip {
    NSString *capeId = objc_getAssociatedObject(chip, @selector(capeChip:selected:));
    [self setCape:capeId.length ? capeId : nil];
}

- (UIView *)settingRow:(NSString *)label value:(NSString *)value {
    UILabel *l = ECLabel(label, 15, 400, ECIvory);
    UILabel *v = ECLabel(value, 14, 400, ECMuted);
    v.textAlignment = NSTextAlignmentRight;
    UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:@[l, v]];
    row.layoutMargins = UIEdgeInsetsMake(16, 0, 16, 0);
    row.layoutMarginsRelativeArrangement = YES;
    return row;
}

- (void)buildSettingsInto:(UIStackView *)stack {
    __weak ECLauncherViewController *weakSelf = self;
    [stack addArrangedSubview:[self sheetTitle:@"Definições"]];
    [stack addArrangedSubview:ECSpacer(8)];
    [stack addArrangedSubview:[self settingRow:@"Versão" value:ECVersion]];
    [stack addArrangedSubview:ECDivider()];

    // Memoria
    UILabel *memLabel = ECLabel(@"Memória", 15, 400, ECIvory);
    UILabel *memValue = ECLabel([NSString stringWithFormat:@"%d MB", self.ramMb], 15, 400, ECGold);
    memValue.textAlignment = NSTextAlignmentRight;
    UIStackView *memRow = [[UIStackView alloc] initWithArrangedSubviews:@[memLabel, memValue]];
    UISlider *slider = [UISlider new];
    slider.minimumValue = 1024;
    slider.maximumValue = ECMaxRAM();
    slider.value = self.ramMb;
    slider.enabled = !self.busy;
    slider.minimumTrackTintColor = ECGold;
    slider.maximumTrackTintColor = [ECIvory colorWithAlphaComponent:.12];
    slider.thumbTintColor = ECIvory;
    [slider addTarget:self action:@selector(sliderChanged:) forControlEvents:UIControlEventValueChanged];
    objc_setAssociatedObject(slider, @selector(sliderChanged:), memValue, OBJC_ASSOCIATION_RETAIN);
    UILabel *rec = ECLabel([NSString stringWithFormat:@"Recomendado para este dispositivo: %d MB", ECRecommendedRAM()], 12, 400, ECMuted);
    rec.numberOfLines = 0;
    UIStackView *mem = [[UIStackView alloc] initWithArrangedSubviews:@[memRow, ECSpacer(6), slider, ECSpacer(6), rec]];
    mem.axis = UILayoutConstraintAxisVertical;
    mem.layoutMargins = UIEdgeInsetsMake(16, 0, 12, 0);
    mem.layoutMarginsRelativeArrangement = YES;
    ECTier tier = ECDeviceTier();
    if (tier == ECTierMinimum || tier == ECTierNotRecommended) {
        UILabel *warn = ECLabel(tier == ECTierMinimum
            ? @"Este iPhone está no mínimo suportado: use distâncias de visão baixas."
            : @"Este iPhone não é recomendado: o jogo pode fechar sozinho por falta de memória.", 12, 400, tier == ECTierMinimum ? ECGoldLo : ECDanger);
        warn.numberOfLines = 0;
        [mem addArrangedSubview:ECSpacer(6)];
        [mem addArrangedSubview:warn];
    }
    [stack addArrangedSubview:mem];
    [stack addArrangedSubview:ECDivider()];
    [stack addArrangedSubview:[self settingRow:@"Renderer" value:ECRendererLabel]];
    [stack addArrangedSubview:ECSpacer(16)];

    ECButton *verify = [ECButton buttonWithStyle:ECButtonStyleOutline title:@"Verificar ficheiros" symbol:@"arrow.clockwise" action:^{
        [weakSelf.sheet dismiss];
        [weakSelf verifyFiles];
    }];
    verify.enabled = !self.busy && self.account != nil;
    ECButton *logButton = [ECButton buttonWithStyle:ECButtonStyleOutline title:self.showLog ? @"Ocultar registo" : @"Registo" symbol:@"list.bullet" action:^{
        weakSelf.showLog = !weakSelf.showLog;
        [weakSelf reloadSheet];
    }];
    [stack addArrangedSubview:ECRow(@[verify, logButton], 10)];

    if (self.showLog) {
        [stack addArrangedSubview:ECSpacer(12)];
        UITextView *tv = [UITextView new];
        tv.editable = NO;
        tv.backgroundColor = EC_HEX(0x09080C, 1);
        tv.textColor = EC_HEX(0xBDB6A0, 1);
        tv.font = [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightRegular];
        tv.layer.cornerRadius = 14;
        tv.layer.borderWidth = 1;
        tv.layer.borderColor = ECHair.CGColor;
        tv.textContainerInset = UIEdgeInsetsMake(10, 6, 10, 6);
        [tv.heightAnchor constraintEqualToConstant:240].active = YES;
        self.logView = tv;
        [self logChanged];
        [stack addArrangedSubview:tv];

        // Herramientas de depuración: la interfaz completa de Amethyst
        UIButton *advanced = [UIButton buttonWithType:UIButtonTypeSystem];
        [advanced setAttributedTitle:[[NSAttributedString alloc] initWithString:@"Abrir modo avançado (Amethyst)" attributes:@{NSFontAttributeName: ECFont(12.5, 500), NSForegroundColorAttributeName: ECMuted}] forState:UIControlStateNormal];
        [advanced addTarget:self action:@selector(openAdvanced) forControlEvents:UIControlEventTouchUpInside];
        [stack addArrangedSubview:advanced];
    }
    [stack addArrangedSubview:ECSpacer(10)];

    ECButton *wipe = [ECButton buttonWithStyle:ECButtonStyleDanger title:@"Apagar dados do Minecraft" symbol:@"trash.fill" action:^{
        [weakSelf confirmWipe];
    }];
    wipe.enabled = !self.busy;
    [stack addArrangedSubview:wipe];
    [stack addArrangedSubview:ECSpacer(18)];

    // Licenças (obligatorio por la LGPL de Amethyst-iOS)
    UILabel *licTitle = ECLabel(@"Licenças", 15, 600, ECIvory);
    UILabel *lic = ECLabel(@"Baseado no Amethyst-iOS (AngelAuraMC) e no PojavLauncher, sob a licença GNU LGPL-3.0. O código-fonte desta aplicação, com todas as alterações, é público em github.com/Ditoo1/ios-cobblelauncher.\n\nTipo de letra Lexend, sob a SIL Open Font License 1.1.\n\nMinecraft é uma marca da Mojang AB. Esta aplicação não é oficial nem está associada à Mojang ou à Microsoft.", 12, 400, ECMuted);
    lic.numberOfLines = 0;
    [stack addArrangedSubview:licTitle];
    [stack addArrangedSubview:ECSpacer(6)];
    [stack addArrangedSubview:lic];
    [stack addArrangedSubview:ECSpacer(18)];
    NSString *ver = NSBundle.mainBundle.infoDictionary[@"CFBundleShortVersionString"];
    [stack addArrangedSubview:ECLabel([NSString stringWithFormat:@"EclipseCobblemon %@ · Runtime Amethyst", ver], 11.5, 400, ECDim)];
}

- (void)sliderChanged:(UISlider *)slider {
    int mb = (int)(slider.value / 256) * 256;
    self.ramMb = mb;
    UILabel *value = objc_getAssociatedObject(slider, @selector(sliderChanged:));
    value.text = [NSString stringWithFormat:@"%d MB", mb];
}

- (void)logChanged {
    UITextView *tv = self.logView;
    if (!tv) return;
    tv.text = [ECLogLines() componentsJoinedByString:@"\n"];
    if (tv.text.length) [tv scrollRangeToVisible:NSMakeRange(tv.text.length - 1, 1)];
}

- (void)openAdvanced {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Modo avançado"
        message:@"Abre a interface original do Amethyst para depuração (controlos, runtimes, ficheiros). Para voltar ao Eclipse, feche e volte a abrir a app."
        preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancelar" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Abrir" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        UIWindow *window = self.view.window;
        window.rootViewController = [[LauncherSplitViewController alloc] initWithStyle:UISplitViewControllerStyleDoubleColumn];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Utilidades

- (void)alert:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    UIViewController *top = self;
    while (top.presentedViewController) top = top.presentedViewController;
    [top presentViewController:alert animated:YES completion:nil];
}

@end
