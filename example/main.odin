// Example app using atlas_packer
//
// To run this:
// 1. Run the packer ('odin run .' from the repo root)
// 2. Copy `output/atlas.odin` and `output/atlas.png` into this directory
//    (or change OUTPUT_PATH in atlas_packer.odin to point here directly)
// 3. `odin run example`

package game

import "core:fmt"
import rl "vendor:raylib"

// Embed atlas.png into the executable at compile time
ATLAS_DATA :: #load("atlas.png")

// The packer emits an int-based Rect, raylib wants f320 so converting at draw time
to_rl_rect :: proc(r: Rect) -> rl.Rectangle {
    return {f32(r.x), f32(r.y), f32(r.w), f32(r.h)}
}

// Draw a sprite from the atlas
draw_sprite :: proc(atlas: rl.Texture2D, name: Texture_Name, x, y: f32, tint := rl.WHITE) {
    texture := atlas_textures[name]
    src := to_rl_rect(texture.rect)
    dst := rl.Rectangle{x, y, f32(texture.original_size.x), f32(texture.original_size.y)}
    rl.DrawTexturePro(atlas, src, dst, {0, 0}, 0, tint)
}

main :: proc() {
    rl.InitWindow(800, 400, "atlas_packer example")
    defer rl.CloseWindow()
    rl.SetTargetFPS(60)

    atlas_image := rl.LoadImageFromMemory(".png", raw_data(ATLAS_DATA), i32(len(ATLAS_DATA)))
    atlas := rl.LoadTextureFromImage(atlas_image)
    rl.UnloadImage(atlas_image)
    defer rl.UnloadTexture(atlas)

    for !rl.WindowShouldClose() {
        rl.BeginDrawing()
        rl.ClearBackground({30, 30, 40, 255})

        x: f32 = 20
        for name in Texture_Name {
            if name == .None do continue
            texture := atlas_textures[name]
            rl.DrawText(fmt.ctprintf("%v", name), i32(x), i32(20), 10, rl.LIGHTGRAY)
            draw_sprite(atlas, name, x, 40)

            x += f32(texture.original_size.x) + 20
        }

        rl.EndDrawing()
    }
}

