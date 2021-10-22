$dash = "-" * 40
$origPath = $env:Path
$temp = $env:RUNNER_TEMP

md $temp\msys64

# copy current msys2 to temp folder, needed to determine what files to include
# in zip file (only newer files)
xcopy C:\msys64 $temp\msys64 /s /q

$env:Path = "C:\msys64\mingw64\bin;C:\msys64\usr\bin;$origPath"

Write-Host "`n$dash pacman --noconfirm -Syyuu"
pacman.exe -Syyuu --noconfirm
taskkill /f /fi "MODULES eq msys-2.0.dll"

Write-Host "`n$dash pacman --noconfirm -Syuu (2nd pass)"
pacman.exe -Syuu  --noconfirm
taskkill /f /fi "MODULES eq msys-2.0.dll"

$pkgs = 'autoconf autogen automake-wrapper bison diffutils libtool m4 make patch texinfo texinfo-tex compression'

Write-Host "`n$dash Install MSYS2 $pkgs"
pacman.exe -S --noconfirm --needed --noprogressbar $pkgs.split(' ')

Write-Host "`n$dash Clean packages"
pacman.exe -Scc --noconfirm

$env:Path = $origPath
