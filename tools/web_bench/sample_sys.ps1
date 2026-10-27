param([int]$Seconds = 300, [string]$Out)
# Claude アプリのプロセスごとの CPU・メモリと、GPU の使用率・専用メモリを1秒ごとに JSON Lines で記録する
$cores = [Environment]::ProcessorCount
$types = @{}
Get-CimInstance Win32_Process -Filter "Name='claude.exe'" | ForEach-Object {
	$t = if ($_.CommandLine -match '--type=([\w-]+)') { $Matches[1] } else { 'browser' }
	$types[[int]$_.ProcessId] = $t
}
$prev = @{}
foreach ($p in Get-Process -Name claude) { $prev[$p.Id] = $p.TotalProcessorTime.TotalMilliseconds }
$prevT = [DateTime]::UtcNow
$end = (Get-Date).AddSeconds($Seconds)
while ((Get-Date) -lt $end) {
	$c = Get-Counter '\GPU Engine(*engtype_3D)\Utilization Percentage', '\GPU Process Memory(*)\Dedicated Usage' -ErrorAction SilentlyContinue
	$now = [DateTime]::UtcNow
	$dt = ($now - $prevT).TotalMilliseconds
	$prevT = $now
	$gpu = @{}; $vram = @{}; $gpuTotal = 0.0
	foreach ($s in $c.CounterSamples) {
		if ($s.InstanceName -match 'pid_(\d+)') {
			$id = [int]$Matches[1]
			if ($s.Path -like '*utilization percentage') { $gpu[$id] = ($gpu[$id] + $s.CookedValue); $gpuTotal += $s.CookedValue }
			else { $vram[$id] = ($vram[$id] + $s.CookedValue) }
		}
	}
	$procs = foreach ($p in Get-Process -Name claude) {
		$cpu = $p.TotalProcessorTime.TotalMilliseconds
		$pct = if ($prev.ContainsKey($p.Id)) { ($cpu - $prev[$p.Id]) / $dt / $cores * 100 } else { 0 }
		$prev[$p.Id] = $cpu
		[ordered]@{ pid = $p.Id; type = $types[$p.Id]; cpu = [math]::Round($pct, 1)
			ws_mb = [math]::Round($p.WorkingSet64 / 1MB); priv_mb = [math]::Round($p.PrivateMemorySize64 / 1MB)
			gpu = [math]::Round([double]$gpu[$p.Id], 1); vram_mb = [math]::Round([double]$vram[$p.Id] / 1MB) }
	}
	[ordered]@{ t = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds(); gpu_total = [math]::Round($gpuTotal, 1); procs = @($procs) } |
		ConvertTo-Json -Compress -Depth 4 | Add-Content -Path $Out
	Start-Sleep -Milliseconds 500
}
