# Bir uygulamaya dil destegini baglar: .pro'ya dil.pri, main.cpp'ye Dil::kur + "dil" baglam ozelligi.
# Kullanim:  .\dil_kur.ps1 -Uygulama ..\BelleRehber
param([Parameter(Mandatory = $true)][string]$Uygulama)
$ErrorActionPreference = "Stop"
$kok = (Resolve-Path $Uygulama).Path
$utf8 = New-Object Text.UTF8Encoding($false)

$pro = Get-ChildItem $kok -Filter *.pro | Select-Object -First 1
$p = [IO.File]::ReadAllText($pro.FullName)
if ($p -notmatch 'kutuphane/dil/dil\.pri') {
    $p = $p.TrimEnd() + "`n`n# Dil destegi (Turkce / English): kutuphane/dil`ninclude(`$`$PWD/../kutuphane/dil/dil.pri)`n"
    [IO.File]::WriteAllText($pro.FullName, $p, $utf8)
    "pro: dil.pri eklendi"
}

$main = Join-Path $kok "main.cpp"
$m = [IO.File]::ReadAllText($main, [Text.Encoding]::UTF8)
if ($m -notmatch 'Dil::kur') {
    $app = [regex]::Match($m, 'Q(?:Core)?Application\s+(\w+)\s*\([^;]*\);[^\n]*\n')
    if (-not $app.Success) { throw "QApplication satiri bulunamadi" }
    $ad = $app.Groups[1].Value
    $m = $m.Insert($app.Index + $app.Length, "    Dil *dil = Dil::kur(&$ad);   // Turkce / English (QML'den once)`n")
    $src = [regex]::Match($m, '\n([ \t]*)(\w+)(\.|->)(setSource|setMainQmlFile)\(')
    if ($src.Success) {
        $girinti = $src.Groups[1].Value; $v = $src.Groups[2].Value; $ok = $src.Groups[3].Value
        $m = $m.Insert($src.Index + 1, "$girinti$v$($ok)rootContext()->setContextProperty(`"dil`", dil);`n")
    } else { "UYARI: setSource bulunamadi, 'dil' baglam ozelligini elle ekleyin" }
    $inc = [regex]::Match($m, '#include[^\n]*\n')
    $m = $m.Insert($inc.Index + $inc.Length, "#include `"dil.h`"`n")
    [IO.File]::WriteAllText($main, $m, $utf8)
    "main.cpp: Dil::kur eklendi"
}
