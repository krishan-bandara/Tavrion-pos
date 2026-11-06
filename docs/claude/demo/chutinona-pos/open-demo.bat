@echo off
rem Opens the demo in Edge. --kiosk-printing sends the receipt straight to the DEFAULT printer without a dialog.
rem Remove --kiosk-printing if you want to see the print dialog / preview first.
start "" msedge --kiosk-printing --app="file:///%~dp0index.html"
