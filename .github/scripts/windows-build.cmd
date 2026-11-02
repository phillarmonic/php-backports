@echo off

rem Build one Windows row of .github/ci-matrix.tsv.
rem
rem phpsdk-<crt>-<arch>.bat -s <toolset> -t <this file> starts this inside a
rem shell where cl, link, and nmake already resolve for that toolset, so the
rem checks below are confirming that the runner label told the truth about the
rem compiler the machine actually provides.

if "%PHP_BACKPORTS_CRT%"=="" goto missing_env
if "%PHP_BACKPORTS_ARCH%"=="" goto missing_env
if "%PHP_BACKPORTS_SERIES%"=="" goto missing_env

if "%PHP_BACKPORTS_SDK_DIR%"=="" set "PHP_BACKPORTS_SDK_DIR=C:\php-sdk"
if "%PHP_BACKPORTS_DEPS_DIR%"=="" set "PHP_BACKPORTS_DEPS_DIR=C:\deps"
if "%PHP_BACKPORTS_STABILITY%"=="" set "PHP_BACKPORTS_STABILITY=stable"

echo ::group::Toolchain
where cl >nul 2>nul
if errorlevel 1 goto no_compiler
cl 2>&1 | findstr /C:"Version"
echo PHP_SDK_VS=%PHP_SDK_VS% PHP_SDK_ARCH=%PHP_SDK_ARCH%
if /i not "%PHP_SDK_VS%"=="%PHP_BACKPORTS_CRT%" goto wrong_toolset
if /i not "%PHP_SDK_ARCH%"=="%PHP_BACKPORTS_ARCH%" goto wrong_arch
echo ::endgroup::

echo ::group::Dependencies
phpsdk_deps --update --no-backup --branch %PHP_BACKPORTS_SERIES% --stability %PHP_BACKPORTS_STABILITY% --crt %PHP_BACKPORTS_CRT% --deps "%PHP_BACKPORTS_DEPS_DIR%"
if errorlevel 1 goto failed
echo ::endgroup::

echo ::group::Configure
call buildconf.bat
if errorlevel 1 goto failed
call configure.bat --disable-all --enable-cli --with-php-build="%PHP_BACKPORTS_DEPS_DIR%"
if errorlevel 1 goto failed
echo ::endgroup::

echo ::group::Build
nmake /NOLOGO
if errorlevel 1 goto failed
echo ::endgroup::

exit /b 0

:missing_env
echo ERROR: PHP_BACKPORTS_CRT, PHP_BACKPORTS_ARCH, and PHP_BACKPORTS_SERIES must all be set.
exit /b 1

:no_compiler
echo ERROR: cl.exe does not resolve, so the SDK runner did not enter a Visual Studio environment.
exit /b 1

:wrong_toolset
echo ERROR: the matrix asked for %PHP_BACKPORTS_CRT% but this shell reports PHP_SDK_VS=%PHP_SDK_VS%.
echo Check this machine's runner labels against .github/ci-matrix.tsv.
exit /b 1

:wrong_arch
echo ERROR: the matrix asked for %PHP_BACKPORTS_ARCH% but this shell reports PHP_SDK_ARCH=%PHP_SDK_ARCH%.
exit /b 1

:failed
echo ERROR: a build step above failed.
exit /b 1
