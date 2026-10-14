@echo off
REM ============================================================
REM  Super Circuit GP - Compila la APK con la version actual del juego
REM  Doble clic y listo: genera SuperCircuitGP-X.Y.apk en esta carpeta
REM ============================================================
setlocal
cd /d "%~dp0"

echo [1/3] Copiando el juego a los assets de Android...
copy /y "index.html" "android\app\src\main\assets\index.html" >nul
copy /y "three.min.js" "android\app\src\main\assets\three.min.js" >nul
copy /y "peerjs.min.js" "android\app\src\main\assets\peerjs.min.js" >nul
copy /y "f1.png" "android\app\src\main\assets\f1.png" >nul
copy /y "f1sel.png" "android\app\src\main\assets\f1sel.png" >nul
if exist "f1_*.png" copy /y "f1_*.png" "android\app\src\main\assets\" >nul
if exist "fondo_pw.jpg" copy /y "fondo_pw.jpg" "android\app\src\main\assets\fondo_pw.jpg" >nul
if exist "fondo_card.jpg" copy /y "fondo_card.jpg" "android\app\src\main\assets\fondo_card.jpg" >nul
if exist "volante.png" copy /y "volante.png" "android\app\src\main\assets\volante.png" >nul
copy /y "portada.jpg" "android\app\src\main\assets\portada.jpg" >nul
copy /y "fondo.jpg" "android\app\src\main\assets\fondo.jpg" >nul
if exist "fondo2.jpg" copy /y "fondo2.jpg" "android\app\src\main\assets\fondo2.jpg" >nul
if exist "manifest.json" copy /y "manifest.json" "android\app\src\main\assets\manifest.json" >nul
if exist "sw.js" copy /y "sw.js" "android\app\src\main\assets\sw.js" >nul
if exist "icon-*.png" copy /y "icon-*.png" "android\app\src\main\assets\" >nul
if exist "track1.js" copy /y "track1.js" "android\app\src\main\assets\track1.js" >nul
if exist "circuitos.js" copy /y "circuitos.js" "android\app\src\main\assets\circuitos.js" >nul
if exist "circuito*.jpg" copy /y "circuito*.jpg" "android\app\src\main\assets\" >nul
if exist "*.mp3" copy /y "*.mp3" "android\app\src\main\assets\" >nul
copy /y "trazar.html" "android\app\src\main\assets\trazar.html" >nul
if exist "gltfloader.js" copy /y "gltfloader.js" "android\app\src\main\assets\gltfloader.js" >nul
if exist "r26.glb" copy /y "r26.glb" "android\app\src\main\assets\r26.glb" >nul
if exist "tex_r26" xcopy /y /e /i "tex_r26" "android\app\src\main\assets\tex_r26" >nul

echo [2/3] Compilando con Gradle...
cd /d "%~dp0android"
set "JAVA_HOME=C:\Program Files\Android\Android Studio\jbr"
call "%~dp0android\gradlew.bat" assembleDebug --console=plain -q
if errorlevel 1 (
    echo.
    echo *** ERROR: la compilacion fallo. Revisa los mensajes de arriba. ***
    pause
    exit /b 1
)
cd /d "%~dp0"

REM Lee la version de build.gradle.kts (versionName = "X.Y")
set "APKVER="
for /f tokens^=2^ delims^=^" %%V in ('findstr /c:"versionName" "android\app\build.gradle.kts"') do set "APKVER=%%V"
if "%APKVER%"=="" set "APKVER=0.0"
set "APKNAME=SuperCircuitGP-%APKVER%.apk"

echo [3/3] Copiando la APK como %APKNAME%...
copy /y "android\app\build\outputs\apk\debug\app-debug.apk" "%APKNAME%" >nul

echo.
echo *** LISTO: %APKNAME% generada correctamente ***
pause
