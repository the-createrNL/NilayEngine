param (
    [switch]$run = $false
)

# Compile for spirv (Fix: added -spirv)
dxc.exe -T vs_6_0 -E "vmain" "shaders/posonly.hlsl" -Fo "shaders/compiled_dxil/posonly.vert.dxil"
dxc.exe -T ps_6_0 -E "pmain" "shaders/posonly.hlsl" -Fo "shaders/compiled_dxil/posonly.pixl.dxil"

dxc.exe -spirv -T vs_6_0 -E "vmain" "shaders/posonly.hlsl" -Fo "shaders/compiled_spirv/posonly.vert.spirv"
dxc.exe -spirv -T ps_6_0 -E "pmain" "shaders/posonly.hlsl" -Fo "shaders/compiled_spirv/posonly.pixl.spirv"

odin.exe build ".\source" -out:"out/forward_game.exe" -debug

if ($run) {
    & .\forward_game.exe
}