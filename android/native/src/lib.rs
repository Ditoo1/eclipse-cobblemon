//! Núcleo de EclipseCobblemon.
//!
//! La lógica vive en `core` (Rust puro, sin dependencias de plataforma) y se expone por dos vías:
//! - `android`: funciones JNI para `dev.eclipsecobblemon.launcher.nativecore.NativeCore`.
//! - `ffi`: C ABI estable (ver `include/eclipse_core.h`) para un futuro cliente Swift en iOS/macOS.

pub mod core {
    use md5::{Digest as _, Md5};
    use sha1::Sha1;
    use std::fs::File;
    use std::io::{self, Read};
    use std::path::Path;

    /// UUID v3 de `"OfflinePlayer:<name>"`, idéntico a `UUID.nameUUIDFromBytes` de Java.
    pub fn offline_uuid(name: &str) -> String {
        let mut h: [u8; 16] = Md5::digest(format!("OfflinePlayer:{name}").as_bytes()).into();
        h[6] = (h[6] & 0x0f) | 0x30; // versión 3
        h[8] = (h[8] & 0x3f) | 0x80; // variante IETF
        let hex = to_hex(&h);
        format!("{}-{}-{}-{}-{}", &hex[0..8], &hex[8..12], &hex[12..16], &hex[16..20], &hex[20..32])
    }

    /// SHA-1 en hex de un archivo, leído por bloques.
    pub fn sha1_file(path: impl AsRef<Path>) -> io::Result<String> {
        let mut file = File::open(path)?;
        let mut hasher = Sha1::new();
        let mut buf = [0u8; 64 * 1024];
        loop {
            let n = file.read(&mut buf)?;
            if n == 0 {
                break;
            }
            hasher.update(&buf[..n]);
        }
        Ok(to_hex(&hasher.finalize()))
    }

    fn to_hex(bytes: &[u8]) -> String {
        bytes.iter().map(|b| format!("{b:02x}")).collect()
    }
}

/// C ABI para Apple (Swift lo importa con el header + module map). Las cadenas devueltas
/// se liberan con `eclipse_free_string`.
pub mod ffi {
    use std::ffi::{c_char, CStr, CString};
    use std::ptr;

    unsafe fn read(s: *const c_char) -> Option<String> {
        if s.is_null() {
            return None;
        }
        CStr::from_ptr(s).to_str().ok().map(str::to_owned)
    }

    fn give(s: String) -> *mut c_char {
        CString::new(s).map(CString::into_raw).unwrap_or(ptr::null_mut())
    }

    /// # Safety
    /// `name` debe ser un C string UTF-8 válido o NULL.
    #[no_mangle]
    pub unsafe extern "C" fn eclipse_offline_uuid(name: *const c_char) -> *mut c_char {
        read(name).map_or(ptr::null_mut(), |n| give(super::core::offline_uuid(&n)))
    }

    /// # Safety
    /// `path` debe ser un C string UTF-8 válido o NULL. Devuelve NULL si no se puede leer.
    #[no_mangle]
    pub unsafe extern "C" fn eclipse_sha1_file(path: *const c_char) -> *mut c_char {
        read(path)
            .and_then(|p| super::core::sha1_file(p).ok())
            .map_or(ptr::null_mut(), give)
    }

    /// # Safety
    /// `s` debe venir de una función `eclipse_*` de esta librería (o ser NULL).
    #[no_mangle]
    pub unsafe extern "C" fn eclipse_free_string(s: *mut c_char) {
        if !s.is_null() {
            drop(CString::from_raw(s));
        }
    }
}

#[cfg(target_os = "android")]
mod android {
    use jni::objects::{JClass, JString};
    use jni::sys::jstring;
    use jni::JNIEnv;
    use std::ptr;

    fn out(env: &mut JNIEnv, s: Option<String>) -> jstring {
        s.and_then(|s| env.new_string(s).ok())
            .map_or(ptr::null_mut(), |j| j.into_raw())
    }

    #[no_mangle]
    pub extern "system" fn Java_dev_eclipsecobblemon_launcher_nativecore_NativeCore_nativeOfflineUuid<'l>(
        mut env: JNIEnv<'l>,
        _class: JClass<'l>,
        name: JString<'l>,
    ) -> jstring {
        let name: Option<String> = env.get_string(&name).ok().map(Into::into);
        let r = name.map(|n| super::core::offline_uuid(&n));
        out(&mut env, r)
    }

    #[no_mangle]
    pub extern "system" fn Java_dev_eclipsecobblemon_launcher_nativecore_NativeCore_nativeSha1File<'l>(
        mut env: JNIEnv<'l>,
        _class: JClass<'l>,
        path: JString<'l>,
    ) -> jstring {
        let path: Option<String> = env.get_string(&path).ok().map(Into::into);
        let r = path.and_then(|p| super::core::sha1_file(p).ok());
        out(&mut env, r)
    }
}

#[cfg(test)]
mod tests {
    use super::core::*;

    #[test]
    fn offline_uuid_matches_java() {
        // UUID.nameUUIDFromBytes("OfflinePlayer:Notch".getBytes())
        assert_eq!(offline_uuid("Notch"), "b50ad385-829d-3141-a216-7e7d7539ba7f");
    }

    #[test]
    fn sha1_of_known_content() {
        let p = std::env::temp_dir().join("eclipse_core_sha1_test.txt");
        std::fs::write(&p, b"abc").unwrap();
        assert_eq!(sha1_file(&p).unwrap(), "a9993e364706816aba3e25717850c26c9cd0d89d");
        let _ = std::fs::remove_file(p);
    }
}
