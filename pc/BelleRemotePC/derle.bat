@echo off
rem BelleRemote PC derleme (.NET Framework 4, 64 bit)
cd /d %~dp0
"%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe" /nologo /target:winexe /platform:x64 /optimize+ /unsafe /out:BelleRemotePC.exe /r:System.Security.dll Program.cs Oturum.cs Masaustu.cs Izleyici.cs Video.cs Dxgi.cs ..\..\apps\kutuphane\dil\Dil.cs /resource:dil\en.txt,en.txt
