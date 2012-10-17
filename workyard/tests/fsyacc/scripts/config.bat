@if "%_echo%"=="" echo off
REM ----------------------------------------------------------------------------
REM
REM Copyright (c) 2002-2011 Microsoft Corporation. 
REM
REM This source code is subject to terms and conditions of the Apache License, Version 2.0. A 
REM copy of the license can be found in the License.html file at the root of this distribution. 
REM By using this source code in any fashion, you are agreeing to be bound 
REM by the terms of the Apache License, Version 2.0.
REM
REM You must not remove this notice, or any other, from this software.
REM ----------------------------------------------------------------------------

set _SCRIPT_DRIVE=%~d0
set _SCRIPT_PATH=%~p0
set SCRIPT_ROOT=%_SCRIPT_DRIVE%%_SCRIPT_PATH%

if not defined FSHARP_HOME set FSHARP_HOME=%SCRIPT_ROOT%..\..\..\..

for /f %%i in ("%FSHARP_HOME%") do set FSHARP_HOME=%%~fi

REM Do we know where fsc.exe is?
 IF     DEFINED FSCBinPath goto :FSCBinPathFound
 IF NOT DEFINED FSC        goto :FSCBinPathFound
 call :WHEREIS "%FSC%" 
 IF NOT ERRORLEVEL 1 set FSCBinPath=%WHEREIS%
:FSCBinPathFound

REM else, let's first assume that this is (like) a desktop box
if not defined BUILD_CONFIG_TO_RUN set BUILD_CONFIG_TO_RUN=Retail

if not defined FSCBinPath set FSCBinPath=%FSHARP_HOME%\%BUILD_CONFIG_TO_RUN%\bin

if not exist "%FSCBinPath%\fsc.exe" echo %FSCBinPath%\fsc.exe not found. Assume that this is a lab QA run machine, with product installed.
if not exist "%FSCBinPath%\fsc.exe" call :GetFSCBinPath
 
if not exist "%FSCBinPath%\fsc.exe" echo %FSCBinPath%\fsc.exe still not found. Assume that user has added it to path somewhere

REM strip extra file separators and make short-name in case the the location is "Program Files" (how i hate spaces in file names!)
if defined FSCBinPath for /f "delims=" %%l in ("%FSCBinPath%") do set FSCBinPath=%%~fsl

REM add %FSCBinPath% to path only if not already there. Otherwise, the path keeps growing.
echo %path%; | find /i "%FSCBinPath%;" > NUL
if ERRORLEVEL 1    set PATH=%PATH%;%FSCBinPath%

if not defined CAMLROOT set CAMLROOT=%FSHARP_HOME%\tools\win86\ocaml

if not defined CAMLLIB set CAMLLIB=%CAMLROOT%\lib

echo %path%; | find /i "%CAMLROOT%\bin;" > NUL
if ERRORLEVEL 1    set PATH=%PATH%;%CAMLROOT%\bin

if "%OCAMLC%"==""   set OCAMLC=%CAMLROOT%\ocamlc
if "%OCAMLOPT%"=="" set OCAMLOPT=%CAMLROOT%\bin\ocamlopt
if "%OCAMLRUN%"=="" set OCAMLRUN=%CAMLROOT%\bin\ocamlrun

if not defined ILX_HOME   set ILX_HOME=%FSHARP_HOME%
if not defined ABSIL_HOME set ABSIL_HOME=%FSHARP_HOME%

if "%FSDIFF%"=="" set FSDIFF=%FSHARP_HOME%\tools\win86\diff.exe -dew

if "%FXCOPCMD%"=="" set FXCOPCMD=%FSHARP_HOME%\tools\win86\fxcop-1.36\fxcopcmd.exe

rem check if we're already configured, if not use the configuration from the last line of the config file
if "%fsc%"=="" ( 
 if exist "%FSHARP_HOME%\setup\installed-ilx-configs" (
  for /f "tokens=1,2,3,4,5,6 delims=," %%i in (%FSHARP_HOME%\setup\installed-ilx-configs) do ( 
   if NOT "%%i"== "#" (
     echo Considering ILX config %%k with compiler %%l.exe
     set csc_flags=%%j
     set fsc_flags=%%k
     set fscroot=%%l
     set fsiroot=%%m
     set ILX_SUFFIX=%%n
    )
  )
 ) else (
   echo NOTE: Could not find %FSHARP_HOME%\setup\installed-ilx-configs
   echo NOTE: Script may fail, try "cd ..; make fsharp-core-layout" if you build on this machine
   echo compiler flags will default to empty.
   echo framework and sdk directories will be set to defaults
   set csc_flags=/nologo
   set fsc_flags=--define:NO_INSTALLED_ILX_CONFIGS
   set fscroot=fsc
   set fsiroot=fsi
   set ILX_SUFFIX=
   IF defined RUNPERF set PERF=%FSHARP_HOME%\tools\perf\perf.exe %SCRIPT_ROOT%\fsharp\perf\perf.csv
 )
)

REM == Removed from inside the 'else' branch ==> broken on 64bit
REM == They will be set later on!
REM   set CORDIR=%SystemRoot%\Microsoft.NET\Framework\v2.0.50727\
REM   set CORSDK=%ProgramFiles%\Microsoft.NET\sdk\v2.0\bin\


if not defined ALINK  set ALINK=al.exe
if not defined CSC    set CSC=csc.exe %csc_flags%
if not defined CORDBG set CORDBG=cordbg.exe

REM SDK Dependencires.
if not defined ILDASM   set ILDASM=ildasm.exe
if not defined PEVERIFY set PEVERIFY=peverify.exe
if not defined RESGEN   set RESGEN=resgen.exe

if "%fscroot%" == "" ( set fscroot=fsc)
if "%fsiroot%" == "" ( set fscroot=fsi)


REM ---------------------------------------------------------------
:SETOSVER
set ISVISTAORLATER=1
ver | findstr -C:" 5.0" && set ISVISTAORLATER=0 
ver | findstr -C:" 5.1" && set ISVISTAORLATER=0 
ver | findstr -C:" 5.2" && set ISVISTAORLATER=0
:DoneOSVER

REM ---------------------------------------------------------------
 REM If we set a "--cli-version" flag anywhere in the flags then assume its v1.x
 REM and generate a config file, so we end up running the test on the right version
 REM of the CLR.  Also modify the CORSDK used.
 REM
 REM Use CLR 1.1 at a minimum since 1.0 is not installed on most of my machines

 REM don't keep repeating if already set 
 IF DEFINED config_cli_v2_0 goto :DoneCORDIR

 REM otherwise assume v2.0
 REM TODO: we need to update this to be v2.0 or v3.5 and nothing else.
 set config_cli_v2_0=true
 set fsc_flags=%fsc_flags% 

 set CSC_GENERATES_V2=true
 set CLR_SUPPORTS_GENERICS=true
 set ILDASM=%ILDASM%
 set CLR_SUPPORTS_WINFORMS=true
 set CLR_SUPPORTS_SYSTEM_WEB=true
 set SSCLI=false

:DoneCORVER

 REM ==
 REM == Find the CORDIR (path to .Net Framework 2.0)
 REM == and CORSDK (path to .Net SDK)
 REM ==

 REM ==
 REM == F# v1.0 targets NetFx3.5 (i.e. NDP2.0)
 REM == It is ok to hardcode the location, since this is not going to
 REM == change ever. Well, if/when we target a different runtime we'll have
 REM == to come and update this, but for now we MUST make sure we use the 2.0 stuff.
 REM ==
 REM == If we run on a 64bit machine (from a 64bit command prompt!), we use the 64bit
 REM == CLR, but tweaking 'Framework' to 'Framework64'.
 REM ==
 set CORDIR=%SystemRoot%\Microsoft.NET\Framework\v2.0.50727\

 REM == Let's see if NDP4.0 is also installed; if so, we use it instead.
 REM == If this machine has both VS2008 and DEV10, the only way to target VS2008
 REM == is to set the env var TARGETFSHARP to VS2008. Otherwise, the default is
 REM == to target DEV10
 set CORDIR40=
 FOR /D %%i IN (%windir%\Microsoft.NET\Framework\v4.0.?????) do set CORDIR40=%%i
 IF NOT "%CORDIR40%"=="" IF /I NOT "%TARGETFSHARP%"=="VS2008" set CORDIR=%CORDIR40%

 REM == Use the same runtime as our architecture
 REM == ASSUMPTION: This could be a good or bad thing.
 IF /I NOT "%PROCESSOR_ARCHITECTURE%"=="x86" set CORDIR=%CORDIR:Framework=Framework64%

 REM ==
 REM == Find out path to NDP SDK (on a standard F# v1.0 run, this should be one of:
 REM == - NDP2.0 SDK (NetFx2.0 SDK)
 REM == - WinSDK 6.0A (VS2008)
 REM == - WinSDK 6.1 (Vista WinSDK)
 REM == - WinSDK 7.0A (Dev10)
 REM == ==> we need to peverify against NET 2.0 (F# VS2008) or 4.0 (F# Dev10)
 REM ==
 REM == Try Windows SDK 6.x or 7.x
 @reg>NUL 2>&1 QUERY "HKLM\Software\Microsoft\Microsoft SDKs\Windows" /v CurrentInstallFolder
 IF ERRORLEVEL 1 goto :TryNDPSDK20

 set CORSDK=
 IF /I "%TARGETFSHARP%"=="DEV10"  FOR /F "tokens=2* delims=      " %%A IN ('reg QUERY "HKLM\Software\Microsoft\Microsoft SDKs\Windows\v7.0A\WinSDK-NetFx40Tools" /v InstallationFolder') DO SET CORSDK=%%B
 IF /I "%TARGETFSHARP%"=="VS2008" FOR /F "tokens=2* delims=      " %%A IN ('reg QUERY "HKLM\Software\Microsoft\Microsoft SDKs\Windows\v6.0A\WinSDKNetFxTools"    /v InstallationFolder') DO SET CORSDK=%%BBin
 
 REM == If TARGETFSHARP was not defined (a do-it-yourself-dev-run), default to something that seems reasonable
 REM == Also, if NDP4.0 is installed, check and see if "NETFX 4.0 Tools" are installed: if we find them, it is out preferred choice
 REM == This is just a best guess on what the user wants to do... 
 IF "%CORSDK%"=="" FOR /F "tokens=2*" %%A IN ('reg QUERY "HKLM\Software\Microsoft\Microsoft SDKs\Windows" /v CurrentInstallFolder') DO SET CORSDK=%%BBin
 IF NOT "%CORDIR40%"=="" IF EXIST "%CORSDK%\NETFX 4.0 Tools" set CORSDK=%CORSDK%\NETFX 4.0 Tools

 REM == Fix up CORSDK for 64bit platforms...
 IF /I "%PROCESSOR_ARCHITECTURE%"=="AMD64" SET CORSDK=%CORSDK%\x64
 IF /I "%PROCESSOR_ARCHITECTURE%"=="IA64"  SET CORSDK=%CORSDK%\IA64
 goto :DoneCORSDK

 REM == Try NDP2.0 SDK
:TryNDPSDK20
 @reg>NUL 2>&1 QUERY "HKLM\Software\Microsoft\.NETFramework" /v sdkInstallRootv2.0
 IF NOT ERRORLEVEL 0 @echo NDPSDK Not Found!&&goto :TryNDPSDK20
 FOR /F "tokens=2*" %%A IN ('reg QUERY "HKLM\Software\Microsoft\.NETFramework" /v sdkInstallRootv2.0') DO SET CORSDK=%%BBin
 goto :DoneCORSDK

:DoneCORSDK
 echo %CORSDK%

 REM ==
 REM == Last minute patch up
 REM == We override some values we set above for some special cases
 REM == (MatteoT: I am not sure if this is really used or not, so I'm leaving it for now [7/5/2008])
 REM ==
 if NOT "%fsc_flags:--sscli=X%" == "%fsc_flags%" (
     set CLR_SUPPORTS_WINFORMS=false
     set CLR_SUPPORTS_SYSTEM_WEB=false
     set CSC_GENERATES_V2=false
     set SSCLI=true
 )

:DoneCORDIR

REM add powerpack to flags only if not already there. Otherwise, the variable can keep growing.
echo %fsc_flags% | find /i "powerpack"
if ERRORLEVEL 1 set fsc_flags=%fsc_flags% -r:System.Core.dll --nowarn:20

if not defined fsi_flags set fsi_flags=%fsc_flags:--define:COMPILED=% --define:INTERACTIVE --maxerrors:1 --abortonerror
if not defined fsi_flags_erorrs_ok set fsi_flags_errors_ok=%fsc_flags:--define:COMPILED=% --define:INTERACTIVE

echo %fsc_flags%; | find "--define:COMPILED" > NUL || (
  set fsc_flags=%fsc_flags% --define:COMPILED
)

if "%SSCLI%"=="true" ( 
  if not defined CLIX (
     set fsc_flags=%fsc_flags% --sscli
     set CLIX=%CORDIR%\clix 
  )
)

if NOT "%fsc_flags:generate-config-file=X%"=="%fsc_flags%" ( 
  if NOT "%fsc_flags:clr-root=X%"=="%fsc_flags%" ( 
    set fsc_flags=%fsc_flags% --clr-root:%CORDIR%
  )
)


if "%CORDIR%"=="unknown" set CORDIR=

REM use short names in the path so you don't have to deal with the space in things like "Program Files"
for /f "delims=" %%I in ("%CORSDK%") do set CORSDK=%%~dfsI%
for /f "delims=" %%I in ("%CORDIR%") do set CORDIR=%%~dfsI%

set NGEN=

REM ==
REM == Set path to C# compiler. If we are NOT on NetFx4.0, try we prefer C# 3.5 to C# 2.0 
REM == This is because we have tests that reference System.Core.dll from C# code!
REM == (e.g. fsharp\core\fsfromcs)
REM ==
                        IF NOT "%CORDIR%"=="" IF EXIST "%CORDIR%\csc.exe"                                          SET CSC="%CORDIR%\csc.exe" %csc_flags%
IF     "%CORDIR40%"=="" IF NOT "%CORDIR%"=="" IF EXIST "%CORDIR%\..\V3.5\csc.exe"                                  SET CSC="%CORDIR%\..\v3.5\csc.exe" %csc_flags%
IF NOT "%CORDIR40%"=="" IF NOT "%CORDIR%"=="" IF EXIST "%CORDIR%\..\V3.5\csc.exe" IF /I "%TARGETFSHARP%"=="VS2008" SET CSC="%CORDIR%\..\v3.5\csc.exe" %csc_flags%

IF NOT "%CORDIR%"=="" IF EXIST "%CORDIR%\ngen.exe"            SET NGEN=%CORDIR%\ngen.exe
IF NOT "%CORDIR%"=="" IF EXIST "%CORDIR%\al.exe"              SET ALINK=%CORDIR%\al.exe

REM ==
REM == The logic here is: pick the latest msbuild
REM == If we are testing against NDP4.0, then don't try msbuild 3.5
REM ==
                        IF NOT "%CORDIR%"=="" IF EXIST "%CORDIR%\msbuild.exe"         SET MSBuildToolsPath=%CORDIR%
IF     "%CORDIR40%"=="" IF NOT "%CORDIR%"=="" IF EXIST "%CORDIR%\..\V3.5\msbuild.exe" SET MSBuildToolsPath="%CORDIR%\..\V3.5\"
IF NOT "%CORDIR40%"=="" IF NOT "%CORDIR%"=="" IF EXIST "%CORDIR%\..\V3.5\msbuild.exe" IF /I "%TARGETFSHARP%"=="VS2008" SET MSBuildToolsPath="%CORDIR%\..\V3.5\"

IF NOT "%CORDIR%"=="" FOR /f %%j IN ("%MSBuildToolsPath%") do SET MSBuildToolsPath=%%~fj

REM REM ==
REM REM == Add --cliversion option if needed.
REM REM == If we are running on NetFx3.5 (i.e. not on NetFx4.0) and --cliversion is not defined set --cliversion to 3.5
REM REM ==
REM   echo %fsc_flags% | find /i "cliversion"
REM   IF NOT ERRORLEVEL 1 goto :SkipCliVersion35a
REM   echo %fsc_flags% | find /i "Linq"
REM   if NOT ERRORLEVEL 1 IF "%CORDIR40%"=="" set fsc_flags=%fsc_flags% --cliversion:3.5
REM 
REM  :SkipCliVersion35a

IF NOT "%CORSDK%"=="" IF EXIST "%CORSDK%\ildasm.exe"          SET ILDASM=%CORSDK%\ildasm.exe
IF NOT "%CORSDK%"=="" IF EXIST "%CORSDK%\peverify.exe"        SET PEVERIFY=%CORSDK%\peverify.exe
IF NOT "%CORSDK%"=="" IF EXIST "%CORSDK%\resgen.exe"          SET RESGEN=%CORSDK%\resgen.exe
IF NOT "%CORSDK%"=="" IF EXIST "%CORSDK%\al.exe"              SET ALINK=%CORSDK%\al.exe
IF NOT "%CORSDK%"=="" IF EXIST "%CORSDK%\cordbg.exe"          SET CORDBG=%CORSDK%\cordbg.exe

IF NOT DEFINED FSC                                            SET FSC=%fscroot%.exe
IF NOT DEFINED FSI                                            SET FSI=%fsiroot%.exe
IF NOT DEFINED FSLEX                                          SET FSLEX=fslex.exe
IF NOT DEFINED FSYACC                                         SET FSYACC=fsyacc.exe

IF DEFINED FSCBinPath IF EXIST "%FSCBinPath%\%fscroot%.exe"   SET FSC=%FSCBinPath%\%fscroot%.exe
IF DEFINED FSCBinPath IF EXIST "%FSCBinPath%\%fsiroot%.exe"   SET FSI=%FSCBinPath%\%fsiroot%.exe
IF DEFINED FSCBinPath IF EXIST "%FSCBinPath%\fslex.exe"       SET FSLEX=%FSCBinPath%\fslex.exe
IF DEFINED FSCBinPath IF EXIST "%FSCBinPath%\fsyacc.exe"      SET FSYACC=%FSCBinPath%\fsyacc.exe

REM == In Dev10 (layout setup), FSharp.Core.dll is not sitting next to fsc.exe
REM == so we provide an alternative location to look for it. Automation will check
REM == this value (which may or may not be defined) and decide to use it.
set FSCOREDLLPATH=
IF /I "%TARGETFSHARP%"=="DEV10"  call :GetFSCOREDLLPath
IF EXIST "%FSCBinPath%\FSharp.Core%ILX_SUFFIX%.dll" set FSCOREDLLPATH=%FSCBinPath%
set FSCOREDLLPATH=%FSCOREDLLPATH%\FSharp.Core%ILX_SUFFIX%.dll

REM ---------------------------------------------------------------
if DEFINED _UNATTENDEDLOG exit /b 0

echo ---------------------------------------------------------------
echo Executables
echo 
echo NGEN                =%ngen%
echo FSC                 =%FSC%
echo FSI                 =%FSI%
echo fsc_flags           =%fsc_flags%
echo csc_flags           =%csc_flags%
echo fsi_flags           =%fsi_flags%
echo fsi_flags_errors_ok =%fsi_flags_errors_ok%
echo CORDIR              =%CORDIR%
echo CORSDK              =%CORSDK%
echo PEVERIFY            =%PEVERIFY%
echo RESGEN              =%RESGEN%
echo ALINK               =%ALINK%
echo MSBUILDTOOLSPATH    =%MSBuildToolsPath%
echo FSCBinPath          =%FSCBinPath%
echo CSC                 =%CSC%
echo CORDBG              =%CORDBG%
echo ILDASM              =%ILDASM%
echo FSDIFF              =%FSDIFF%
echo FXCOPCMD            =%FXCOPCMD%
echo PERF                =%PERF%
echo FSLEX               =%FSLEX%
echo FSYACC              =%FSYACC%
echo FSCOREDLLPATH       =%FSCOREDLLPATH% 
echo CLIX                =%CLIX% 
echo SSCLI               =%SSCLI% 
echo ---------------------------------------------------------------

exit /b 0

REM ===
REM === Find path to FSC/FSI looking up the registry REM === Will set the FSCBinPath env variable.
REM === Assumes an entry like Microsoft.FSharp-dd.dd.dd.dd REM === Works on both XP and Vista and hopefully everything else REM === Works on 32bit and 64 bit, no matter what cmd prompt it is invoked from REM === It checks all the possible FSharp installs/versions and picks up the REM === most recent.
REM === author: redmond\matteot
:GetFSCBinPath
   set /A VERSION_V1=0
   set /A VERSION_V2=0
   set /A VERSION_V3=0
   set /A VERSION_V4=0

   FOR /F %%f IN ('reg query HKLM\Software\Microsoft\.NetFramework\AssemblyFolders ^| findstr -i Microsoft.FSharp') DO call :CalcMaxVersion %%f
   REM == Key exists? Maybe we are on a 64bit box

   reg>NUL query HKLM\Software\Microsoft\.NetFramework\AssemblyFolders\Microsoft.FSharp-%VERSION_V1%.%VERSION_V2%.%VERSION_V3%.%VERSION_V4%
   IF ERRORLEVEL 1 goto :Try64bit
   FOR /F "tokens=1-2*" %%a IN ('reg query HKLM\Software\Microsoft\.NetFramework\AssemblyFolders\Microsoft.FSharp-%VERSION_V1%.%VERSION_V2%.%VERSION_V3%.%VERSION_V4% /ve') DO set FSCBinPath=%%c
   IF "%FSCBinPath%"=="" FOR /F "tokens=1-3*" %%a IN ('reg query HKLM\Software\Microsoft\.NetFramework\AssemblyFolders\Microsoft.FSharp-%VERSION_V1%.%VERSION_V2%.%VERSION_V3%.%VERSION_V4% /ve') DO set FSCBinPath=%%d
   goto :EOF

:Try64bit
   FOR /F %%f IN ('reg query HKLM\Software\Wow6432Node\Microsoft\.NetFramework\AssemblyFolders ^| findstr -i Microsoft.FSharp') DO call :CalcMaxVersion %%f
   FOR /F "tokens=1-2*" %%a IN ('reg query HKLM\Software\Wow6432Node\Microsoft\.NetFramework\AssemblyFolders\Microsoft.FSharp-%VERSION_V1%.%VERSION_V2%.%VERSION_V3%.%VERSION_V4% /ve') DO set FSCBinPath=%%c
   IF "%FSCBinPath%"=="" FOR /F "tokens=1-3*" %%a IN ('reg query HKLM\Software\Wow6432Node\Microsoft\.NetFramework\AssemblyFolders\Microsoft.FSharp-%VERSION_V1%.%VERSION_V2%.%VERSION_V3%.%VERSION_V4% /ve') DO set FSCBinPath=%%d
   goto :EOF

:CalcMaxVersion
     FOR /F "tokens=1-6 delims=-." %%a IN ("%~nx1") DO (
       IF %%c LSS %VERSION_V1% goto :EOF
       IF %%c GTR %VERSION_V1% set VERSION_V1=%%c&&set VERSION_V2=%%d&&set VERSION_V3=%%e&&set VERSION_V4=%%f&&goto :EOF

       IF %%d LSS %VERSION_V2% goto :EOF
       IF %%d GTR %VERSION_V2% set set VERSION_V2=%%d&&set VERSION_V3=%%e&&set VERSION_V4=%%f&&goto :EOF

       IF %%e LSS %VERSION_V3% goto :EOF
       IF %%e GTR %VERSION_V3% set VERSION_V3=%%e&&set VERSION_V4=%%f&&goto :EOF
 
       IF %%f LSS %VERSION_V4% goto :EOF
       IF %%f GTR %VERSION_V4% set VERSION_V4=%%f&&goto :EOF
     )
   goto :EOF

REM ===
REM === Find path to FSharp.Core.dll (in Dev10, this is under Reference Assemblies\Microsoft\FSharp\2.0\Runtime\v4.0)
REM === author: redmond\matteot
REM ===
:GetFSCOREDLLPath

    REM == Find out OS architecture, no matter what cmd prompt
    SET OSARCH=%PROCESSOR_ARCHITECTURE%
    IF NOT "%PROCESSOR_ARCHITEW6432%"=="" SET OSARCH=%PROCESSOR_ARCHITEW6432%

    REM == Find out path to native 'Program Files 32bit', no matter what
    REM == architecture we are running on and no matter what command
    REM == prompt we came from.
    IF /I "%OSARCH%"=="x86"   set X86_PROGRAMFILES=%ProgramFiles%
    IF /I "%OSARCH%"=="IA64"  set X86_PROGRAMFILES=%ProgramFiles(x86)%
    IF /I "%OSARCH%"=="AMD64" set X86_PROGRAMFILES=%ProgramFiles(x86)%

    REM == Set path to FSharp.Core.dll
    set FSCOREDLLPATH=%X86_PROGRAMFILES%\Reference Assemblies\Microsoft\FSharp\2.0\Runtime\v4.0
    
    goto :EOF  

REM ===
REM === Handly 'where' replacement (which is not available on XP - sigh)
REM === Set errorlevel to 0/1 if found/not_found
REM === Also set global env variable %WHEREIS% to the result
:WHEREIS
@IF EXIST %1 (@set WHEREIS=%CD%\%~nx1&&@EXIT /B 0)
@for /f "usebackq" %%f in ('%1') do @if "%%~$PATH:f"=="" (@set WHEREIS=&&@EXIT /B 1) else (@set WHEREIS=%%~$PATH:f&&@echo %%~$PATH:f&&@EXIT /B 0)
goto :EOF