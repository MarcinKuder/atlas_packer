package atlas_packer

import "core:encoding/endian"
import "core:fmt"
import "core:os"

Reader :: struct {
    data: []u8,
    pos:  int,
}

AseColorDepth :: enum u16 {
    Indexed   = 8,
    Grayscale = 16,
    RGBA      = 32,
}

AseHeader :: struct {
    frames:            int,
    width:             int,
    height:            int,
    color_depth:       AseColorDepth,
    transparent_index: int,
    number_of_colors:  int,
}

skip :: proc(r: ^Reader, n: int) {
    r.pos += n
}

seek :: proc(r: ^Reader, abs: int) {
    r.pos = abs
}

// BYTE
read_u8 :: proc(r: ^Reader) -> u8 {
    v := r.data[r.pos]
    r.pos += 1
    return v
}

// WORD
read_u16 :: proc(r: ^Reader) -> u16 {
    v, _ := endian.get_u16(r.data[r.pos:], .Little)
    r.pos += 2
    return v
}

// DWORD
read_u32 :: proc(r: ^Reader) -> u32 {
    v, _ := endian.get_u32(r.data[r.pos:], .Little)
    r.pos += 4
    return v
}

// Aseprite STRING: string length (num of bytes) + characters (in UTF-8) The '\0' character is not included
read_string :: proc(r: ^Reader) -> string {
    length := int(read_u16(r))
    s := string(r.data[r.pos:r.pos + length])
    r.pos += length
    return s
}

// Reading all needed fields from the header
read_ase_header :: proc(r: ^Reader) -> (header: AseHeader, ok: bool) {
    start := r.pos

    skip(r, 4) // DWORD File size
    if read_u16(r) != 0xA5E0 {     // WORD magic number
        return {}, false
    }
    header.frames = int(read_u16(r))
    header.width = int(read_u16(r))
    header.height = int(read_u16(r))
    header.color_depth = AseColorDepth(read_u16(r))
    skip(r, 14) // skip DWORD flags, WORD speed, DWORD 0, DWORD 0
    header.transparent_index = int(read_u8(r))
    skip(r, 3) // skip BYTE[3] ignore
    header.number_of_colors = int(read_u16(r))

    seek(r, start + 128) // seek past the 128 bytes header
    return header, true
}

load_aseprite :: proc(fi: os.File_Info, sources: ^[dynamic]Source) {
    fmt.printfln("loading %s", fi.name)
    data, data_err := os.read_entire_file_from_path(fi.fullpath, context.allocator)
    defer delete(data)
    if data_err != nil {
        fmt.eprintfln("failed to read %s", fi.name)
        return
    }
    r := Reader {
        data = data,
    }

    // Header (128 bytes)
    header, ok := read_ase_header(&r)
    if !ok {
        fmt.eprintln("failed to read header")
        return
    }

    fmt.printfln("header: %v", header)

    //TODO: Layers

    //TODO: Frames
}

