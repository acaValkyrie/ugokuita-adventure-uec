param([string]$Sys, [string]$Phases)
# 計測の区間ごとに、Claude アプリのプロセスの CPU・メモリと GPU の値を平均する
$samples = Get-Content $Sys | ForEach-Object { $_ | ConvertFrom-Json }
$windows = Get-Content $Phases -Raw | ConvertFrom-Json -NoEnumerate
# いちばん CPU を使った renderer をゲームのページとみなす
$cpuByPid = @{}
foreach ($s in $samples) { foreach ($p in $s.procs) { $cpuByPid[$p.pid] = $cpuByPid[$p.pid] + $p.cpu } }
$all = $samples[0].procs
$renderer = ($all | Where-Object type -eq 'renderer' | Sort-Object { $cpuByPid[$_.pid] } -Descending | Select-Object -First 1).pid
$gpuProc = ($all | Where-Object type -eq 'gpu-process' | Select-Object -First 1).pid
"renderer pid=$renderer gpu-process pid=$gpuProc cores=$([Environment]::ProcessorCount)"
foreach ($ph in $windows) {
	$in = $samples | Where-Object { $_.t -ge $ph[2] -and $_.t -le $ph[3] }
	$r = $in | ForEach-Object { $_.procs | Where-Object pid -eq $renderer }
	$g = $in | ForEach-Object { $_.procs | Where-Object pid -eq $gpuProc }
	$tot = $in | ForEach-Object { ($_.procs | Measure-Object cpu -Sum).Sum }
	[pscustomobject]@{
		spot = "$($ph[0]):$($ph[1])"; n = $in.Count
		cpu_renderer = [math]::Round(($r | Measure-Object cpu -Average).Average, 1)
		cpu_gpuproc = [math]::Round(($g | Measure-Object cpu -Average).Average, 1)
		cpu_claude_all = [math]::Round(($tot | Measure-Object -Average).Average, 1)
		gpu3d_total = [math]::Round(($in | Measure-Object gpu_total -Average).Average, 1)
		gpu3d_gpuproc = [math]::Round(($g | Measure-Object gpu -Average).Average, 1)
		vram_gpuproc_mb = [math]::Round(($g | Measure-Object vram_mb -Average).Average)
		renderer_priv_mb = [math]::Round(($r | Measure-Object priv_mb -Average).Average)
		renderer_ws_mb = [math]::Round(($r | Measure-Object ws_mb -Average).Average)
	}
}

