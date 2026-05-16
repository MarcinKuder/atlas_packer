package pakker

import "core:crypto/chacha20"
import "core:fmt"
import "core:image"
import "core:image/png"
import "core:os"
import "core:strings"
import stb_image "vendor:stb/image"
import "vendor:stb/rect_pack"

INPUT_PATH :: "./input"
OUTPUT_PATH :: "./output"
TILESET_TAG :: "tileset"
ATLAS_SIZE :: 512


main :: proc() {
    fmt.println(":: Pakker ::")

    infos, err := os.read_all_directory_by_path(INPUT_PATH, context.allocator)
    if err != nil {
        fmt.eprintfln("read failed: %v", err)
        return
    }
    defer {
        for fi in infos do os.file_info_delete(fi, context.allocator)
        delete(infos, context.allocator)
    }

    images: [dynamic]^image.Image

    // load all png images
    for fi in infos {
        if !strings.contains(fi.name, TILESET_TAG) {
            fmt.printfln("%s", fi.name)
            data, _ := os.read_entire_file_from_path(fi.fullpath, context.allocator)
            defer delete(data)
            img, _ := png.load_from_bytes(data)
            append(&images, img)
        }
    }

    // pack rectangles - setup
    rc: rect_pack.Context
    rc_nodes: [ATLAS_SIZE]rect_pack.Node
    rect_pack.init_target(&rc, ATLAS_SIZE, ATLAS_SIZE, raw_data(rc_nodes[:]), ATLAS_SIZE)
    rects: [dynamic]rect_pack.Rect

    // build rectangles (with 1px padding)
    for img, i in images {
        append(
            &rects,
            rect_pack.Rect{id = i32(i), w = rect_pack.Coord(img.width + 1), h = rect_pack.Coord(img.height + 1)},
        )
    }

    // pack
    rect_pack.pack_rects(&rc, raw_data(rects[:]), i32(len(rects)))

    // blit image into canvas
    Color :: [4]u8

    atlas_pixels := make([]Color, ATLAS_SIZE * ATLAS_SIZE)
    defer delete(atlas_pixels)

    for rect in rects {
        img := images[rect.id]
        src := img.pixels.buf[:]
        ch := img.channels
        for sy in 0 ..< img.height {
            for sx in 0 ..< img.width {
                si := (sy * img.width + sx) * ch // source pixel byte offset
                di := (int(rect.y) + sy) * ATLAS_SIZE + (int(rect.x) + sx) // dest pixel index
                atlas_pixels[di] = Color{src[si], src[si + 1], src[si + 2], src[si + 3] if ch == 4 else 255}
            }
        }
    }

    // cleanup
    for img in images {
        png.destroy(img)
    }

    // write atlas.png
    stb_image.write_png("atlas.png", ATLAS_SIZE, ATLAS_SIZE, 4, raw_data(atlas_pixels), ATLAS_SIZE * size_of(Color))

}

