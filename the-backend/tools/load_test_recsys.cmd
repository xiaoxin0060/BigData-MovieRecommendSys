@echo off
setlocal
node "%~dp0load_test_recsys.js" %*
exit /b %ERRORLEVEL%

