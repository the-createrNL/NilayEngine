package main

import log              "core:log"
import linalg           "core:math/linalg"
import mem              "core:mem"
import sdl              "vendor:sdl3"
import assimp           "../libraries/assimp/import"
import math             "core:math"

// vector type def
    Vec2i32 :: [2]i32
    Vec3i32 :: [3]i32
    Vec4i32 :: [4]i32

    Vec2u32 :: [2]u32
    Vec3u32 :: [3]u32
    Vec4u32 :: [4]u32

    Vec2f32 :: [2]f32
    Vec3f32 :: [3]f32
    Vec4f32 :: [4]f32

    Mat2f32 :: matrix[2, 2]f32
    Mat3f32 :: matrix[3, 3]f32
    Mat4f32 :: matrix[4, 4]f32

    PointIndex    :: Vec3u32
    LineIndex     :: Vec3u32
    TriangleIndex :: Vec3u32

    VertexPos3fCol3f :: struct { pos : Vec3f32, col : Vec3f32 }
    VertexPos3fTex2f :: struct { pos : Vec3f32, tex : Vec2f32 }

    UniformMvp :: struct { mvp : Mat4f32 }

    UserSettings :: struct {
        win_title               : cstring,
        win_w                   : i32,
        win_h                   : i32,
        gpu_drivers             : sdl.GPUShaderFormat,
        perspertive             : Mat4f32
    }


    CubeRendInfo :: struct {
        cmd         : ^sdl.GPUCommandBuffer,
        rps         : ^sdl.GPURenderPass,
        vbuffer     : ^sdl.GPUBuffer,
        ibuffer     : ^sdl.GPUBuffer,
        prsp        : Mat4f32,
        num_indice  : u32
    }
    Cube :: struct {
        pos : Vec3f32,
        rot : Vec3f32,
        scl : Vec3f32
    }
    cube_getmodel :: proc "contextless" (#by_ptr cube : Cube) -> (model : Mat4f32) {
        mpos := linalg.matrix4_translate_f32(cube.pos)
        rot_x := linalg.matrix4_rotate_f32(cube.rot.x, Vec3f32{1, 0, 0})
        rot_y := linalg.matrix4_rotate_f32(cube.rot.y, Vec3f32{0, 1, 0})
        rot_z := linalg.matrix4_rotate_f32(cube.rot.z, Vec3f32{0, 0, 1})
        mrot := rot_z * rot_y * rot_x 
        mscl := linalg.matrix4_scale_f32(cube.scl)
        model = mpos * mrot * mscl
        return
    }
    cube_render :: proc "contextless" (#by_ptr cube : Cube, #by_ptr info : CubeRendInfo) {
        model := cube_getmodel(cube)
        mvp := UniformMvp {
            mvp = info.prsp * model
        }

        sdl.PushGPUVertexUniformData(info.cmd, 0, &mvp, size_of(mvp))
        sdl.BindGPUVertexBuffers(info.rps, 0, &sdl.GPUBufferBinding{ buffer = info.vbuffer, offset = 0 }, 1)
        sdl.BindGPUIndexBuffer(info.rps, { buffer = info.ibuffer, offset = 0 }, ._32BIT)
        sdl.DrawGPUIndexedPrimitives(info.rps, info.num_indice, 1, 0, 0, 0)
    }


main_ :: proc () {
    ok : bool
    context.logger = log.create_console_logger()

    // user
    settings : UserSettings
    {
        ww := i32(1000)
        wh := i32(600)
        aspect := f32(ww)/f32(wh)

        settings = {
            win_title                   = "hello sdl",
            win_w                       = ww,
            win_h                       = wh,
            gpu_drivers                 = {.SPIRV, .DXIL},
            perspertive                 = linalg.matrix4_perspective_f32(linalg.to_radians(f32(45.0)), aspect, 0.0001, 1000.0, false)
        }
    }

    // Init sdl
    window : ^sdl.Window
    device : ^sdl.GPUDevice
    defer sdl.DestroyWindow(window)
    defer sdl.DestroyGPUDevice(device)
    {
        ok = sdl.Init({.VIDEO}); assert(ok)
        sdl.SetLogPriorities(.VERBOSE)
        window = sdl.CreateWindow(settings.win_title, settings.win_w, settings.win_h, {.RESIZABLE}); assert(window != nil)
        device = sdl.CreateGPUDevice(settings.gpu_drivers, true, nil); assert(device != nil)
        ok = sdl.ClaimWindowForGPUDevice(device, window); assert(ok)
        // ok = sdl.SetWindowRelativeMouseMode(window, true); assert(ok)
    }

    // buffer data
    vertices : []VertexPos3fCol3f
    indices  : []TriangleIndex
    bytesize_vertices_pitch : u32
    bytesize_vertices_data  : u32
    bytesize_indices_data   : u32
    num_indice              : u32
    {
        // get vertices data
        {
            // On définit les 8 coins du cube (Centré sur 0,0,0)
            vertices = {
                // --- FACE AVANT (Z = 1.0) ---
                {{-1.0, -1.0,  1.0}, {1.0, 0.0, 0.0}}, // 0. Bas-Gauche (Rouge)
                {{ 1.0, -1.0,  1.0}, {0.0, 1.0, 0.0}}, // 1. Bas-Droite (Vert)
                {{ 1.0,  1.0,  1.0}, {0.0, 0.0, 1.0}}, // 2. Haut-Droite (Bleu)
                {{-1.0,  1.0,  1.0}, {1.0, 1.0, 0.0}}, // 3. Haut-Gauche (Jaune)
            }

            bytesize_vertices_pitch = u32(size_of(vertices[0]))
            bytesize_vertices_data = bytesize_vertices_pitch * u32(len(vertices))
        }

        // get indices data
        {
            indices = {
                {0, 1, 2},
                {2, 3, 0}
            }

            bytesize_indices_data = u32(size_of(indices[0]) * len(indices))
            num_indice = u32(len(indices) * len(TriangleIndex))
        }
    }

    // create gpu buffers
    vbuffer : ^sdl.GPUBuffer
    ibuffer : ^sdl.GPUBuffer
    defer sdl.ReleaseGPUBuffer(device, vbuffer)
    defer sdl.ReleaseGPUBuffer(device, ibuffer)
    {
        //defer delete(vertices)
        //defer delete(indices)

        // alloc buffer's gpu memory
        {
            // vertex buffer
            vbuffer = sdl.CreateGPUBuffer(device, {
                usage = {.VERTEX},
                size = bytesize_vertices_data
            })

            // index buffer
            ibuffer = sdl.CreateGPUBuffer(device, {
                usage = {.INDEX},
                size = bytesize_indices_data
            })
        }

        // alloc buffer's transfer memory
        tbuffer : ^sdl.GPUTransferBuffer
        defer sdl.ReleaseGPUTransferBuffer(device, tbuffer)
        {
            tbuffer = sdl.CreateGPUTransferBuffer(device, {
                usage = .UPLOAD,
                size = bytesize_vertices_data + bytesize_indices_data
            }); assert(tbuffer != nil)
        }

        // transfer buffer data to transfer memory
        {
            tmemory := transmute([^]byte)sdl.MapGPUTransferBuffer(device, tbuffer, false)
            mem.copy(tmemory, raw_data(vertices), int(bytesize_vertices_data))
            mem.copy(tmemory[bytesize_vertices_data:], raw_data(indices), int(bytesize_indices_data))
            sdl.UnmapGPUTransferBuffer(device, tbuffer)
        }

        // copy data to gpu
        {
            cmd := sdl.AcquireGPUCommandBuffer(device); assert(cmd != nil)
            defer {ok = sdl.SubmitGPUCommandBuffer(cmd); assert(ok)}
            cps := sdl.BeginGPUCopyPass(cmd); assert(cps != nil)
            {
                defer sdl.EndGPUCopyPass(cps)

                // copy buffer data to the gpu (vbuffer)
                {
                    // vertex buffer
                    sdl.UploadToGPUBuffer(cps, {
                        transfer_buffer = tbuffer,
                        offset = 0
                    }, {
                        buffer = vbuffer,
                        offset = 0,
                        size = bytesize_vertices_data
                    }, false)

                    // index buffer
                    sdl.UploadToGPUBuffer(cps, {
                        transfer_buffer = tbuffer,
                        offset = bytesize_vertices_data
                    }, {
                        buffer = ibuffer,
                        offset = 0,
                        size = bytesize_indices_data
                    }, false)
                }
            }
        }
    }

    // create gpipeline
    /* var */ num_vubuffer := u32(1)
    gpipeline : ^sdl.GPUGraphicsPipeline
    defer sdl.ReleaseGPUGraphicsPipeline(device, gpipeline)
    {
        // create shaders
        vshader : ^sdl.GPUShader
        fshader : ^sdl.GPUShader
        defer sdl.ReleaseGPUShader(device, vshader)
        defer sdl.ReleaseGPUShader(device, fshader)
        {
            vshader_code := #load("../shaders/compiled_spirv/shader.vert.spirv", []byte)
            fshader_code := #load("../shaders/compiled_spirv/shader.pixl.spirv", []byte)
            vcode_size := uint(len(vshader_code))
            fcode_size := uint(len(fshader_code))
            ventrypoint := cstring("vs_main")
            fentrypoint := cstring("ps_main")

            vshader = sdl.CreateGPUShader(device, sdl.GPUShaderCreateInfo{
                code_size = vcode_size,
                code = raw_data(vshader_code),
                entrypoint = ventrypoint,
                format = settings.gpu_drivers,
                stage = .VERTEX,
                num_uniform_buffers = num_vubuffer
            }); assert(vshader != nil)

            fshader = sdl.CreateGPUShader(device, sdl.GPUShaderCreateInfo{
                code_size = fcode_size,
                code = raw_data(fshader_code),
                entrypoint = fentrypoint,
                format = settings.gpu_drivers,
                stage = .FRAGMENT,
            }); assert(fshader != nil)
        }

        vertex_input_state : sdl.GPUVertexInputState
        {
            list_buffer_desc : []sdl.GPUVertexBufferDescription
            {
                list_buffer_desc = {
                    {
                        slot = 0, 
                        pitch = bytesize_vertices_pitch
                    }
                }
            }

            list_vertex_attr : []sdl.GPUVertexAttribute
            {
                list_vertex_attr = {
                    {
                        location = 0,
                        format = .FLOAT3,
                        offset = u32(offset_of(VertexPos3fCol3f, pos))
                    },
                    {
                        location = 1,
                        format = .FLOAT3,
                        offset = u32(offset_of(VertexPos3fCol3f, col))
                    }
                }
            }

            vertex_input_state = { 
                vertex_buffer_descriptions = raw_data(list_buffer_desc),
                num_vertex_buffers = u32(len(list_buffer_desc)),
                vertex_attributes = raw_data(list_vertex_attr),
                num_vertex_attributes = u32(len(list_vertex_attr)),
            }
        }

        gpipeline = sdl.CreateGPUGraphicsPipeline(device, sdl.GPUGraphicsPipelineCreateInfo{
            vertex_shader = vshader,
            fragment_shader = fshader,
            vertex_input_state = vertex_input_state,
            target_info = sdl.GPUGraphicsPipelineTargetInfo{
                color_target_descriptions = &sdl.GPUColorTargetDescription{
                    format = sdl.GetGPUSwapchainTextureFormat(device, window)
                },
                num_color_targets = 1
            }
        }); assert(gpipeline != nil)
    }


    // Loop
    {
        game_loop := true
        last_tick : u64
        new_tick : u64
        delta_time : f32
        current_time := f32(0.0)

        for game_loop {
            mouse_moved := false
            event : sdl.Event
            for sdl.PollEvent(&event) {
                if event.type == .QUIT do game_loop = false

                if event.type == .WINDOW_RESIZED {
                    ww, wh : i32
                    sdl.GetWindowSize(window, &ww, &wh)
                    aspect := f32(ww)/f32(wh)
                    settings.perspertive = linalg.matrix4_perspective_f32(linalg.to_radians(f32(45.0)), aspect, 0.0001, 1000.0, false)
                    settings.win_w = ww
                    settings.win_h = wh
                }

                
            }
            
            // update time
            {
                new_tick = sdl.GetTicks()
                delta_time = f32(new_tick - last_tick) / 1000.0
                last_tick = new_tick
                current_time += delta_time
            }

            // update mouse state 
            if mouse_moved {
                log.debug(mouse_moved)
            }

            // update logic
            {
                // view camera
                {

                }
            }

            // draw 
            {
                cmd := sdl.AcquireGPUCommandBuffer(device); assert(cmd != nil)
                swp : ^sdl.GPUTexture; ok = sdl.WaitAndAcquireGPUSwapchainTexture(cmd, window, &swp, nil, nil); assert(ok)
                defer {ok = sdl.SubmitGPUCommandBuffer(cmd); assert(ok)}

                rps := sdl.BeginGPURenderPass(cmd, &sdl.GPUColorTargetInfo{
                    texture = swp, 
                    clear_color = {0.1, 0.1, 0.1, 1.0}, 
                    load_op = .CLEAR, 
                    store_op = .STORE
                }, 1, nil); assert(rps != nil)
                defer sdl.EndGPURenderPass(rps)
                {
                    // 1. Définir la caméra
                    // On place la caméra en arrière (Z=5) et un peu en haut (Y=2)
                    camera_pos    := Vec3f32{0.0, 0.0, 5.0}  
                    camera_target := Vec3f32{0.0, 0.0, 0.0} // On regarde l'origine (0,0,0)
                    camera_up     := Vec3f32{0.0, 1.0, 0.0} // Le haut est Y

                    // 2. Créer la View Matrix avec LookAt
                    // Note: linalg.matrix4_look_at_f32 crée l'inverse de la transformation caméra automatiquement
                    view_matrix := linalg.matrix4_look_at_f32(camera_pos, camera_target, camera_up)

                    // 3. Calculer View-Projection (pour l'envoyer au shader)
                    // Ordre de multiplication : Projection * View
                    view_proj := settings.perspertive * view_matrix

                    sdl.BindGPUGraphicsPipeline(rps, gpipeline)

                    // 4. Rendu du Cube
                    // IMPORTANT : J'ai mis le cube à {0,0,0} pour qu'il soit bien au centre de la vue
                    cube0 := Cube{
                        pos = {0.0, 0.0, 0.0}, 
                        rot = {current_time, current_time * 0.5, 0},
                        scl = {1.0, 1.0, 1.0},
                    }

                    // On passe 'view_proj' comme paramètre 'prsp'
                    cube_render(cube0, CubeRendInfo{ // Note: J'ai ajouté '&' car tes procs demandent #by_ptr
                        cmd = cmd,
                        rps = rps,
                        vbuffer = vbuffer,
                        ibuffer = ibuffer,
                        prsp = view_proj,
                        num_indice = num_indice
                    })
                }
            }
        }
    }
}