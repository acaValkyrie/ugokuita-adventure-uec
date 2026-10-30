# Godot Web export template（release / no threads / wasm32）をビルドする。
# 同階層の skip_default_shader_variant.patch を適用し、Web GLES3 で未使用の
# 各 shader の default specialization のコンパイルを止める。
# Windows Chrome の初回訪問では各約 1.4 秒かかる処理を省く。
# 成果物は export_presets.cfg の custom release template に指定する。
param(
	[string]$BuildDir = 'D:\document\Program\Godot\godot-web-build',
	[string]$GodotTag = '4.7.1-stable',
	[string]$EmsdkVersion = '4.0.20',
	[int]$Jobs = [Environment]::ProcessorCount
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$originalLocation = Get-Location

try {
	$emsdk = Join-Path $BuildDir 'emsdk'
	$godot = Join-Path $BuildDir 'godot'
	$emsdkScript = Join-Path $emsdk 'emsdk.ps1'
	$patch = Join-Path $PSScriptRoot 'skip_default_shader_variant.patch'
	$output = Join-Path $PSScriptRoot 'web_nothreads_release.zip'

	if (-not (Test-Path -LiteralPath $emsdkScript -PathType Leaf)) {
		Write-Host "git clone https://github.com/emscripten-core/emsdk.git `"$emsdk`""
		Write-Host "& `"$emsdkScript`" install $EmsdkVersion"
		Write-Host "& `"$emsdkScript`" activate $EmsdkVersion"
		throw 'emsdk.ps1 がありません。上記コマンドで Emscripten SDK を準備してください。'
	}

	if (-not (Test-Path -LiteralPath $godot -PathType Container)) {
		git clone --depth 1 --branch $GodotTag https://github.com/godotengine/godot.git $godot
		if ($LASTEXITCODE -ne 0) {
			throw 'Godot リポジトリの取得に失敗しました。'
		}
	}

	$actualTag = git -C $godot describe --tags
	if ($LASTEXITCODE -ne 0 -or $actualTag -cne $GodotTag) {
		throw "Godot のタグが一致しません。期待値: $GodotTag / 実際: $actualTag"
	}

	git -C $godot apply --reverse --check $patch 2>$null
	if ($LASTEXITCODE -eq 0) {
		Write-Host 'シェーダーパッチは適用済みです。'
	} else {
		git -C $godot apply $patch
		if ($LASTEXITCODE -ne 0) {
			throw 'シェーダーパッチの適用に失敗しました。'
		}
	}

	. (Join-Path $emsdk 'emsdk_env.ps1')
	if (-not (Get-Command emcc -ErrorAction SilentlyContinue)) {
		Write-Host "& `"$emsdkScript`" activate $EmsdkVersion"
		throw "emcc が見つかりません。上記コマンドで Emscripten $EmsdkVersion を有効化してください。"
	}
	$emccVersion = emcc --version
	if ($LASTEXITCODE -ne 0 -or ($emccVersion -join "`n") -notmatch [regex]::Escape($EmsdkVersion)) {
		Write-Host "& `"$emsdkScript`" activate $EmsdkVersion"
		throw "Emscripten のバージョンが $EmsdkVersion と一致しません。上記コマンドで有効化してください。"
	}

	Set-Location -LiteralPath $godot
	uv tool run --from scons scons platform=web target=template_release threads=no arch=wasm32 production=yes -j $Jobs
	if ($LASTEXITCODE -ne 0) {
		throw 'Godot Web export template のビルドに失敗しました。'
	}

	Copy-Item -LiteralPath (Join-Path $godot 'bin/godot.web.template_release.wasm32.nothreads.zip') -Destination $output -Force
	$sizeMB = (Get-Item -LiteralPath $output).Length / 1MB
	Write-Host ('成果物: {0} ({1:F2} MB)' -f $output, $sizeMB)
} finally {
	Set-Location -LiteralPath $originalLocation
}
