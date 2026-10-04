/* C ABI de libeclipse_core para clientes Apple (Swift/Obj-C). Mantener en sincronía con src/lib.rs (mod ffi). */
#ifndef ECLIPSE_CORE_H
#define ECLIPSE_CORE_H

#ifdef __cplusplus
extern "C" {
#endif

/* UUID v3 de "OfflinePlayer:<name>". Liberar con eclipse_free_string. */
char *eclipse_offline_uuid(const char *name);

/* SHA-1 hex de un archivo, o NULL si no se puede leer. Liberar con eclipse_free_string. */
char *eclipse_sha1_file(const char *path);

void eclipse_free_string(char *s);

#ifdef __cplusplus
}
#endif

#endif /* ECLIPSE_CORE_H */
