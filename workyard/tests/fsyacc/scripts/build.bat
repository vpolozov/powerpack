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
 
setlocal
set _ScriptHome=%~dp0%

if exist tdirs (
 for /f %%i in (tdirs) do ( 
  if exist %%i (
	pushd %%i
        echo **************************************************
        cd
        echo **************************************************
        call %_ScriptHome%\build.bat
	if ERRORLEVEL 1 goto Error
	popd
  )
 )
)

if NOT exist tdirs (
   if exist build.bat (
        call .\build.bat
	if ERRORLEVEL 1 goto Error
   ) 
)

echo Built fsharp ok.
:Ok
endlocal
exit /b 0

:Error
endlocal
exit /b %ERRORLEVEL%



