package atlas_packer

import "core:c"
import "core:fmt"
import "core:image"
import "core:image/png"
import "core:mem"
import "core:os"
import "core:slice"
import "core:strings"
import stb_image "vendor:stb/image"
import "vendor:stb/rect_pack"

INPUT_PATH :: "./input"
OUTPUT_PATH :: "./output"
OUTPUT_FILE_NAME :: "atlas.png"
TILESET_TAG :: "tileset"
MAX_ATLAS_SIZE :: 8192

Color :: [4]u8

main :: proc() {
    fmt.println(":: running atlas_packer... ::")

    // scan input dir
    infos, err := os.read_all_directory_by_path(INPUT_PATH, context.allocator)
    if err != nil {
        fmt.eprintfln("read failed: %v", err)
        return
    }
    defer {
        for fi in infos do os.file_info_delete(fi, context.allocator)
        delete(infos, context.allocator)
    }

    // sort by filename so atlas layout is reproducible across machines
    slice.sort_by(infos, proc(a, b: os.File_Info) -> bool {return a.name < b.name})

    images: [dynamic]^image.Image
    defer {
        for img in images {png.destroy(img)}
        delete(images)
    }

    // load all png images
    for fi in infos {
        if strings.has_suffix(fi.name, ".png") && !strings.contains(fi.name, TILESET_TAG) {
            fmt.printfln("loading %s", fi.name)
            data, data_err := os.read_entire_file_from_path(fi.fullpath, context.allocator)
            defer delete(data)
            if data_err != nil {
                fmt.eprintfln("failed to read %s", fi.name)
                continue
            }
            img, img_err := png.load_from_bytes(data, {.alpha_add_if_missing}) // load with forcing all images to rgba
            if img_err != nil {
                fmt.eprintfln("failed to decode %s: %v", fi.name, img_err)
                continue
            }
            if img.channels != 4 || img.depth != 8 {
                fmt.eprintfln("skipping %s: need RGBA8, got %dch %dbpp", fi.name, img.channels, img.depth)
                png.destroy(img)
                continue
            }
            append(&images, img)
        }
    }

    // pack rectangles - setup
    rects: [dynamic]rect_pack.Rect
    defer delete(rects)
    total_area: int

    // build rectangles (with 1px padding to prevent bleeding)
    for img, i in images {
        append(
            &rects,
            rect_pack.Rect{id = i32(i), w = rect_pack.Coord(img.width + 1), h = rect_pack.Coord(img.height + 1)},
        )
        total_area += img.width * img.height
    }

    // estimate atlas size
    atlas_size := 128
    for atlas_size * atlas_size < total_area {
        atlas_size *= 2
    }

    // pack with retry untill all rects fit
    for {
        rc: rect_pack.Context
        rc_nodes := make([]rect_pack.Node, atlas_size)
        rect_pack.init_target(&rc, i32(atlas_size), i32(atlas_size), raw_data(rc_nodes[:]), i32(atlas_size))

        for &rect in rects {rect.was_packed = false}
        rect_pack.pack_rects(&rc, raw_data(rects[:]), i32(len(rects)))
        delete(rc_nodes)

        all_packed := true
        for rect in rects {
            if !rect.was_packed {
                all_packed = false
                break
            }
        }
        if all_packed {break}

        atlas_size *= 2

        if atlas_size > MAX_ATLAS_SIZE {
            fmt.eprintfln("error: images too large to fit into %v x %v atlas", MAX_ATLAS_SIZE, MAX_ATLAS_SIZE)
            return
        }
    }

    // blit images into atlas canvas
    atlas_pixels := make([]Color, atlas_size * atlas_size)
    defer delete(atlas_pixels)

    for rect in rects {
        img := images[rect.id]
        src := mem.slice_data_cast([]Color, img.pixels.buf[:])
        for sy in 0 ..< img.height {
            dst_row := (int(rect.y) + sy) * atlas_size + int(rect.x)
            src_row := sy * img.width
            copy(atlas_pixels[dst_row:dst_row + img.width], src[src_row:src_row + img.width])
        }
    }

    // calculate the crop
    max_x, max_y: int
    for rect in rects {
        img := images[rect.id]
        x := int(rect.x) + img.width
        y := int(rect.y) + img.height
        if x > max_x {max_x = x}
        if y > max_y {max_y = y}
    }

    // write atlas.png
    if !os.exists(OUTPUT_PATH) {
        if os.make_directory(OUTPUT_PATH) != nil {
            fmt.eprintfln("error: failed to create output directory %s", OUTPUT_PATH)
            return
        }
    }
    if stb_image.write_png(
           OUTPUT_PATH + "/" + OUTPUT_FILE_NAME,
           c.int(max_x),
           c.int(max_y),
           4,
           raw_data(atlas_pixels),
           c.int(atlas_size * size_of(Color)),
       ) ==
       0 {
        fmt.eprintfln("error: failed to write %s", OUTPUT_FILE_NAME)
    }
}

