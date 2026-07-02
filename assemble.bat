@echo off
setlocal

powerpc-gekko-as.exe -mregnames lozce_persistent.asm -o lozce_persistent.o
if errorlevel 1 (
    echo Assembly failed.
    exit /b 1
)

powerpc-eabi-objcopy.exe -O binary lozce_persistent.o lozce_persistent.bin
if errorlevel 1 (
    echo objcopy failed.
    exit /b 1
)

echo GECKO CODE OUTPUT
echo =================

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$b = [IO.File]::ReadAllBytes('lozce_persistent.bin');" ^
  "if ($b.Length %% 4 -ne 0) { Write-Error 'Binary is not a multiple of 4 bytes'; exit 1 };" ^
  "$words = New-Object System.Collections.Generic.List[string];" ^
  "for ($i = 0; $i -lt $b.Length; $i += 4) { $words.Add(('{0:X2}{1:X2}{2:X2}{3:X2}' -f $b[$i], $b[$i+1], $b[$i+2], $b[$i+3])) };" ^
  "if ($words.Count %% 2 -eq 1) { $words.Add('00000000') };" ^
  "'C0000000 {0:X8}' -f ($words.Count / 2);" ^
  "for ($i = 0; $i -lt $words.Count; $i += 2) { '{0} {1}' -f $words[$i], $words[$i+1] }"

echo =================
echo.
echo Press any key to exit...

pause > nul

endlocal