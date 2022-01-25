
$root = 'C:/msys64'

function DeleteDir($path) {
  $del = "$root/$path"
  if (Test-Path -Path $del -PathType Container ) {
    Remove-Item -Path $del -Recurse
    Write-Host "Removed dir  $del"
  } else {
    Write-Host "dir  doesn't exist $del"
  }
}

function DeleteFile($path) {
  $del = "$root/$path"
  if (Test-Path -Path $del -PathType Leaf ) {
    Remove-Item -Path $del
    Write-Host "Removed file $del"
  } else {
    Write-Host "file doesn't exist $del"
  }
}

$versions = @('2.71', '2.69', '2.13')

$bins = @('autoconf', 'autoheader', 'autom4te', 'autoreconf', 'autoscan', 'autoupdate', 'ifnames')
foreach ($version in $versions) {
  DeleteDir "usr/share/autoconf-$version"
  foreach ($bin in $bins) {
    DeleteFile "usr/bin/$bin-$version"
  }
  DeleteFile "/usr/share/licenses/autoconf$version/COPYING.EXCEPTION"
}

$versions = @('2.71.1', '2.69.1')
foreach ($version in $versions) {
  foreach ($bin in $bins) {
    DeleteFile "usr/share/man/man1/$bin-$version.gz"
  }  foreach ($bin in $bins) {
    DeleteFile "usr/share/man/man1/$bin-$version.gz"
  }
}

DeleteFile "usr/share/info/autoconf2.13.info.gz"
DeleteFile "usr/share/licenses/autoconf2.13/COPYING"

DeleteFile "usr/share/man/man1/config.guess-2.69.1.gz"
DeleteFile "usr/share/man/man1/config.sub-2.69.1.gz"
