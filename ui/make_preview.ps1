# Preview: six cut icons on dark navy cards (1:1) + zoomed corner insets.
# Usage: powershell.exe -NoProfile -ExecutionPolicy Bypass -File make_preview.ps1
param(
    [string]$IconDir = 'D:\demo\test01\balance\ui',
    [string]$OutFile = 'D:\demo\test01\balance\ui\preview.png'
)

Add-Type -AssemblyName System.Drawing

$names = @('button1.png','button2.png','button3.png','button4.png','button5.png','button6.png')
$labels = @('1 undo','2 history','3 settings','4 keypad','5 clear','6 mic')

$bgColor = [System.Drawing.Color]::FromArgb(255, 10, 14, 20)
$cellW = 360; $cellH = 360; $pad = 30
$W = $cellW * 3 + $pad * 4
$H = $cellH * 2 + $pad * 3

$bmp = New-Object System.Drawing.Bitmap($W, $H)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.Clear($bgColor)

$font = New-Object System.Drawing.Font('Consolas', 14)
$labelBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 180, 200, 220))
$sf = New-Object System.Drawing.StringFormat
$sf.Alignment = [System.Drawing.StringAlignment]::Center

for ($i = 0; $i -lt 6; $i++) {
    $col = $i % 3; $row = [Math]::Floor($i / 3)
    $x = $pad + $col * ($cellW + $pad)
    $y = $pad + $row * ($cellH + $pad)
    $icon = [System.Drawing.Bitmap]::FromFile((Join-Path $IconDir $names[$i]))
    $scale = [Math]::Min(0.62 * $cellW / $icon.Width, 0.62 * $cellH / $icon.Height)
    $dw = [int]($icon.Width * $scale); $dh = [int]($icon.Height * $scale)
    $ix = $x + ($cellW - $dw) / 2; $iy = $y + ($cellH - $dh) / 2
    $g.DrawImage($icon, $ix, $iy, $dw, $dh)
    $icon.Dispose()
    $labelRect = [System.Drawing.RectangleF]::new($x, $y + $cellH - 32, $cellW, 28)
    $g.DrawString($labels[$i], $font, $labelBrush, $labelRect, $sf)
}

$sf.Dispose(); $labelBrush.Dispose(); $font.Dispose()
$g.Dispose()
$bmp.Save($OutFile, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
Write-Output "preview saved: $OutFile"
