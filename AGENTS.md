# AGENTS — Super Circuit GP

## Preferencias del usuario
- **NO PREGUNTES — HAZLO SIEMPRE.** Implementa los cambios directamente sin pedir
  confirmación ni aclaraciones. Si algo es ambiguo, elige la opción más razonable
  y ejecútala.
- El usuario se comunica en español. Toda UI visible nueva debe estar localizada
  en los diccionarios ES y EN (claves `T()`).
- Optimiza siempre las imágenes antes de usarlas (reescalar + JPEG progresivo ~82).

## Proyecto
- Juego de carreras Three.js en `index.html` (archivo único: CSS+JS inline).
- Circuitos trazados en `circuitos.js`; `trazar.html` = herramienta de trazado.
- `sw.js` = service worker network-first; bump de caché al tocar assets.
- **Versión**: `BUILD_NO` en `index.html` (~línea 3412) se muestra en el menú como
  `Ver.01-2026-0XXX`. **Sumar +1 por cada cambio entregado** (petición del usuario).

## Verificación
- Servidor de pruebas: `python -m http.server` o el ya activo en 127.0.0.1:52793.
- Tests con Playwright + Chrome del sistema: `p.chromium.launch(channel='chrome')`.
- Tras cambios: comprobar `pageerror`/console = 0 errores y captura visual.

## Build APK + sincronización (hacer tras CADA cambio verificado)
```bash
cp index.html sw.js "/d/Super Circuit GP/" 2>/dev/null
cp index.html sw.js "/e/GP SUPER CIRCUIT/" 2>/dev/null
cp index.html "android/app/src/main/assets/index.html"
cp sw.js "android/app/src/main/assets/sw.js"
cd android && JAVA_HOME="C:\Program Files\Android\Android Studio\jbr" \
  ./gradlew.bat assembleDebug --console=plain -q < /dev/null && cd ..
cp "android/app/build/outputs/apk/debug/app-debug.apk" "SuperCircuitGP-1.0.apk"
cp "SuperCircuitGP-1.0.apk" "/d/Super Circuit GP/"
cp "SuperCircuitGP-1.0.apk" "/e/GP SUPER CIRCUIT/"
```
