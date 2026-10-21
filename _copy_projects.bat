@echo off
set OPTS=/E /MT:8 /NFL /NDL /NJH /R:1 /W:1

echo [C] ADVANCED F1
robocopy "C:\Users\mbarr\ADVANCED F1" "E:\PROYECTOS\ADVANCED F1" %OPTS%
echo [C] abyss
robocopy "C:\Users\mbarr\abyss" "E:\PROYECTOS\ABYSS DESCENT" %OPTS%
echo [C] echo-gravity
robocopy "C:\Users\mbarr\echo-gravity" "E:\PROYECTOS\ECHO GRAVITY" %OPTS%
echo [C] galaxihan
robocopy "C:\Users\mbarr\galaxihan" "E:\PROYECTOS\GALAXIHAN" %OPTS%
echo [C] juegos
robocopy "C:\Users\mbarr\juegos" "E:\PROYECTOS\JUEGOS STARLEGEND" %OPTS%
echo [C] nova-strike
robocopy "C:\Users\mbarr\nova-strike" "E:\PROYECTOS\NOVA STRIKE" %OPTS%
echo [C] clickandbuilds
robocopy "C:\Users\mbarr\clickandbuilds" "E:\PROYECTOS\CLICKANDBUILDS" %OPTS%
echo === C: COPIES DONE ===
