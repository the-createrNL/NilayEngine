param (
    [switch]$run = $false
)

# Compile for spirv (Fix: added -spirv)
dxc.exe -spirv -T vs_6_0 -E "vs_main" "shaders/shader_source.hlsl" -Fo "shaders/compiled_spirv/shader.vert.spirv"
dxc.exe -spirv -T ps_6_0 -E "ps_main" "shaders/shader_source.hlsl" -Fo "shaders/compiled_spirv/shader.pixl.spirv"

dxc.exe -spirv -T vs_6_0 -E "vmain" "shaders/posonly.hlsl" -Fo "shaders/compiled_spirv/posonly.vert.spirv"
dxc.exe -spirv -T ps_6_0 -E "pmain" "shaders/posonly.hlsl" -Fo "shaders/compiled_spirv/posonly.pixl.spirv"

odin.exe build ".\source" -out:"out/forward_game.exe" -debug

if ($run) {
    & .\forward_game.exe
}