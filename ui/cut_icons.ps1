# Icon cutter v6: split button.png into 6 individual transparent PNGs.
# - transparent exterior: flood-fill bg from borders (tolerance 35)
# - keep ALL interior colors untouched (clock face / keys / gear hub are part of the art)
# - clean edges WITHOUT cream residue:
#     1) boundary alpha ramp (dist 35-160 -> alpha 0-255)
#     2) 1px min-erosion (drops the light pastel stroke ring)
#     3) 1x feather (box blur on alpha only)
#     4) CLEANUP: any partial-alpha pixel whose color is still near-cream
#        is zeroed -> no cream-tinted rim sticks to the icon on dark UIs
#        (this was the "background color sticking to the icon" artifact)
# - also exports the raw source crop to ui\source for reference
#
# NOTE: run with Windows PowerShell 5.1 (powershell.exe); keep file pure ASCII
#       (PS 5.1 reads BOM-less .ps1 as ANSI).
# Usage: powershell.exe -NoProfile -ExecutionPolicy Bypass -File cut_icons.ps1
param(
    [string]$Src       = 'D:\demo\test01\balance\ui\button.png',
    [string]$OutDir    = 'D:\demo\test01\balance\ui',
    [string]$AppOutDir = 'D:\demo\test01\balance\app\assets\icons',
    [string]$SrcOutDir = 'D:\demo\test01\balance\ui\source',
    [int]$Tolerance    = 35,
    [int]$Margin       = 8
)

Add-Type -AssemblyName System.Drawing

$cs = @'
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;

public static class IconCutter6
{
    private static int At(byte[] px, int stride, int x, int y) { return y * stride + x * 4; }

    private static bool IsBg(byte[] px, int stride, int bkr, int bkg, int bkb, int tol, int x, int y)
    {
        int i = At(px, stride, x, y);
        return Math.Abs((int)px[i] - bkr) <= tol &&
               Math.Abs((int)px[i + 1] - bkg) <= tol &&
               Math.Abs((int)px[i + 2] - bkb) <= tol;
    }

    private static void Push(Queue<int> q, bool[] visited, int cw, int x, int y)
    {
        int o = y * cw + x;
        if (visited[o]) return;
        visited[o] = true;
        q.Enqueue(o);
    }

    public static string[] Cut(string src, string outDir, string appOutDir, string srcOutDir, int tol, int margin, string[] names)
    {
        var results = new List<string>();
        Directory.CreateDirectory(outDir);
        Directory.CreateDirectory(appOutDir);
        Directory.CreateDirectory(srcOutDir);
        using (var bmp = new Bitmap(src))
        {
            int W = bmp.Width, H = bmp.Height;
            var rect = new Rectangle(0, 0, W, H);
            var data = bmp.LockBits(rect, ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
            int stride = data.Stride;
            var px = new byte[stride * H];
            Marshal.Copy(data.Scan0, px, 0, px.Length);
            bmp.UnlockBits(data);

            // bg reference color: mode of sampled points (corners may hold marks)
            var pts = new int[] {
                5 * stride + 5 * 4, (W - 6) * stride + 5 * 4, 5 * stride + (H - 6) * 4, (W - 6) * stride + (H - 6) * 4,
                (W / 2) * stride + 5 * 4, 5 * stride + (H / 2) * 4, (W - 6) * stride + (H / 2) * 4, (W / 2) * stride + (H - 6) * 4,
                100 * stride + 100 * 4, (W - 101) * stride + 100 * 4, 100 * stride + (H - 101) * 4, (W - 101) * stride + (H - 101) * 4
            };
            var hist = new Dictionary<long, int>();
            foreach (int p in pts)
            {
                long key = ((long)px[p] << 16) | ((long)px[p + 1] << 8) | px[p + 2];
                if (hist.ContainsKey(key)) hist[key]++; else hist[key] = 1;
            }
            long best = -1; int bestN = 0;
            foreach (var kv in hist) if (kv.Value > bestN) { bestN = kv.Value; best = kv.Key; }
            int br = ((int)(best >> 16)) & 255, bg = ((int)(best >> 8)) & 255, bb = ((int)best) & 255;

            // 1) connected components of non-bg pixels
            var visited = new bool[W * H];
            var comps = new List<int[]>();
            for (int y = 0; y < H; y++)
            {
                for (int x = 0; x < W; x++)
                {
                    int o = y * W + x;
                    if (visited[o] || IsBg(px, stride, br, bg, bb, tol, x, y)) continue;
                    var q = new Queue<int>();
                    q.Enqueue(o); visited[o] = true;
                    long area = 0;
                    int minX = x, maxX = x, minY = y, maxY = y;
                    while (q.Count > 0)
                    {
                        int p = q.Dequeue();
                        int cx = p % W, cy = p / W;
                        area++;
                        if (cx < minX) minX = cx; if (cx > maxX) maxX = cx;
                        if (cy < minY) minY = cy; if (cy > maxY) maxY = cy;
                        if (cx > 0 && !visited[p - 1] && !IsBg(px, stride, br, bg, bb, tol, cx - 1, cy)) { visited[p - 1] = true; q.Enqueue(p - 1); }
                        if (cx < W - 1 && !visited[p + 1] && !IsBg(px, stride, br, bg, bb, tol, cx + 1, cy)) { visited[p + 1] = true; q.Enqueue(p + 1); }
                        if (cy > 0 && !visited[p - W] && !IsBg(px, stride, br, bg, bb, tol, cx, cy - 1)) { visited[p - W] = true; q.Enqueue(p - W); }
                        if (cy < H - 1 && !visited[p + W] && !IsBg(px, stride, br, bg, bb, tol, cx, cy + 1)) { visited[p + W] = true; q.Enqueue(p + W); }
                    }
                    if (area >= 40) comps.Add(new int[] { (int)area, minX, maxX, minY, maxY });
                }
            }

            // 2) cluster components (absorb within 35px; < 43px gap between keypad & broom)
            var clusters = new List<int[]>();
            var used = new bool[comps.Count];
            for (int i = 0; i < comps.Count; i++)
            {
                if (used[i]) continue;
                int cminX = comps[i][1], cmaxX = comps[i][2], cminY = comps[i][3], cmaxY = comps[i][4];
                used[i] = true;
                bool grew = true;
                while (grew)
                {
                    grew = false;
                    for (int j = 0; j < comps.Count; j++)
                    {
                        if (used[j]) continue;
                        int e = 35;
                        if (comps[j][1] <= cmaxX + e && comps[j][2] >= cminX - e &&
                            comps[j][3] <= cmaxY + e && comps[j][4] >= cminY - e)
                        {
                            used[j] = true; grew = true;
                            if (comps[j][1] < cminX) cminX = comps[j][1];
                            if (comps[j][2] > cmaxX) cmaxX = comps[j][2];
                            if (comps[j][3] < cminY) cminY = comps[j][3];
                            if (comps[j][4] > cmaxY) cmaxY = comps[j][4];
                        }
                    }
                }
                clusters.Add(new int[] { cminX, cmaxX, cminY, cmaxY });
            }

            // 3) order row-major: split into top/bottom bands by centerY, sort each by centerX
            int midY = H / 2;
            var top = new List<int[]>(); var bottom = new List<int[]>();
            foreach (var cl in clusters)
            {
                int cy = (cl[2] + cl[3]) / 2;
                if (cy < midY) top.Add(cl); else bottom.Add(cl);
            }
            top.Sort(delegate(int[] a, int[] b) { return ((a[0] + a[1]) / 2).CompareTo((b[0] + b[1]) / 2); });
            bottom.Sort(delegate(int[] a, int[] b) { return ((a[0] + a[1]) / 2).CompareTo((b[0] + b[1]) / 2); });
            var ordered = new List<int[]>();
            ordered.AddRange(top); ordered.AddRange(bottom);

            results.Add("bg=" + br + "," + bg + "," + bb + " clusters=" + clusters.Count);
            int idx = 0;
            foreach (var cl in ordered)
            {
                int minX = Math.Max(0, cl[0] - margin), minY = Math.Max(0, cl[2] - margin);
                int maxX = Math.Min(W - 1, cl[1] + margin), maxY = Math.Min(H - 1, cl[3] + margin);
                int cw = maxX - minX + 1, ch = maxY - minY + 1;

                var outBmp = new Bitmap(cw, ch, PixelFormat.Format32bppArgb);
                var outData = outBmp.LockBits(new Rectangle(0, 0, cw, ch), ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
                int oStride = outData.Stride;
                var opx = new byte[oStride * ch];

                // 4) copy source crop into output buffer
                for (int y = 0; y < ch; y++)
                    for (int x = 0; x < cw; x++)
                    {
                        int si = At(px, stride, x + minX, y + minY);
                        int di = At(opx, oStride, x, y);
                        opx[di] = px[si]; opx[di + 1] = px[si + 1]; opx[di + 2] = px[si + 2]; opx[di + 3] = px[si + 3];
                    }

                // 5) save raw source crop (reference, cream bg kept)
                var rawBmp = new Bitmap(cw, ch, PixelFormat.Format32bppArgb);
                var rawData = rawBmp.LockBits(new Rectangle(0, 0, cw, ch), ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
                Marshal.Copy(opx, 0, rawData.Scan0, opx.Length);
                rawBmp.UnlockBits(rawData);
                string name = names.Length > idx ? names[idx] : ("icon_" + idx + ".png");
                rawBmp.Save(Path.Combine(srcOutDir, name), ImageFormat.Png);
                rawBmp.Dispose();

                // 6) flood fill bg from borders -> alpha 0
                var queue = new Queue<int>();
                var fill = new bool[cw * ch];
                for (int x = 0; x < cw; x++)
                {
                    if (IsBg(px, stride, br, bg, bb, tol, x + minX, minY)) Push(queue, fill, cw, x, 0);
                    if (IsBg(px, stride, br, bg, bb, tol, x + minX, maxY)) Push(queue, fill, cw, x, ch - 1);
                }
                for (int y = 0; y < ch; y++)
                {
                    if (IsBg(px, stride, br, bg, bb, tol, minX, y + minY)) Push(queue, fill, cw, 0, y);
                    if (IsBg(px, stride, br, bg, bb, tol, maxX, y + minY)) Push(queue, fill, cw, cw - 1, y);
                }
                while (queue.Count > 0)
                {
                    int o = queue.Dequeue();
                    int x = o % cw, y = o / cw;
                    opx[At(opx, oStride, x, y) + 3] = 0;
                    if (x > 0 && !fill[o - 1] && IsBg(px, stride, br, bg, bb, tol, x - 1 + minX, y + minY)) Push(queue, fill, cw, x - 1, y);
                    if (x < cw - 1 && !fill[o + 1] && IsBg(px, stride, br, bg, bb, tol, x + 1 + minX, y + minY)) Push(queue, fill, cw, x + 1, y);
                    if (y > 0 && !fill[o - cw] && IsBg(px, stride, br, bg, bb, tol, x + minX, y - 1 + minY)) Push(queue, fill, cw, x, y - 1);
                    if (y < ch - 1 && !fill[o + cw] && IsBg(px, stride, br, bg, bb, tol, x + minX, y + 1 + minY)) Push(queue, fill, cw, x, y + 1);
                }

                // 7) boundary alpha ramp: the icons' soft pastel stroke sits at dist
                //    35-90 from the cream bg; fade it so the light ring does not show
                //    as a halo on dark backgrounds. Colors untouched.
                //    NOTE: 8-neighbor adjacency - diagonal edges otherwise skip the
                //    ramp and stay fully opaque (later peeled by step 10 anyway).
                const int D0 = 35;
                const int D1 = 160;
                for (int y = 0; y < ch; y++)
                {
                    for (int x = 0; x < cw; x++)
                    {
                        int o = y * cw + x;
                        if (fill[o]) continue;
                        bool adjT = (x > 0 && fill[o - 1]) || (x < cw - 1 && fill[o + 1]) ||
                                    (y > 0 && fill[o - cw]) || (y < ch - 1 && fill[o + cw]) ||
                                    (x > 0 && y > 0 && fill[o - 1 - cw]) ||
                                    (x < cw - 1 && y > 0 && fill[o + 1 - cw]) ||
                                    (x > 0 && y < ch - 1 && fill[o - 1 + cw]) ||
                                    (x < cw - 1 && y < ch - 1 && fill[o + 1 + cw]);
                        if (!adjT) continue;
                        int s = At(opx, oStride, x, y);
                        int dR = Math.Abs((int)opx[s] - br), dG = Math.Abs((int)opx[s + 1] - bg), dB = Math.Abs((int)opx[s + 2] - bb);
                        int dist = Math.Max(dR, Math.Max(dG, dB));
                        if (dist <= D0) { opx[s + 3] = 0; continue; }
                        if (dist >= D1) continue;
                        double a = Math.Max(0.03, (double)(dist - D0) / (D1 - D0));
                        opx[s + 3] = (byte)(a * 255);
                    }
                }

                // 8) erode alpha (4-neighbor min, 1 pass): drops the faint stroke ring
                var aTmp = new byte[cw * ch];
                for (int o = 0; o < cw * ch; o++) aTmp[o] = opx[At(opx, oStride, o % cw, o / cw) + 3];
                for (int y = 0; y < ch; y++)
                {
                    for (int x = 0; x < cw; x++)
                    {
                        int o = y * cw + x;
                        int a = aTmp[o];
                        if (x > 0 && aTmp[o - 1] < a) a = aTmp[o - 1];
                        if (x < cw - 1 && aTmp[o + 1] < a) a = aTmp[o + 1];
                        if (y > 0 && aTmp[o - cw] < a) a = aTmp[o - cw];
                        if (y < ch - 1 && aTmp[o + cw] < a) a = aTmp[o + cw];
                        opx[At(opx, oStride, x, y) + 3] = (byte)a;
                    }
                }

                // 9) feather: 1x 3x3 box blur on alpha only
                for (int o = 0; o < cw * ch; o++) aTmp[o] = opx[At(opx, oStride, o % cw, o / cw) + 3];
                for (int y = 0; y < ch; y++)
                {
                    for (int x = 0; x < cw; x++)
                    {
                        int sum = 0, cnt = 0;
                        for (int dy = -1; dy <= 1; dy++)
                        {
                            int ny = y + dy;
                            if (ny < 0 || ny >= ch) continue;
                            for (int dx = -1; dx <= 1; dx++)
                            {
                                int nx = x + dx;
                                if (nx < 0 || nx >= cw) continue;
                                sum += aTmp[ny * cw + nx];
                                cnt++;
                            }
                        }
                        int na = sum / cnt;
                        if (na < 8) na = 0;
                        opx[At(opx, oStride, x, y) + 3] = (byte)na;
                    }
                }

                // 10) RIM DESPILL: iteratively zero EVERY pixel at the alpha
                //     boundary whose color is still near the cream background,
                //     including fully-opaque ones. The old single-pass cleanup
                //     only handled partial alpha, so the pale pastel ring
                //     (dist ~41-45 from bg, alpha 255) survived as a light halo
                //     on dark UIs. This peels inward until the boundary hits
                //     real art color (dist >= CREAM_TOL). Fully-opaque interior
                //     cream (clock face, keys, hub) is not at the rim and is
                //     untouched.
                //     NOTE: 66 not 60 - the pale ring sits at dist 41-66, and
                //     dist==60 pixels (e.g. stray islands below the mic base)
                //     escaped the old `dist < 60` cutoff exactly.
                const int CREAM_TOL = 66;
                bool changed = true;
                int guard = 0;
                while (changed && guard++ < 64)
                {
                    changed = false;
                    for (int y = 0; y < ch; y++)
                    {
                        for (int x = 0; x < cw; x++)
                        {
                            int s = At(opx, oStride, x, y);
                            if (opx[s + 3] == 0) continue;
                            bool adjT = (x > 0 && opx[At(opx, oStride, x - 1, y) + 3] == 0) ||
                                        (x < cw - 1 && opx[At(opx, oStride, x + 1, y) + 3] == 0) ||
                                        (y > 0 && opx[At(opx, oStride, x, y - 1) + 3] == 0) ||
                                        (y < ch - 1 && opx[At(opx, oStride, x, y + 1) + 3] == 0);
                            if (!adjT) continue;
                            int dR = Math.Abs((int)opx[s] - br), dG = Math.Abs((int)opx[s + 1] - bg), dB = Math.Abs((int)opx[s + 2] - bb);
                            if (Math.Max(dR, Math.Max(dG, dB)) < CREAM_TOL) { opx[s + 3] = 0; changed = true; }
                        }
                    }
                }

                // NOTE: no extra "rim fade" here - the icons are cream/pastel
                // art whose real edge sits only dist 40-90 from the bg, so a
                // color-distance fade would eat the actual icon (it removed the
                // clock body's bottom rows in testing). The peel above already
                // removes every bg-near rim pixel; the remaining pale edge is
                // the art's own color.

                // 11) ISLAND SWEEP: drop tiny detached components (area <= 4)
                //     whose color is still near the bg - e.g. the stray 1px
                //     pink dot floating below the mic base. The peel only
                //     walks the rim; a floating pixel whose neighbors are all
                //     transparent was already rim-adjacent, but a 2-4px speck
                //     attached diagonally can survive. Anything this small is
                //     noise, not art.
                {
                    var aMask = new byte[cw * ch];
                    for (int o = 0; o < cw * ch; o++) aMask[o] = opx[At(opx, oStride, o % cw, o / cw) + 3];
                    var vis = new bool[cw * ch];
                    for (int o = 0; o < cw * ch; o++)
                    {
                        if (aMask[o] == 0 || vis[o]) continue;
                        var q = new Queue<int>();
                        q.Enqueue(o); vis[o] = true;
                        int n = 0;
                        var cells = new List<int>();
                        while (q.Count > 0)
                        {
                            int p = q.Dequeue();
                            cells.Add(p); n++;
                            int xx = p % cw, yy = p / cw;
                            if (xx > 0 && !vis[p - 1] && aMask[p - 1] != 0) { vis[p - 1] = true; q.Enqueue(p - 1); }
                            if (xx < cw - 1 && !vis[p + 1] && aMask[p + 1] != 0) { vis[p + 1] = true; q.Enqueue(p + 1); }
                            if (yy > 0 && !vis[p - cw] && aMask[p - cw] != 0) { vis[p - cw] = true; q.Enqueue(p - cw); }
                            if (yy < ch - 1 && !vis[p + cw] && aMask[p + cw] != 0) { vis[p + cw] = true; q.Enqueue(p + cw); }
                        }
                        if (n <= 4)
                        {
                            bool nearBg = true;
                            foreach (int p in cells)
                            {
                                int s = At(opx, oStride, p % cw, p / cw);
                                int dR = Math.Abs((int)opx[s] - br), dG = Math.Abs((int)opx[s + 1] - bg), dB = Math.Abs((int)opx[s + 2] - bb);
                                if (Math.Max(dR, Math.Max(dG, dB)) >= CREAM_TOL) { nearBg = false; break; }
                            }
                            if (nearBg) foreach (int p in cells) opx[At(opx, oStride, p % cw, p / cw) + 3] = 0;
                        }
                    }
                }

                Marshal.Copy(opx, 0, outData.Scan0, opx.Length);
                outBmp.UnlockBits(outData);
                outBmp.Save(Path.Combine(outDir, name), ImageFormat.Png);
                outBmp.Save(Path.Combine(appOutDir, name), ImageFormat.Png);
                outBmp.Dispose();
                results.Add(name + "  src=(" + cl[0] + "," + cl[2] + ")-(" + cl[1] + "," + cl[3] + ")  crop=" + cw + "x" + ch);
                idx++;
            }
        }
        return results.ToArray();
    }
}
'@

Add-Type -ReferencedAssemblies @('System.Drawing') -TypeDefinition $cs

# 输出命名：button1..6.png（用户指定），同时复制一份到 app/assets/icons 供 Flutter 使用
$names = @('button1.png','button2.png','button3.png','button4.png','button5.png','button6.png')
[IconCutter6]::Cut($Src, $OutDir, $AppOutDir, $SrcOutDir, $Tolerance, $Margin, $names) | ForEach-Object { Write-Output $_ }
