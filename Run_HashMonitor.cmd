@echo off
PowerShell -NoProfile -ExecutionPolicy Bypass -Command "& {Start-Process PowerShell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File ""%~DP0JJs_HashMonitor.ps1""' -Verb RunAs}"
