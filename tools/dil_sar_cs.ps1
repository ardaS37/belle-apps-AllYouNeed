# C# (PC uygulamalari) dosyalarindaki kullaniciya gorunen Turkce metinleri L.T("...") ile sarar.
# Kullanim: .\dil_sar_cs.ps1 -Dosyalar ..\E6Uzak\pc\Program.cs,... [-Uygula]
# const satirlari, case etiketleri, karsilastirmalar, @"..." ve $"..." dizeleri atlanir.
param([Parameter(Mandatory = $true)][string[]]$Dosyalar, [switch]$Uygula)
$ErrorActionPreference = "Stop"
$trHarf = '[çğışöüÇĞİŞÖÜ]'
function MetinMi([string]$s) {
    if ($s.Length -lt 2 -or $s -notmatch '[A-Za-zçğışöüÇĞİŞÖÜ]') { return $false }
    if ($s -match '://|^[/\\]|\.(exe|txt|ini|png|json|bin|dll|cs)$|^[\w\-\.]+=') { return $false }
    if ($s -cmatch $trHarf) { return $true }
    if ($s -match '\s' -and $s -match '[a-zA-Z]{3}') { return $true }
    if ($s -cmatch '^[A-ZÇĞİÖŞÜ][a-zçğışöü]{2,}') { return $true }
    return $false
}
$toplam = 0
foreach ($yol in $Dosyalar) {
    $f = (Resolve-Path $yol).Path
    $satirlar = [IO.File]::ReadAllText($f, [Text.Encoding]::UTF8) -split "`n", -1
    $blok = $false; $adet = 0
    for ($n = 0; $n -lt $satirlar.Count; $n++) {
        $line = $satirlar[$n]
        if ($line -match '^\s*(#|\[|using\b)' -or $line -match '\bconst\b' -or $line -match '^\s*case\b') { continue }
        $out = New-Object Text.StringBuilder; $i = 0
        while ($i -lt $line.Length) {
            $c = $line[$i]
            if ($blok) { if ($c -eq '*' -and $i + 1 -lt $line.Length -and $line[$i + 1] -eq '/') { $blok = $false; [void]$out.Append('*/'); $i += 2; continue }; [void]$out.Append($c); $i++; continue }
            if ($c -eq '/' -and $i + 1 -lt $line.Length -and $line[$i + 1] -eq '/') { [void]$out.Append($line.Substring($i)); break }
            if ($c -eq '/' -and $i + 1 -lt $line.Length -and $line[$i + 1] -eq '*') { $blok = $true; [void]$out.Append('/*'); $i += 2; continue }
            if ($c -eq "'") { $j = $i + 1; while ($j -lt $line.Length -and $line[$j] -ne "'") { if ($line[$j] -eq '\') { $j++ }; $j++ }; [void]$out.Append($line.Substring($i, [Math]::Min($j + 1, $line.Length) - $i)); $i = $j + 1; continue }
            if ($c -eq '@' -and $i + 1 -lt $line.Length -and $line[$i + 1] -eq '"') {
                $j = $i + 2; while ($j -lt $line.Length) { if ($line[$j] -eq '"') { if ($j + 1 -lt $line.Length -and $line[$j + 1] -eq '"') { $j += 2; continue }; break }; $j++ }
                [void]$out.Append($line.Substring($i, [Math]::Min($j + 1, $line.Length) - $i)); $i = $j + 1; continue
            }
            $interp = ($c -eq '$' -and $i + 1 -lt $line.Length -and $line[$i + 1] -eq '"')
            if ($interp) { [void]$out.Append('$'); $i++; $c = '"' }
            if ($c -ne '"') { [void]$out.Append($c); $i++; continue }
            $j = $i + 1
            while ($j -lt $line.Length -and $line[$j] -ne '"') { if ($line[$j] -eq '\') { $j++ }; $j++ }
            if ($j -ge $line.Length) { [void]$out.Append($line.Substring($i)); break }
            $ic = $line.Substring($i + 1, $j - $i - 1)
            $once = $out.ToString(); $sonra = $line.Substring($j + 1)
            $sar = (-not $interp) -and (MetinMi $ic)
            if ($sar -and ($once -match '(==|!=)\s*$' -or $sonra -match '^\s*(==|!=)')) { $sar = $false }
            if ($sar -and $once -match '(L\.T|Equals|StartsWith|EndsWith|IndexOf|Contains|Split|Replace|GetValue|SetValue|OpenSubKey|CreateSubKey|DeleteValue|GetManifestResourceStream|Combine|Start|Headers\[)\s*\(?\s*$') { $sar = $false }
            if ($sar) { [void]$out.Append('L.T("' + $ic + '")'); $adet++ } else { [void]$out.Append('"' + $ic + '"') }
            $i = $j + 1
        }
        $satirlar[$n] = $out.ToString()
    }
    $toplam += $adet
    "$([IO.Path]::GetFileName($f)): $adet"
    if ($Uygula -and $adet) { [IO.File]::WriteAllText($f, ($satirlar -join "`n"), (New-Object Text.UTF8Encoding($true))) }
}
"TOPLAM: $toplam (uygulandi: $([bool]$Uygula))"
