# Web版の定点計測用ビルドを書き出す。
param(
	[Parameter(Mandatory = $true)]
	[string]$Out,
	[string]$Godot = 'D:\Downloads\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe'
)

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$originalLocation = Get-Location
$outPath = [System.IO.Path]::GetFullPath($Out)
$presetPath = Join-Path $repoRoot 'export_presets.cfg'
$projectPath = Join-Path $repoRoot 'project.godot'
$benchSource = Join-Path $PSScriptRoot 'web_bench.gd'
$tempScript = Join-Path $repoRoot 'web_bench_tmp.gd'
$tempUid = "$tempScript.uid"
$indexHtml = Join-Path $outPath 'index.html'

Set-Location $repoRoot
$dirtyConfig = git status --porcelain -- export_presets.cfg project.godot
if ($LASTEXITCODE -ne 0) {
	Set-Location $originalLocation
	throw 'git status の確認に失敗しました。'
}
if ($dirtyConfig) {
	Set-Location $originalLocation
	throw 'export_presets.cfg または project.godot に変更があるため中断します。'
}
if ((Test-Path -LiteralPath $tempScript) -or (Test-Path -LiteralPath $tempUid)) {
	Set-Location $originalLocation
	throw 'web_bench_tmp.gd または対応する .uid が既にあるため中断します。'
}

try {
	if (-not (Test-Path -LiteralPath $benchSource)) { throw 'web_bench.gd が見つかりません。' }
	if (-not (Test-Path -LiteralPath $Godot)) { throw "Godot が見つかりません: $Godot" }

	New-Item -ItemType Directory -Path $outPath -Force | Out-Null
	Copy-Item -LiteralPath $benchSource -Destination $tempScript

	$presets = Get-Content -LiteralPath $presetPath -Raw
	$oldExclude = 'tools/*, tests/*"'
	$newExclude = 'tools/*, tests/*, tmp/*, .codex/*"'
	if (-not $presets.Contains($oldExclude)) { throw 'export_presets.cfg の置換対象が見つかりません。' }
	$presets = $presets.Replace($oldExclude, $newExclude)
	Set-Content -LiteralPath $presetPath -Value $presets -NoNewline -Encoding utf8

	$project = Get-Content -LiteralPath $projectPath -Raw
	$orientationLine = 'ScreenOrientation="*res://screen_orientation.gd"'
	$benchLine = "ScreenOrientation=`"*res://screen_orientation.gd`"`nWebBench=`"*res://web_bench_tmp.gd`""
	if (-not $project.Contains($orientationLine)) { throw 'project.godot の ScreenOrientation が見つかりません。' }
	$project = $project.Replace($orientationLine, $benchLine)
	Set-Content -LiteralPath $projectPath -Value $project -NoNewline -Encoding utf8

	& $Godot --headless --path . --export-release "Web" $indexHtml
	if ($LASTEXITCODE -ne 0) { throw "Godot の書き出しに失敗しました (exit $LASTEXITCODE)。" }
}
finally {
	if (Test-Path -LiteralPath $repoRoot) {
		Set-Location $repoRoot
		git checkout -- export_presets.cfg project.godot
		if ($LASTEXITCODE -ne 0) { Write-Error '設定ファイルの復元に失敗しました。' }
	}
	if (Test-Path -LiteralPath $tempScript) { Remove-Item -LiteralPath $tempScript }
	if (Test-Path -LiteralPath $tempUid) { Remove-Item -LiteralPath $tempUid }
	Set-Location $originalLocation
}

$pckPath = Join-Path $outPath 'index.pck'
$wasmPath = Join-Path $outPath 'index.wasm'
foreach ($artifact in @($pckPath, $wasmPath)) {
	if (Test-Path -LiteralPath $artifact) {
		$sizeMb = (Get-Item -LiteralPath $artifact).Length / 1MB
		'{0}: {1:N2} MB' -f (Split-Path -Leaf $artifact), $sizeMb
	}
}
