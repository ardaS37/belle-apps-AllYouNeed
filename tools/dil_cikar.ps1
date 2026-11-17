# Uygulamadaki cevrilecek metinleri toplar (QML/JS: qsTr, QT_TR_NOOP; C++: Dil::t) ve ana sozlukten
# (kutuphane/dil/sozluk_en.txt) uygulamanin dil/en.txt dosyasini uretir. Sozlukte olmayanlar raporlanir.
# Kullanim:  .\dil_cikar.ps1 -Uygulama ..\WhatsE6 [-EksikDosya eksik.txt]
param([Parameter(Mandatory = $true)][string]$Uygulama, [string]$EksikDosya = "")

$ErrorActionPreference = "Stop"
$kok = (Resolve-Path $Uygulama).Path
# Ana sozluk: kutuphane/dil/sozluk/*.txt, her satir "Turkce ¦ English" (ayirac tam olarak " ¦ ";
# metinlerin bastaki/sondaki bosluklari korunur). Bos satir ve # ile baslayan satir atlanir.
$sozlukKlasor = Join-Path $PSScriptRoot "..\apps\kutuphane\dil\sozluk"
$utf8 = New-Object Text.UTF8Encoding($false)

$sozluk = @{}
$ayirac = " " + [char]0x00A6 + " "
foreach ($sf in (Get-ChildItem $sozlukKlasor -Filter *.txt -ErrorAction SilentlyContinue)) {
    foreach ($s in [IO.File]::ReadAllLines($sf.FullName, [Text.Encoding]::UTF8)) {
        if ($s -eq "" -or $s.StartsWith("#")) { continue }
        $k = $s.IndexOf($ayirac); if ($k -lt 0) { continue }
        $sozluk[$s.Substring(0, $k)] = $s.Substring($k + $ayirac.Length)
    }
}

$metinler = New-Object System.Collections.Generic.HashSet[string]
$rx = '(?:qsTr|QT_TR_NOOP|Dil::t|L\.T)\s*\(\s*"((?:[^"\\]|\\.)*)"'
Get-ChildItem $kok -Recurse -File -Include *.qml, *.js, *.cpp, *.h, *.cs | Where-Object { $_.FullName -notmatch '\\(build|release|debug)\\' } | ForEach-Object {
    $t = ([IO.File]::ReadAllLines($_.FullName, [Text.Encoding]::UTF8) | Where-Object { $_ -notmatch '^\s*(//|#|\*)' }) -join "`n"
    foreach ($m in [regex]::Matches($t, $rx)) { [void]$metinler.Add($m.Groups[1].Value) }
}
# ortak kutuphanedeki (harita vb.) metinler de uygulamaya gerekebilir: .pro'daki include'lar
$pro = Get-ChildItem $kok -Filter *.pro | Select-Object -First 1
if ($pro) {
    foreach ($m in [regex]::Matches([IO.File]::ReadAllText($pro.FullName), 'kutuphane/(\w+)/')) {
        $lib = Join-Path $PSScriptRoot "..\apps\kutuphane\$($m.Groups[1].Value)"
        if (Test-Path $lib) {
            Get-ChildItem $lib -Recurse -File -Include *.qml, *.js, *.cpp, *.h | ForEach-Object {
                $t = ([IO.File]::ReadAllLines($_.FullName, [Text.Encoding]::UTF8) | Where-Object { $_ -notmatch '^\s*(//|#|\*)' }) -join "`n"
                foreach ($mm in [regex]::Matches($t, $rx)) { [void]$metinler.Add($mm.Groups[1].Value) }
            }
        }
    }
}

$satirlar = New-Object System.Collections.Generic.List[string]
$eksik = New-Object System.Collections.Generic.List[string]
foreach ($m in ($metinler | Sort-Object)) {
    if ($sozluk.ContainsKey($m)) { $satirlar.Add("$m`t$($sozluk[$m])") } else { $eksik.Add($m) }
}
$dilKlasor = Join-Path $kok "dil"
New-Item -ItemType Directory -Force $dilKlasor | Out-Null
[IO.File]::WriteAllText((Join-Path $dilKlasor "en.txt"), "# $((Split-Path $kok -Leaf)) - English (araclar/dil_cikar.ps1 ile uretilir, elle duzenlemeyin)`n" + ($satirlar -join "`n") + "`n", $utf8)
# Ayarlar icin hazir "Dil / Language" satiri: qrc:/qml/DilSatiri.qml (main.qml ile ayni klasorde gorunur)
Copy-Item (Join-Path $PSScriptRoot "..\apps\kutuphane\dil\DilSatiri.qml") (Join-Path $dilKlasor "DilSatiri.qml") -Force
[IO.File]::WriteAllText((Join-Path $dilKlasor "dil.qrc"), "<RCC>`n    <qresource prefix=`"/dil`">`n        <file>en.txt</file>`n    </qresource>`n    <qresource prefix=`"/qml`">`n        <file>DilSatiri.qml</file>`n    </qresource>`n</RCC>`n", $utf8)
if ($EksikDosya) { [IO.File]::WriteAllText($EksikDosya, ($eksik -join "`n") + "`n", $utf8) }
"$((Split-Path $kok -Leaf)): $($metinler.Count) metin, $($satirlar.Count) cevrili, $($eksik.Count) eksik"
