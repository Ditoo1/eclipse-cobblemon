#import <UIKit/UIKit.h>

/// Luna creciente: disco dorado tapado por otro del color del fondo.
@interface ECMoonView : UIView
@property(nonatomic) UIColor *cutColor;
@end

typedef NS_ENUM(NSInteger, ECButtonStyle) {
    ECButtonStyleGold,
    ECButtonStyleOutline,
    ECButtonStyleDanger
};

/// Botón con icono y texto, en los estilos dorado y contorno de la app Android.
@interface ECButton : UIControl
@property(nonatomic) ECButtonStyle style;
@property(nonatomic, copy) NSString *title;
@property(nonatomic, copy) NSString *symbol;
@property(nonatomic) BOOL loading;
@property(nonatomic, copy) void (^action)(void);
+ (instancetype)buttonWithStyle:(ECButtonStyle)style title:(NSString *)title symbol:(NSString *)symbol action:(void (^)(void))action;
@end

/// Selector segmentado (Conta | Skin, Clássico | Fino).
@interface ECSegmented : UIControl
@property(nonatomic) NSInteger selectedIndex;
@property(nonatomic, copy) void (^onSelect)(NSInteger index);
- (instancetype)initWithItems:(NSArray<NSString *> *)items;
@end

/// Línea de estrellas que se encienden de izquierda a derecha con el progreso.
@interface ECStarStrip : UIView
@property(nonatomic) CGFloat lit;
@property(nonatomic) BOOL idle;
@end

/// Botón de jugar (círculo dorado) que se convierte en anillo de progreso.
@interface ECPlayControl : UIControl
@property(nonatomic) BOOL busy;
/// Progreso 0–1, o negativo para indeterminado.
@property(nonatomic) CGFloat progress;
@end

/// Panel inferior modal (bottom sheet) con tirador, como ModalBottomSheet de Compose.
@interface ECSheet : UIView
@property(nonatomic, readonly) UIStackView *stack;
@property(nonatomic, copy) void (^onDismiss)(void);
- (void)presentInView:(UIView *)host;
- (void)dismiss;
@end

/// Separador de 1 px en Hair.
UIView *ECDivider(void);
/// Espacio vertical fijo para pilas.
UIView *ECSpacer(CGFloat height);
/// Fila horizontal con reparto igual.
UIStackView *ECRow(NSArray<UIView *> *views, CGFloat spacing);
