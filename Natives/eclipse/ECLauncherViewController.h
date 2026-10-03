#import <UIKit/UIKit.h>

/// Pantalla raíz de Eclipse Cobblemon: acceso sin sesión, inicio con el botón de jugar
/// y los paneles de Perfil y Definições. Sustituye a la interfaz de Amethyst.
@interface ECLauncherViewController : UIViewController
@end

/// Registro visible en Definições → Registo.
void ECLog(NSString *format, ...) NS_FORMAT_FUNCTION(1, 2);
