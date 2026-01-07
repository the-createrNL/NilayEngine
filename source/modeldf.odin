// modeldf.odin

package main

import log          "core:log"
import sdl          "vendor:sdl3"
import os           "core:os"
import ln           "core:math/linalg"

init_sdl            :: proc (conx: ^Context, init_flags: sdl.InitFlags = {.VIDEO}) {
    ok: bool = sdl.Init(init_flags)

    assert(ok, string(sdl.GetError()))

    sdl.SetLogPriorities(.VERBOSE)
}

create_window       :: proc (conx: ^Context) {
    conx.window.title   = cstring("mouha window")
    conx.window.size    = {800, 580}
    conx.window.aspect  = f32(conx.window.size.x) / f32(conx.window.size.y)
    conx.window.midle   = {conx.window.size.x/2, conx.window.size.y/2}

    conx.window.window = sdl.CreateWindow(
        conx.window.title,
        i32(conx.window.size.x),
        i32(conx.window.size.y),
        {}
    )

    assert(conx.window.window != nil, string(sdl.GetError()))

    set_mouse_mode(conx, .fps)
}

create_device       :: proc (conx: ^Context) {
    conx.device.format_flags = {.SPIRV}

    conx.device.device = sdl.CreateGPUDevice(
        conx.device.format_flags,
        true,
        nil
    )

    assert(conx.device.device != nil, string(sdl.GetError()))

    ok := sdl.ClaimWindowForGPUDevice(conx.device.device, conx.window.window)

    ok = sdl.SetGPUSwapchainParameters(conx.device.device, conx.window.window, .SDR, .VSYNC)
}

create_gpipeline    :: proc (conx: ^Context) {
    create_depthtexture(conx)

    conx.gpipeline.vshad_code_path = cstring("shaders/compiled_spirv/posonly.vert.spirv")
    conx.gpipeline.fshad_code_path = cstring("shaders/compiled_spirv/posonly.pixl.spirv")

    vshader, fshader := create_shaders(conx)

    target_info: sdl.GPUGraphicsPipelineTargetInfo = {
        color_target_descriptions = &sdl.GPUColorTargetDescription{
            format = sdl.GetGPUSwapchainTextureFormat(conx.device.device, conx.window.window)
        },
        num_color_targets = 1,

        has_depth_stencil_target    = bool(true),
        depth_stencil_format        = conx.gpipeline.depth_texture.format,
    } 

    depth_state: sdl.GPUDepthStencilState = {
        enable_depth_test   = true,   // ACTIVATION !
        enable_depth_write  = true,   // Permet d'écrire dans la texture
        compare_op          = .LESS,  // Si Z < Z_actuel (plus proche), on dessine
    }

    vbuffer_desc:   sdl.GPUVertexBufferDescription
    vattribs_pos:   sdl.GPUVertexAttribute
    vattribs_tex:   sdl.GPUVertexAttribute

    vbuffer_desc, vattribs_pos, vattribs_tex = create_vinput_state()

    list_vbuffer_descs:     []sdl.GPUVertexBufferDescription = {vbuffer_desc}
    list_vattribs:          []sdl.GPUVertexAttribute         = {vattribs_pos, vattribs_tex}

    vertex_input_state := sdl.GPUVertexInputState{
        vertex_buffer_descriptions      = raw_data  (list_vbuffer_descs),
        num_vertex_buffers              = u32(len   (list_vbuffer_descs)),
        vertex_attributes               = raw_data  (list_vattribs),
        num_vertex_attributes           = u32(len   (list_vattribs)),
    }

    gpipeline_info: sdl.GPUGraphicsPipelineCreateInfo = {
        vertex_shader               = vshader,
        fragment_shader             = fshader,
        target_info                 = target_info,
        depth_stencil_state         = depth_state,
        vertex_input_state          = vertex_input_state,
    }

    conx.gpipeline.pipeline = sdl.CreateGPUGraphicsPipeline(conx.device.device, gpipeline_info)
}

begin_drawing       :: proc (conx: ^Context) -> DrawContext {
    command_buffer  := sdl.AcquireGPUCommandBuffer(conx.device.device)

    texture: ^sdl.GPUTexture
    ok := sdl.WaitAndAcquireGPUSwapchainTexture(command_buffer, conx.window.window, &texture, nil, nil)

    render_pass     := sdl.BeginGPURenderPass(command_buffer, &sdl.GPUColorTargetInfo{
        texture = texture,
        clear_color = sdl.FColor{0.1, 0.1, 0.1, 1.0},
        load_op = .CLEAR,
        store_op = .STORE
    }, 1, &sdl.GPUDepthStencilTargetInfo{
        texture = conx.gpipeline.depth_texture.texture,
        clear_depth = 1,
        load_op = .CLEAR,
        store_op = .DONT_CARE,
    })

    drawconx: DrawContext = {
        command_buffer = command_buffer,
        render_pass = render_pass
    }

    sdl.BindGPUGraphicsPipeline(render_pass, conx.gpipeline.pipeline)

    return drawconx
}

end_drawing         :: proc (conx: ^Context, #by_ptr drawconx: DrawContext) {
    sdl.EndGPURenderPass(drawconx.render_pass)
    ok := sdl.SubmitGPUCommandBuffer(drawconx.command_buffer)
}

update_context      :: proc (conx: ^Context) {
    update_time         (conx)
    update_mouse        (conx)
    update_cam          (conx)
}

begin_gameloop      :: proc (conx: ^Context) {
    gameloop := bool(true)

    vunif_mdl: vUniform_mdl = {
        model       = ln.MATRIX4F32_IDENTITY,
    }



    for gameloop {
        event: sdl.Event
        for sdl.PollEvent(&event) {
            if event.type == .QUIT do gameloop = bool(false)

            if event.type == .MOUSE_MOTION {}

            if event.type == .WINDOW_RESIZED do update_window(conx)

            if event.type == .KEY_DOWN {
                if event.key.scancode == .ESCAPE {
                    if      conx.mouse.mode == .ui   do set_mouse_mode(conx, .fps)
                    else if conx.mouse.mode == .fps  do set_mouse_mode(conx, .ui)
                }
            }
        }

        update_context(conx)

        drawconx := begin_drawing(conx); {
            
            sdl.PushGPUVertexUniformData(drawconx.command_buffer, 0, &conx.cam.uniform, size_of(vUniform_cam))
            vunif_mdl.model = ln.matrix4_translate_f32({0, 0, 0}) * ln.matrix4_rotate_f32(f32(conx.time.time_s), {3, 241, 241})
            sdl.PushGPUVertexUniformData(drawconx.command_buffer, 1, &vunif_mdl, size_of(vunif_mdl))
            sdl.DrawGPUPrimitives(drawconx.render_pass, 36, 1, 0, 0)

        }; end_drawing(conx, drawconx)
    }
}



@(require_results)
create_shaders          :: proc (conx: ^Context) -> (vshader: ^sdl.GPUShader, fshader: ^sdl.GPUShader) {
    vshad_code, _ := os.read_entire_file_from_filename(string(conx.gpipeline.vshad_code_path))
    fshad_code, _ := os.read_entire_file_from_filename(string(conx.gpipeline.fshad_code_path))

    defer delete(vshad_code)
    defer delete(fshad_code)

    bytesize_vshadcode := uint(size_of(vshad_code[0]) * len(vshad_code))
    bytesize_fshadcode := uint(size_of(fshad_code[0]) * len(fshad_code))

    ventry_point := cstring("vmain")
    fentry_point := cstring("pmain")

    vshadinfo: sdl.GPUShaderCreateInfo  = {
        code_size                       = bytesize_vshadcode,
        code                            = ([^]byte)(raw_data(vshad_code)),
        entrypoint                      = ventry_point,
        format                          = conx.device.format_flags,
        stage                           = .VERTEX,
        num_samplers                    = 0,
        num_storage_buffers             = 0,
        num_storage_textures            = 0,
        num_uniform_buffers             = 2,
    }

    fshadinfo: sdl.GPUShaderCreateInfo  = {
        code_size                       = bytesize_fshadcode,
        code                            = ([^]byte)(raw_data(fshad_code)),
        entrypoint                      = fentry_point,
        format                          = conx.device.format_flags,
        stage                           = .FRAGMENT,
        num_samplers                    = 1,
        num_storage_buffers             = 0,
        num_storage_textures            = 0,
        num_uniform_buffers             = 0,
    }

    vshader = sdl.CreateGPUShader(conx.device.device, vshadinfo)
    fshader = sdl.CreateGPUShader(conx.device.device, fshadinfo)

    return
}

create_gputexture       :: proc (conx: ^Context, texinfo: ^GpuTextureInfo) {
    texinfo.texture = sdl.CreateGPUTexture(conx.device.device, sdl.GPUTextureCreateInfo{
        type                    = texinfo.type,
        format                  = texinfo.format,
        usage                   = texinfo.usage,
        width                   = texinfo.width,
        height                  = texinfo.height,
        layer_count_or_depth    = texinfo.layer_count,
        num_levels              = texinfo.num_levels,
    })
}

create_depthtexture     :: proc (conx: ^Context) {
    conx.gpipeline.depth_texture = GpuTextureInfo {
        type                = .D2,
        format              = .D24_UNORM,
        usage               = {.DEPTH_STENCIL_TARGET},
        width               = conx.window.size.x,
        height              = conx.window.size.y,
        layer_count         = 1,
        num_levels          = 1,
    }

    create_gputexture(conx, &conx.gpipeline.depth_texture)
}

update_window           :: proc (conx: ^Context) {
    win_size:   [2]i32
    sdl.GetWindowSize(conx.window.window, &win_size.x, &win_size.y)

    conx.window.size    = {u32(win_size.x), u32(win_size.y)}
    conx.window.aspect  = f32(conx.window.size.x) / f32(conx.window.size.y)
    conx.window.midle   = {conx.window.size.x/2, conx.window.size.y/2}
}

update_time             :: proc (conx: ^Context) {
    ticks:      u64 = sdl.GetTicks()
    delta:      u64 = ticks - conx.time.time_ms

    conx.time = TimeHandler {
        time_ms     = ticks,
        time_s      = f64(ticks) / 1000,
        delta_ms    = delta,
        delta_s     = f64(delta) / 1000,
    }
}

set_mouse_mode          :: proc (conx: ^Context, mode: MouseMode) {
    switch mode {
        case .ui    :
            ok := sdl.SetWindowRelativeMouseMode(conx.window.window, false)
            conx.mouse.mode = .ui
        case .fps  :
            ok := sdl.SetWindowRelativeMouseMode(conx.window.window, true)
            conx.mouse.mode = .fps
    }
} 

update_mouse            :: proc (conx: ^Context) {
    mouse_new_pos:      [2]f32
    mouse_new_delta:    [2]f32

    _= sdl.GetMouseState(&mouse_new_pos.x, &mouse_new_pos.y)
    _= sdl.GetRelativeMouseState(&mouse_new_delta.x, &mouse_new_delta.y)

    conx.mouse.pos      = {u32(mouse_new_pos.x), u32(mouse_new_pos.y)}
    if conx.mouse.mode == .ui   do conx.mouse.delta    = {i32(0.0),         i32(0.0)}
    if conx.mouse.mode == .fps  do conx.mouse.delta    = {i32(mouse_new_delta.x), i32(mouse_new_delta.y)}
}

init_cam                :: proc (conx: ^Context) {
    conx.cam = GpuCamera {
        pos                 = {0.0, 0.0, 0.0},
        dir                 = {0.0, 0.0, 0.0},
        front               = {0.0, 0.0, 0.0},
        right               = {0.0, 0.0, 0.0},
        local_up            = {0.0, 0.0, 0.0},
        speed               = {0.003, 0.003},
        speed_move          = {0.2, 0.2, 0.2},
        yaw                 = f32(0.0),
        pitch               = f32(0.0),
        max_pitch           = f32(ln.PI / 2) - 0.01,
        fovy                = ln.to_radians(f32(65.0)),
        near                = f32(0.0001),
        far                 = f32(1000.0),
        uniform             = vUniform_cam {
            view            = ln.MATRIX4F32_IDENTITY,
            projection      = ln.MATRIX4F32_IDENTITY,
        },
    }
}

update_cam              :: proc (conx: ^Context) {
    base_forward: [3]f32 = {0.0, 0.0, 1.0}
    base_right:   [3]f32 = {1.0, 0.0, 0.0}
    base_up:      [3]f32 = {0.0, 1.0, 0.0}

    q_dir:      ln.Quaternionf32

    {
        conx.cam.yaw   += f32(conx.mouse.delta.x) * -conx.cam.speed.x
        conx.cam.pitch += f32(conx.mouse.delta.y) * conx.cam.speed.y
        conx.cam.pitch  = clamp(conx.cam.pitch, -conx.cam.max_pitch, conx.cam.max_pitch)

        q_yaw:      ln.Quaternionf32 = ln.quaternion_angle_axis_f32(conx.cam.yaw,   {0, 1, 0})
        q_pitch:    ln.Quaternionf32 = ln.quaternion_angle_axis_f32(conx.cam.pitch, {1, 0, 0})

        q_dir                        = ln.quaternion_mul_quaternion( q_yaw, q_pitch )

        conx.cam.dir = ln.normalize(ln.quaternion_mul_vector3(q_dir, base_forward))
    }

    move_dir: [3]f32 = {0,0,0}
    {
        conx.cam.front      = ln.normalize(ln.quaternion_mul_vector3(q_dir, base_forward))
        conx.cam.right      = ln.normalize(ln.quaternion_mul_vector3(q_dir, base_right  ))
        conx.cam.local_up   = ln.normalize(ln.quaternion_mul_vector3(q_dir, base_up     ))

        keyboard: [^]bool = sdl.GetKeyboardState(nil)
        if keyboard[sdl.Scancode.W]         do move_dir += conx.cam.front   * conx.cam.speed_move
        if keyboard[sdl.Scancode.S]         do move_dir -= conx.cam.front   * conx.cam.speed_move
        if keyboard[sdl.Scancode.D]         do move_dir -= conx.cam.right   * conx.cam.speed_move
        if keyboard[sdl.Scancode.A]         do move_dir += conx.cam.right   * conx.cam.speed_move
    }

    if ln.length(move_dir) > 0.001 {
        // On ramène la longueur de la diagonale (1.414) à 1.0
        move_dir = ln.normalize(move_dir)
        
        // 3. Et MAINTENANT on applique la vitesse
        conx.cam.pos += move_dir * conx.cam.speed_move
    }

    conx.cam.uniform.view       = ln.matrix4_look_at_f32(
        eye                     = conx.cam.pos,
        centre                  = conx.cam.dir + conx.cam.pos,
        up                      = {0.0, 1.0, 0.0},
        flip_z_axis             = true,
    )

    conx.cam.uniform.projection = ln.matrix4_perspective_f32(
        fovy                    = conx.cam.fovy,
        aspect                  = conx.window.aspect,
        near                    = conx.cam.near,
        far                     = conx.cam.far,
        flip_z_axis             = true,
    )
}

create_vinput_state     :: proc () -> (sdl.GPUVertexBufferDescription, sdl.GPUVertexAttribute, sdl.GPUVertexAttribute) {
    vbuffer_desc: sdl.GPUVertexBufferDescription = {
        slot            = 0,
        pitch           = size_of(GpuVertex),
        input_rate      = .VERTEX
    }

    vattrib_pos: sdl.GPUVertexAttribute = {
        location        = 0,
        buffer_slot     = 0,
        format          = .FLOAT3,
        offset          = u32(offset_of(GpuVertex, pos))
    }

    vattrib_tex: sdl.GPUVertexAttribute = {
        location        = 1,
        buffer_slot     = 0,
        format          = .FLOAT2,
        offset          = u32(offset_of(GpuVertex, tex))
    }

    return vbuffer_desc, vattrib_pos, vattrib_tex
}
