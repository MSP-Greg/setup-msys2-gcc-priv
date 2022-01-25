
$root = 'C:/msys64'

function DeleteDir($path) {
  if (Test-Path -Path $root/$path -PathType Container ) {
    Remove-Item -Path $root/$path -Recurse
  }
}

function DeleteFile($path) {
if (Test-Path -Path $root/$path -PathType Leaf ) {
  Remove-Item -Path $root/$path
}

$versions = @('2.71', '2.69', '3.13')

foreach ($version in $versions) {
  DeleteDir user/share/autoconf-$vers
}

$bins = @('autoconf', 'autoheader', 'autom4te', 'autoreconf', 'autoscan', 'autoupdate', 'ifnames')
foreach ($version in $versions) {
  foreach ($bin in $bins) {
    DeleteFile user/bin/$bin-$vers
  }
}


autoconf2.71: /usr/share/man/man1/autoconf-2.71.1.gz exists in filesystem
autoconf2.71: /usr/share/man/man1/autoheader-2.71.1.gz exists in filesystem
autoconf2.71: /usr/share/man/man1/autom4te-2.71.1.gz exists in filesystem
autoconf2.71: /usr/share/man/man1/autoreconf-2.71.1.gz exists in filesystem
autoconf2.71: /usr/share/man/man1/autoscan-2.71.1.gz exists in filesystem
autoconf2.71: /usr/share/man/man1/autoupdate-2.71.1.gz exists in filesystem
autoconf2.71: /usr/share/man/man1/ifnames-2.71.1.gz exists in filesystem