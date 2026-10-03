#import "ECTheme.h"
#import "ECViews.h"

UIView *ECDivider(void) {
    UIView *v = [UIView new];
    v.backgroundColor = ECHair;
    [v.heightAnchor constraintEqualToConstant:1].active = YES;
    return v;
}

UIView *ECSpacer(CGFloat height) {
    UIView *v = [UIView new];
    [v.heightAnchor constraintEqualToConstant:height].active = YES;
    return v;
}

UIStackView *ECRow(NSArray<UIView *> *views, CGFloat spacing) {
    UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:views];
    row.axis = UILayoutConstraintAxisHorizontal;
    row.distribution = UIStackViewDistributionFillEqually;
    row.spacing = spacing;
    return row;
}

#pragma mark - Luna

@implementation ECMoonView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    self.backgroundColor = UIColor.clearColor;
    self.opaque = NO;
    self.userInteractionEnabled = NO;
    _cutColor = ECNight;
    return self;
}

- (void)setCutColor:(UIColor *)cutColor {
    _cutColor = cutColor;
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect {
    CGFloat r = MIN(self.bounds.size.width, self.bounds.size.height) / 2;
    CGPoint c = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(ctx, ECGold.CGColor);
    CGFloat r1 = r * .82;
    CGContextFillEllipseInRect(ctx, CGRectMake(c.x - r1, c.y - r1, r1 * 2, r1 * 2));
    CGContextSetFillColorWithColor(ctx, self.cutColor.CGColor);
    CGFloat r2 = r * .68;
    CGPoint c2 = CGPointMake(c.x + r * .36, c.y - r * .2);
    CGContextFillEllipseInRect(ctx, CGRectMake(c2.x - r2, c2.y - r2, r2 * 2, r2 * 2));
}

@end

#pragma mark - Botón

@interface ECButton ()
@property(nonatomic) UIImageView *icon;
@property(nonatomic) UILabel *label;
@property(nonatomic) UIActivityIndicatorView *spinner;
@property(nonatomic) UIStackView *content;
@end

@implementation ECButton

+ (instancetype)buttonWithStyle:(ECButtonStyle)style title:(NSString *)title symbol:(NSString *)symbol action:(void (^)(void))action {
    ECButton *b = [[ECButton alloc] initWithFrame:CGRectZero];
    b.style = style;
    b.title = title;
    b.symbol = symbol;
    b.action = action;
    return b;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    self.layer.cornerRadius = 16;
    self.layer.cornerCurve = kCACornerCurveContinuous;
    self.layer.borderWidth = 1;

    _icon = [UIImageView new];
    _icon.contentMode = UIViewContentModeScaleAspectFit;
    _label = [UILabel new];
    _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    _spinner.hidesWhenStopped = YES;
    _content = [[UIStackView alloc] initWithArrangedSubviews:@[_spinner, _icon, _label]];
    _content.axis = UILayoutConstraintAxisHorizontal;
    _content.spacing = 9;
    _content.alignment = UIStackViewAlignmentCenter;
    _content.userInteractionEnabled = NO;
    _content.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_content];
    [NSLayoutConstraint activateConstraints:@[
        [_content.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
        [_content.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [_content.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.leadingAnchor constant:8],
    ]];
    [self addTarget:self action:@selector(fire) forControlEvents:UIControlEventTouchUpInside];
    [self refresh];
    return self;
}

- (CGSize)intrinsicContentSize {
    return CGSizeMake(UIViewNoIntrinsicMetric, self.style == ECButtonStyleGold ? 54 : 50);
}

- (void)fire {
    if (self.loading || !self.enabled) return;
    if (self.action) self.action();
}

- (void)setStyle:(ECButtonStyle)style { _style = style; [self invalidateIntrinsicContentSize]; [self refresh]; }
- (void)setTitle:(NSString *)title { _title = [title copy]; [self refresh]; }
- (void)setSymbol:(NSString *)symbol { _symbol = [symbol copy]; [self refresh]; }
- (void)setLoading:(BOOL)loading { _loading = loading; [self refresh]; }
- (void)setEnabled:(BOOL)enabled { [super setEnabled:enabled]; [self refresh]; }

- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    self.alpha = highlighted ? 0.75 : 1;
}

- (void)refresh {
    BOOL gold = self.style == ECButtonStyleGold;
    UIColor *tint;
    if (gold) {
        tint = ECInk;
        self.backgroundColor = self.enabled ? ECGold : [ECGold colorWithAlphaComponent:.35];
        self.layer.borderColor = UIColor.clearColor.CGColor;
    } else {
        UIColor *base = self.style == ECButtonStyleDanger ? ECDanger : ECIvory;
        tint = self.enabled ? base : ECDim;
        self.backgroundColor = UIColor.clearColor;
        self.layer.borderColor = (self.style == ECButtonStyleDanger ? [ECDanger colorWithAlphaComponent:.35] : ECHair).CGColor;
    }
    self.label.attributedText = [[NSAttributedString alloc] initWithString:self.title ?: @"" attributes:@{
        NSFontAttributeName: ECFont(gold ? 15 : 14, gold ? 700 : 600),
        NSForegroundColorAttributeName: tint
    }];
    self.icon.image = self.symbol ? ECSymbol(self.symbol, gold ? 16 : 15, UIFontWeightSemibold) : nil;
    self.icon.tintColor = tint;
    self.icon.hidden = self.symbol == nil || self.loading;
    self.spinner.color = tint;
    if (self.loading) [self.spinner startAnimating]; else [self.spinner stopAnimating];
}

@end

#pragma mark - Segmentado

@interface ECSegmented ()
@property(nonatomic) NSArray<UIButton *> *buttons;
@end

@implementation ECSegmented

- (instancetype)initWithItems:(NSArray<NSString *> *)items {
    self = [super initWithFrame:CGRectZero];
    self.backgroundColor = ECSurface;
    self.layer.cornerRadius = 14;
    self.layer.borderWidth = 1;
    self.layer.borderColor = ECHair.CGColor;
    NSMutableArray *buttons = [NSMutableArray new];
    for (NSInteger i = 0; i < items.count; i++) {
        UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
        b.tag = i;
        b.layer.cornerRadius = 10;
        [b setTitle:items[i] forState:UIControlStateNormal];
        b.titleLabel.font = ECFont(14, 600);
        [b addTarget:self action:@selector(tapped:) forControlEvents:UIControlEventTouchUpInside];
        [buttons addObject:b];
    }
    self.buttons = buttons;
    UIStackView *row = ECRow(buttons, 0);
    row.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:row];
    [NSLayoutConstraint activateConstraints:@[
        [row.topAnchor constraintEqualToAnchor:self.topAnchor constant:4],
        [row.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-4],
        [row.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:4],
        [row.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-4],
        [self.heightAnchor constraintEqualToConstant:44],
    ]];
    [self refresh];
    return self;
}

- (void)tapped:(UIButton *)b {
    if (!self.enabled || b.tag == self.selectedIndex) return;
    self.selectedIndex = b.tag;
    if (self.onSelect) self.onSelect(b.tag);
}

- (void)setSelectedIndex:(NSInteger)selectedIndex { _selectedIndex = selectedIndex; [self refresh]; }
- (void)setEnabled:(BOOL)enabled { [super setEnabled:enabled]; [self refresh]; }

- (void)refresh {
    for (UIButton *b in self.buttons) {
        BOOL on = b.tag == self.selectedIndex;
        b.backgroundColor = on ? [ECGold colorWithAlphaComponent:.14] : UIColor.clearColor;
        [b setTitleColor:on ? ECGold : (self.enabled ? ECMuted : ECDim) forState:UIControlStateNormal];
    }
}

@end

#pragma mark - Estrellas

@interface ECStarStrip ()
@property(nonatomic) CADisplayLink *link;
@property(nonatomic) CGFloat t;
@property(nonatomic) CGFloat shown;
@end

@implementation ECStarStrip

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    self.backgroundColor = UIColor.clearColor;
    self.opaque = NO;
    self.userInteractionEnabled = NO;
    _idle = YES;
    return self;
}

- (void)didMoveToWindow {
    [super didMoveToWindow];
    [self.link invalidate];
    self.link = nil;
    if (self.window) {
        self.link = [CADisplayLink displayLinkWithTarget:self selector:@selector(tick:)];
        if (@available(iOS 15.0, *)) {
            self.link.preferredFrameRateRange = CAFrameRateRangeMake(20, 30, 30);
        } else {
            self.link.preferredFramesPerSecond = 30;
        }
        [self.link addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
    }
}

- (void)tick:(CADisplayLink *)link {
    if (UIAccessibilityIsReduceMotionEnabled()) {
        self.t = 0;
        self.shown = self.lit;
    } else {
        self.t = fmod(self.t + link.duration * 2 * M_PI / 4.0, 2 * M_PI);
        self.shown += (self.lit - self.shown) * 0.15;
    }
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGSize s = self.bounds.size;
    const int n = 13;
    CGPoint pts[n];
    for (int k = 0; k < n; k++) {
        pts[k] = CGPointMake(4 + (s.width - 8) * k / (n - 1), s.height / 2 + sin(k * .9) * s.height * .32);
    }
    int on = self.idle ? -1 : (int)(self.shown * (n - 1));
    CGContextSetLineWidth(ctx, 1);
    for (int k = 0; k < n - 1; k++) {
        UIColor *c = k < on ? [ECGold colorWithAlphaComponent:.55] : ECHair;
        CGContextSetStrokeColorWithColor(ctx, c.CGColor);
        CGContextMoveToPoint(ctx, pts[k].x, pts[k].y);
        CGContextAddLineToPoint(ctx, pts[k + 1].x, pts[k + 1].y);
        CGContextStrokePath(ctx);
    }
    for (int k = 0; k < n; k++) {
        CGFloat twinkle = .45 + .55 * ((sin(self.t + k * .8) + 1) / 2);
        UIColor *c;
        CGFloat r;
        if (k <= on) {
            c = [ECGold colorWithAlphaComponent:(k == on ? twinkle : 1)];
            r = 2.6;
        } else if (self.idle) {
            c = [ECGold colorWithAlphaComponent:.25 + .45 * twinkle];
            r = 1.9;
        } else {
            c = [ECIvory colorWithAlphaComponent:.28];
            r = 1.8;
        }
        CGContextSetFillColorWithColor(ctx, c.CGColor);
        CGContextFillEllipseInRect(ctx, CGRectMake(pts[k].x - r, pts[k].y - r, r * 2, r * 2));
    }
}

@end

#pragma mark - Jugar / anillo

@interface ECPlayControl ()
@property(nonatomic) UIView *disc;
@property(nonatomic) CAGradientLayer *gradient;
@property(nonatomic) UIImageView *playIcon;
@property(nonatomic) CAShapeLayer *track, *arc;
@property(nonatomic) UILabel *percent;
@property(nonatomic) ECMoonView *moon;
@end

@implementation ECPlayControl

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    self.backgroundColor = ECNight;
    self.layer.borderWidth = 1;
    self.layer.borderColor = [ECGold colorWithAlphaComponent:.35].CGColor;

    _disc = [UIView new];
    _disc.userInteractionEnabled = NO;
    _disc.clipsToBounds = YES;
    _gradient = [CAGradientLayer layer];
    _gradient.colors = @[(id)ECGoldHi.CGColor, (id)ECGoldLo.CGColor];
    [_disc.layer addSublayer:_gradient];
    [self addSubview:_disc];

    _playIcon = [[UIImageView alloc] initWithImage:ECSymbol(@"play.fill", 34, UIFontWeightBold)];
    _playIcon.tintColor = ECInk;
    _playIcon.contentMode = UIViewContentModeCenter;
    [_disc addSubview:_playIcon];

    _track = [CAShapeLayer layer];
    _track.fillColor = UIColor.clearColor.CGColor;
    _track.strokeColor = [ECGold colorWithAlphaComponent:.16].CGColor;
    _track.lineWidth = 2.5;
    _arc = [CAShapeLayer layer];
    _arc.fillColor = UIColor.clearColor.CGColor;
    _arc.strokeColor = ECGold.CGColor;
    _arc.lineWidth = 2.5;
    _arc.lineCap = kCALineCapRound;
    [self.layer addSublayer:_track];
    [self.layer addSublayer:_arc];

    _percent = [UILabel new];
    _percent.textAlignment = NSTextAlignmentCenter;
    [self addSubview:_percent];
    _moon = [ECMoonView new];
    [self addSubview:_moon];

    self.accessibilityLabel = @"Jogar";
    self.isAccessibilityElement = YES;
    self.accessibilityTraits = UIAccessibilityTraitButton;
    [self refresh];
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat s = self.bounds.size.width;
    self.layer.cornerRadius = s / 2;
    CGFloat d = s * 88.0 / 112.0;
    self.disc.frame = CGRectMake((s - d) / 2, (s - d) / 2, d, d);
    self.disc.layer.cornerRadius = d / 2;
    self.gradient.frame = self.disc.bounds;
    self.playIcon.frame = CGRectOffset(self.disc.bounds, 3, 0);
    CGFloat inset = 5 + 1.25;
    UIBezierPath *circle = [UIBezierPath bezierPathWithArcCenter:CGPointMake(s / 2, s / 2) radius:s / 2 - inset startAngle:-M_PI_2 endAngle:3 * M_PI_2 clockwise:YES];
    self.track.path = circle.CGPath;
    self.arc.path = circle.CGPath;
    self.arc.frame = self.bounds;
    self.percent.frame = self.bounds;
    self.moon.frame = CGRectMake((s - 34) / 2, (s - 34) / 2, 34, 34);
}

- (void)setBusy:(BOOL)busy {
    if (_busy == busy) return;
    _busy = busy;
    [UIView transitionWithView:self duration:0.3 options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
        [self refresh];
    } completion:nil];
}

- (void)setProgress:(CGFloat)progress {
    _progress = progress;
    [self refresh];
}

- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    if (!self.busy) self.transform = highlighted ? CGAffineTransformMakeScale(.96, .96) : CGAffineTransformIdentity;
}

- (void)refresh {
    BOOL busy = self.busy;
    self.disc.hidden = busy;
    self.layer.borderWidth = busy ? 0 : 1;
    self.track.hidden = self.arc.hidden = !busy;
    BOOL determinate = self.progress >= 0;
    self.percent.hidden = !busy || !determinate;
    self.moon.hidden = !busy || determinate;
    if (!busy) {
        [self.arc removeAnimationForKey:@"spin"];
        return;
    }
    if (determinate) {
        [self.arc removeAnimationForKey:@"spin"];
        self.arc.transform = CATransform3DIdentity;
        self.arc.strokeStart = 0;
        self.arc.strokeEnd = MAX(0, MIN(1, self.progress));
        NSMutableAttributedString *t = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%d", (int)(self.progress * 100)] attributes:@{
            NSFontAttributeName: ECFont(26, 600), NSForegroundColorAttributeName: ECIvory
        }];
        [t appendAttributedString:[[NSAttributedString alloc] initWithString:@"%" attributes:@{
            NSFontAttributeName: ECFont(13, 400), NSForegroundColorAttributeName: ECMuted
        }]];
        self.percent.attributedText = t;
    } else {
        self.arc.strokeStart = 0;
        self.arc.strokeEnd = 70.0 / 360.0;
        if (![self.arc animationForKey:@"spin"]) {
            CABasicAnimation *spin = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
            spin.fromValue = @0;
            spin.toValue = @(2 * M_PI);
            spin.duration = 1.4;
            spin.repeatCount = HUGE_VALF;
            [self.arc addAnimation:spin forKey:@"spin"];
        }
    }
}

@end

#pragma mark - Panel inferior

@interface ECSheet ()
@property(nonatomic) UIControl *scrim;
@property(nonatomic) UIView *container;
@property(nonatomic) UIScrollView *scroll;
@property(nonatomic, readwrite) UIStackView *stack;
@end

@implementation ECSheet

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    _scrim = [UIControl new];
    _scrim.backgroundColor = EC_HEX(0x050508, .62);
    [_scrim addTarget:self action:@selector(dismiss) forControlEvents:UIControlEventTouchUpInside];
    _scrim.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_scrim];

    _container = [UIView new];
    _container.backgroundColor = ECSheetBg;
    _container.layer.cornerRadius = 28;
    _container.layer.cornerCurve = kCACornerCurveContinuous;
    _container.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
    _container.layer.borderWidth = 1;
    _container.layer.borderColor = ECHair.CGColor;
    _container.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_container];

    // Zona de arrastre superior (el resto del panel desplaza el contenido)
    UIView *grab = [UIView new];
    grab.translatesAutoresizingMaskIntoConstraints = NO;
    [_container addSubview:grab];
    UIView *handle = [UIView new];
    handle.backgroundColor = [ECIvory colorWithAlphaComponent:.18];
    handle.layer.cornerRadius = 2;
    handle.translatesAutoresizingMaskIntoConstraints = NO;
    [grab addSubview:handle];

    _scroll = [UIScrollView new];
    _scroll.alwaysBounceVertical = NO;
    _scroll.showsVerticalScrollIndicator = NO;
    _scroll.translatesAutoresizingMaskIntoConstraints = NO;
    [_container addSubview:_scroll];

    _stack = [UIStackView new];
    _stack.axis = UILayoutConstraintAxisVertical;
    _stack.translatesAutoresizingMaskIntoConstraints = NO;
    [_scroll addSubview:_stack];

    NSLayoutConstraint *fit = [_scroll.heightAnchor constraintEqualToAnchor:_stack.heightAnchor constant:18 + 28];
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(pan:)];
    [grab addGestureRecognizer:pan];
    fit.priority = 700; // por debajo de la resistencia a compresión del contenido
    [NSLayoutConstraint activateConstraints:@[
        [_scrim.topAnchor constraintEqualToAnchor:self.topAnchor],
        [_scrim.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
        [_scrim.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [_scrim.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],

        [_container.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [_container.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [_container.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:1],
        [_container.topAnchor constraintGreaterThanOrEqualToAnchor:self.safeAreaLayoutGuide.topAnchor constant:24],

        [grab.topAnchor constraintEqualToAnchor:_container.topAnchor],
        [grab.leadingAnchor constraintEqualToAnchor:_container.leadingAnchor],
        [grab.trailingAnchor constraintEqualToAnchor:_container.trailingAnchor],
        [grab.heightAnchor constraintEqualToConstant:28],
        [handle.topAnchor constraintEqualToAnchor:grab.topAnchor constant:12],
        [handle.centerXAnchor constraintEqualToAnchor:grab.centerXAnchor],
        [handle.widthAnchor constraintEqualToConstant:40],
        [handle.heightAnchor constraintEqualToConstant:4],

        [_scroll.topAnchor constraintEqualToAnchor:grab.bottomAnchor],
        [_scroll.leadingAnchor constraintEqualToAnchor:_container.leadingAnchor],
        [_scroll.trailingAnchor constraintEqualToAnchor:_container.trailingAnchor],
        [_scroll.bottomAnchor constraintEqualToAnchor:_container.safeAreaLayoutGuide.bottomAnchor],
        fit,

        [_stack.topAnchor constraintEqualToAnchor:_scroll.contentLayoutGuide.topAnchor constant:18],
        [_stack.bottomAnchor constraintEqualToAnchor:_scroll.contentLayoutGuide.bottomAnchor constant:-28],
        [_stack.leadingAnchor constraintEqualToAnchor:_scroll.frameLayoutGuide.leadingAnchor constant:24],
        [_stack.trailingAnchor constraintEqualToAnchor:_scroll.frameLayoutGuide.trailingAnchor constant:-24],
    ]];

    return self;
}

- (void)pan:(UIPanGestureRecognizer *)g {
    CGFloat dy = [g translationInView:self].y;
    switch (g.state) {
        case UIGestureRecognizerStateChanged:
            self.container.transform = CGAffineTransformMakeTranslation(0, MAX(0, dy));
            break;
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
            if (dy > 120 || [g velocityInView:self].y > 800) {
                [self dismiss];
            } else {
                [UIView animateWithDuration:0.25 animations:^{ self.container.transform = CGAffineTransformIdentity; }];
            }
            break;
        default:
            break;
    }
}

- (void)presentInView:(UIView *)host {
    self.frame = host.bounds;
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [host addSubview:self];
    [self layoutIfNeeded];
    self.scrim.alpha = 0;
    self.container.transform = CGAffineTransformMakeTranslation(0, self.container.bounds.size.height + 40);
    [UIView animateWithDuration:0.42 delay:0 usingSpringWithDamping:0.92 initialSpringVelocity:0 options:0 animations:^{
        self.scrim.alpha = 1;
        self.container.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)dismiss {
    if (!self.superview) return;
    [UIView animateWithDuration:0.28 animations:^{
        self.scrim.alpha = 0;
        self.container.transform = CGAffineTransformMakeTranslation(0, self.container.bounds.size.height + 40);
    } completion:^(BOOL finished) {
        [self removeFromSuperview];
        if (self.onDismiss) self.onDismiss();
    }];
}

@end
