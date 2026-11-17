@echo off
rem Symbian^3 Qt 4.7.4 build environment (Qt SDK 1.2.1 default install path C:\QtSDK).
rem Usage: call tools\build_env.bat, then: qmake App.pro -r -spec symbian-sbsv2 "CONFIG+=release" ^&^& make release-gcce ^&^& make sis
set SDK=C:\QtSDK\Symbian\SDKs\Symbian3Qt474
set EPOCROOT=C:\QtSDK\Symbian\SDKs\Symbian3Qt474\
set QTDIR=C:\QtSDK\Symbian\SDKs\Symbian3Qt474\
set QT_GCCE_VERSION=4.4.1
set SBS=C:\QtSDK\Symbian\tools\sbs\bin\sbs.bat
set SBS_HOME=C:\QtSDK\Symbian\tools\sbs
set SBS_GCCE441BIN=C:\QtSDK\Symbian\tools\gcce4\bin
set SBS_PYTHON=C:\QtSDK\Symbian\tools\sbs\win32\python27\python.exe
set SBS_CYGWIN_TMP=%TEMP%
set PATH=C:\QtSDK\Symbian\tools\sbs\win32\mingw\bin;C:\QtSDK\Symbian\tools\sbs\win32\cygwin\bin;C:\QtSDK\Symbian\tools\sbs\win32\bin;C:\QtSDK\Symbian\tools\gcce4\bin;C:\QtSDK\Symbian\tools\sbs\bin;C:\QtSDK\Symbian\tools\perl\bin;%SDK%\epoc32\gcc\bin;%SDK%\epoc32\tools;%SDK%\lib;%SDK%\bin;C:\Windows\system32;C:\Windows