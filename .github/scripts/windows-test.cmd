@echo off

rem Run the suites for one Windows row of .github/ci-matrix.tsv.
rem
rem Same entry point as windows-build.cmd: phpsdk-<crt>-<arch>.bat -t <this file>
rem supplies the compiler environment nmake expects.

if "%PHP_BACKPORTS_SERIES%"=="" goto missing_env
if "%PHP_BACKPORTS_SUITES%"=="" set "PHP_BACKPORTS_SUITES=tests/lang Zend/tests"

set NO_INTERACTION=1
set REPORT_EXIT_STATUS=1
set SKIP_IO_CAPTURE_TESTS=1

rem The runner image installs its own PHP. Keep a stray php.ini out of the tests.
set PHPRC=
set PHP_INI_SCAN_DIR=

rem -j arrived in run-tests.php with 7.2, so a legacy 5.x row runs serially.
set PARALLEL=-j%NUMBER_OF_PROCESSORS%
echo %PHP_BACKPORTS_SERIES% | findstr /b /c:"5." >nul && set PARALLEL=
if "%PARALLEL%"=="-j" set PARALLEL=

echo ::group::Tests
nmake test TESTS="%PARALLEL% -g FAIL,BORK,LEAK,XLEAK --no-progress -q --offline --show-diff %PHP_BACKPORTS_SUITES%"
if errorlevel 1 goto failed
echo ::endgroup::

exit /b 0

:missing_env
echo ERROR: PHP_BACKPORTS_SERIES must be set.
exit /b 1

:failed
echo ERROR: the test suite reported failures.
exit /b 1
