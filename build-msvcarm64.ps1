$ErrorActionPreference = "Stop"

# Detect vswhere location
try {
	$vswhere = (Get-Command "vswhere").source
} catch {
	$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
}

# Use vswhere to get Visual Studio's VC folder path, containing console setup scripts
$VcPath = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath

# Call vcvarsamd64_arm64.bat with cmd to setup environment variables and retrieve them in our PowerShell environment
$VsDevCmdPath = Join-Path $VcPath 'VC\Auxiliary\Build\vcvarsamd64_arm64.bat'
cmd /s /c """$VsDevCmdPath"" $args && set" | Where-Object { $_ -match '(\w+)=(.*)' } | ForEach-Object {
    $null = New-Item -Force -Path "Env:\$($Matches[1])" -Value $Matches[2]
}

# Setup output directory
try { Remove-Item -Recurse -Force -Path "$PSScriptRoot/out" } catch {}
New-Item -ItemType Directory -Path "$PSScriptRoot/out" | Out-Null

# Setup Vulkan SDK
if(-not (Test-Path "$PSScriptRoot/include/vulkan/include")) {
	New-Item -ItemType SymbolicLink -Path "$PSScriptRoot/include/vulkan/include" -Target "D:\Program Files\VulkanSDK\1.3.283.0\Include" | Out-Null
}
if(-not (Test-Path "$PSScriptRoot/include/spirv/include")) {
	New-Item -ItemType Directory -Path "$PSScriptRoot/include/spirv/include" | Out-Null
	New-Item -ItemType Directory -Path "$PSScriptRoot/include/spirv/include/spirv" | Out-Null
	New-Item -ItemType SymbolicLink -Path "$PSScriptRoot/include/spirv/include/spirv/unified1" -Target "D:\Program Files\VulkanSDK\1.3.283.0\Include\spirv-headers" | Out-Null
}

# Setup build by calling meson
# Instruct meson to not use native compiler tools as Visual Studio does not support havng both cross and native compilers in a single session
meson setup --cross-file build-msvcarm64.txt --native-file build-none.txt --buildtype release --prefix "$PSScriptRoot/out/dxvk" "$PSScriptRoot/out/build.arm64"
if($LASTERRORCODE -ne 0) {
	throw "meson invokation failed."
}

# Build and copy binaries
Push-Location "$PSScriptRoot/out/build.arm64"
try {
	ninja install
	if($LASTERRORCODE -ne 0) {
		throw "ninja invokation failed."
	}
} finally {
	Pop-Location
}

# Remove .a and .lib files from package directory
Get-ChildItem -Recurse -File -Path "$PSScriptRoot/out/dxvk" | Where-Object { $_ -notlike "*.dll" } | Remove-Item
# Remove empty directories from package directory
Get-ChildItem -Recurse -Directory -Path "$PSScriptRoot/out/dxvk" | Where-Object { ($_ | Get-ChildItem | Measure-Object).Count -eq 0 } | Remove-Item

# Create package
Compress-Archive -Path "$PSScriptRoot/out/dxvk" -DestinationPath "$PSScriptRoot/out/dxvk.zip"
