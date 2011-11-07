@ECHO OFF
IF %1.==. GOTO DefaultValue
SET profile=%1
GOTO DoWork

:DefaultValue
ECHO No build profile has been specified, will copy from Release.
SET profile=Release
GOTO DoWork

:DoWork
@ECHO On
mkdir ..\bin
mkdir ..\bin\locales

copy /Y ..\..\chromium\chromium\src\chrome\%profile%\avcodec-52.dll ..\bin\avcodec-52.dll
copy /Y ..\..\chromium\chromium\src\chrome\%profile%\avformat-52.dll ..\bin\avformat-52.dll
copy /Y ..\..\chromium\chromium\src\chrome\%profile%\avutil-50.dll ..\bin\avutil-50.dll
copy /Y ..\..\chromium\chromium\src\chrome\%profile%\icudt46.dll ..\bin\icudt46.dll
copy /Y ..\..\chromium\chromium\src\chrome\%profile%\libEGL.dll ..\bin\libEGL.dll
copy /Y ..\..\chromium\chromium\src\chrome\%profile%\libGLESv2.dll ..\bin\libGLESv2.dll
copy /Y ..\..\chromium\chromium\src\chrome\%profile%\locales\en-US.dll ..\bin\locales\en-US.dll
copy /Y ..\..\chromium\chromium\src\chrome\%profile%\resources.pak ..\bin\resources.pak
copy /Y ..\..\chromium\chromium\src\chrome\%profile%\wow_helper.exe ..\bin\wow_helper.exe