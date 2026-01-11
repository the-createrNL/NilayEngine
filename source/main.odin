// file : main.odin

package main

import log          "core:log"
import sdl          "vendor:sdl3"

main :: proc () {
    context.logger = log.create_console_logger(opt = {.Line, .Level})

    conx: Context
    conxptr: ^Context = &conx

    {
        init_sdl                    (conxptr)
        create_window               (conxptr)
        create_device               (conxptr)
        create_gpipeline            (conxptr)
        create_gpumeshs             (conxptr)
        init_cam                    (conxptr)
        begin_gameloop              (conxptr)
    }
}

Context         :: struct {
    cam:            GpuCamera,
    time:           TimeHandler,
    mouse:          MouseHandler,
    window:         WindowInfo,
    device:         GpuDeviceInfo,
    gpipeline:      GpuPipelineInfo,
    meshmap:        GpuMesh_map,
}

WindowInfo      :: struct {
    window:         ^sdl.Window,
    title:          cstring,
    size:           [2]u32,
    midle:          [2]u32,
    aspect:         f32,
}

GpuDeviceInfo   :: struct {
    device:             ^sdl.GPUDevice,
    format_flags:   sdl.GPUShaderFormat,
}

GpuPipelineInfo :: struct {
    pipeline:          ^sdl.GPUGraphicsPipeline,
    vshad_code_path:    cstring,
    fshad_code_path:    cstring,
    depth_texture:      GpuTextureInfo,
}

TimeHandler     :: struct {
    time_ms:        u64,
    time_s:         f64,
    delta_ms:       u64,
    delta_s:        f64,
}

MouseHandler    :: struct {
    mode:           MouseMode,
    pos:            [2]u32,
    delta:          [2]i32,
    isinw:          bool,
}

DrawContext     :: struct {
    command_buffer:         ^sdl.GPUCommandBuffer,
    render_pass:            ^sdl.GPURenderPass,
}

GpuVertex       :: struct {
    pos:    [3]f32,
    tex:    [2]f32,
    nor:    [3]f32,
}

MeshData        :: struct {
    vertices:       []GpuVertex,
    indices:        []u32
}

GpuMesh         :: struct {
    // Vertex Data
    vertex_buffer:  ^sdl.GPUBuffer,
    vertex_count:   u32,            // Indispensable pour sdl.DrawGPUPrimitives

    // Index Data (Optionnel, si tu utilises des indices)
    index_buffer:   ^sdl.GPUBuffer,
    index_count:    u32,            // Indispensable pour sdl.DrawGPUIndexedPrimitives

    // Material / Texture
    texture:        ^sdl.GPUTexture,
    sampler:        ^sdl.GPUSampler, // Souvent nécessaire avec la texture
}

GpuMesh_map     :: struct {
    mesh_map:       map[string]GpuMesh
}

vUniform_cam    :: struct {
    view:           matrix[4, 4]f32,
    projection:     matrix[4, 4]f32,
}

vUniform_mdl    :: struct {
    model:          matrix[4, 4]f32,
}

GpuTextureInfo  :: struct {
    texture:        ^sdl.GPUTexture,
    type:           sdl.GPUTextureType,
    format:         sdl.GPUTextureFormat,
    usage:          sdl.GPUTextureUsageFlags,
    width:          u32,
    height:         u32,
    layer_count:    u32,
    num_levels:     u32,
}

ImageDesc       :: struct {
    list_pixels:        [^]byte,
    size:               [2]i32,
    channels:           i32,
    bytesize:           u32,
    pixel_count:        u32,
}

GpuCamera       :: struct {
    pos:            [3]f32,
    dir:            [3]f32,
    front:          [3]f32,
    right:          [3]f32,
    local_up:       [3]f32,
    speed:          [2]f32,
    speed_move:     [3]f32,
    yaw:            f32,
    pitch:          f32,
    max_pitch:      f32,
    fovy:           f32,
    near:           f32,
    far:            f32,
    uniform:        vUniform_cam,
}

MouseMode       :: enum   {
    ui,
    fps,
}
