param (
    [Parameter(Mandatory=$true)][string]$version
)

$target="zerowallet-v$version"

Remove-Item -Path release/wininstaller -Recurse -ErrorAction Ignore  | Out-Null
New-Item release/wininstaller -itemtype directory                    | Out-Null

Copy-Item release/$target/zerowallet.exe     release/wininstaller/
Copy-Item release/$target/LICENSE           release/wininstaller/
Copy-Item release/$target/README.md         release/wininstaller/
Copy-Item release/$target/zerod.exe        release/wininstaller/
Copy-Item release/$target/zero-cli.exe     release/wininstaller/

Get-Content src/scripts/zero-qt-wallet.wxs | ForEach-Object { $_ -replace "RELEASE_VERSION", "$version" } | Out-File -Encoding utf8 release/wininstaller/zero-qt-wallet.wxs

candle.exe release/wininstaller/zero-qt-wallet.wxs -o release/wininstaller/zero-qt-wallet.wixobj 
if (!$?) {
    exit 1;
}

light.exe -ext WixUIExtension -cultures:en-us release/wininstaller/zero-qt-wallet.wixobj -out release/wininstaller/zerowallet.msi 
if (!$?) {
    exit 1;
}

New-Item artifacts -itemtype directory -Force | Out-Null
Copy-Item release/wininstaller/zerowallet.msi ./artifacts/Windows-installer-$target.msi