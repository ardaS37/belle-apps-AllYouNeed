@echo off
rem E6Video arayuzunu VM'de qmlviewer ile acar (Z: = D:\WM\paylasim)
taskkill /f /im qmlviewer.exe > nul 2>&1
xcopy /E /Y /I Z:\E6Video C:\E6Video > nul
start "" C:\QtSDK\Desktop\Qt\4.7.4\mingw\bin\qmlviewer.exe -I Z:\qmltest Z:\qmltest\Harness.qml
