$dash = "-" * 40

pacman.exe -R --noconfirm --needed --noprogressbar autoconf2.71
pacman.exe -R --noconfirm --needed --noprogressbar autoconf2.69
pacman.exe -R --noconfirm --needed --noprogressbar autoconf2.13

Write-Host "`n$dash pacman --noconfirm -Syyuu"
pacman.exe -Syyuu --noconfirm
taskkill /f /fi "MODULES eq msys-2.0.dll"

Write-Host "`n$dash pacman --noconfirm -Syuu (2nd pass)"
pacman.exe -Syuu  --noconfirm
taskkill /f /fi "MODULES eq msys-2.0.dll"

$pkgs = 'autoconf-wrapper autogen automake-wrapper bison diffutils libtool m4 make patch texinfo texinfo-tex compression'

Write-Host "`n$dash Install MSYS2 $pkgs"
pacman.exe -S --noconfirm --needed --noprogressbar $pkgs.split(' ')

Write-Host "`n$dash Clean packages"
pacman.exe -Scc --noconfirm
