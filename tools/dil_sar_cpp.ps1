# C++ dosyalarinda kullaniciya gorunen QString::fromUtf8("Turkce metin") ifadelerini Dil::t("...") yapar
# ve dosyaya #include "dil.h" ekler. Gunluk (log/qDebug) satirlarina dokunmaz.
# Kullanim:  .\dil_sar_cpp.ps1 -Uygulama ..\BelleRehber [-Uygula]
param([Parameter(Mandatory = $true)][string]$Uygulama, [switch]$Uygula, [string[]]$Atla = @())

$ErrorActionPreference = "Stop"
$kok = (Resolve-Path $Uygulama).Path
$rx = [regex]'QString::fromUtf8\(\s*"((?:[^"\\]|\\.)*)"\s*\)'
$toplam = 0
foreach ($f in (Get-ChildItem $kok -Recurse -File -Include *.cpp | Where-Object { $_.FullName -notmatch '\\(build|release|debug)\\' -and ($Atla -notcontains $_.Name) })) {
    $metin = [IO.File]::ReadAllText($f.FullName, [Text.Encoding]::UTF8)
    $satirlar = $metin -split "`n", -1
    $adet = 0
    for ($n = 0; $n -lt $satirlar.Count; $n++) {
        $s = $satirlar[$n]
        if ($s -match '^\s*//' -or $s -match '\b(qDebug|qWarning|log|gunluk|Gunluk::yaz|kayit)\s*\(') { continue }
        $yeni = $rx.Replace($s, {
            param($m)
            $ic = $m.Groups[1].Value
            if ($ic -cmatch '[çğışöüÇĞİŞÖÜ…]' -or ($ic -match '\s' -and $ic -match '[A-Za-z]{2}')) { $script:adet++; return 'Dil::t("' + $ic + '")' }
            return $m.Value
        })
        $satirlar[$n] = $yeni
    }
    if ($adet -gt 0) {
        $toplam += $adet
        "$($f.Name): $adet"
        if ($Uygula) {
            $sonuc = $satirlar -join "`n"
            if ($sonuc -notmatch '#include\s+"dil\.h"') {
                # ilk #include satirindan sonra ekle
                $ilk = [regex]::Match($sonuc, '#include[^\n]*\n')
                $sonuc = $sonuc.Insert($ilk.Index + $ilk.Length, "#include `"dil.h`"`n")
            }
            [IO.File]::WriteAllText($f.FullName, $sonuc, (New-Object Text.UTF8Encoding($false)))
        }
    }
}
"TOPLAM: $toplam (uygulandi: $([bool]$Uygula))"
