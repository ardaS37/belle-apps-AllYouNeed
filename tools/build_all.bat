@echo off
rem Builds every Symbian app. Copy the "apps" folder to a short path first, e.g. C:\b, then run:  tools\build_all.bat C:\b
rem SIS files are collected in <path>\_sis. Log: <path>\_sis\build.log
setlocal
set ROOT=%~1
if "%ROOT%"=="" set ROOT=C:\b
call "%~dp0build_env.bat"
mkdir "%ROOT%\_sis" 2>nul
set LOG=%ROOT%\_sis\build.log
echo build %DATE% %TIME% > "%LOG%"
for %%A in (ApiLauncher BelleBrowser BelleFiles BelleMail BelleMaps BelleMiddleKey BelleRemote BelleTube BelleVideo BelleWidgets WhatsBelle) do (
  echo ===== %%A ===== >> "%LOG%"
  pushd "%ROOT%\%%A"
  qmake %%A.pro -r -spec symbian-sbsv2 "CONFIG+=release" >> "%LOG%" 2>&1
  make release-gcce >> "%LOG%" 2>&1
  make sis >> "%LOG%" 2>&1
  copy /Y *.sis "%ROOT%\_sis\" >> "%LOG%" 2>&1
  popd
)
echo done >> "%LOG%"