@echo off

rem For scripting: call zimaos-usb-creator.exe and wait until it finishes.
rem This is necessary because the GUI executable does not block by default.

start /WAIT zimaos-usb-creator.exe --cli %*
