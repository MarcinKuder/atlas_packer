# Atlas Packer

A small texture atlas packer written in Odin. 
It scans an input directory for images and fonts, packs them into a single PNG atlas file and generates an Odin source file with the sprites and glyphs coordinates.

Packing many sprites into one texture lets the GPU draw them in a single batch and one bind, which cuts draw calls resulting in much better rendering performance.

## Features

- Supports PNG images, TrueType (.ttf) fonts, and Aseprite (work-in-progress) files
- Auto-sizes the atlas (with per-source padding to prevent bleeding)
- Generates atlas.odin with texture enums and glyphs maps

## Usage

1. Put your assets into input/ folder.
2. Run:
```odin run .```
3. Results are generated in the output/ folder.
4. Copy both files into your game project.
5. Sprites can be accessed via ```atlas_textures[.SomeSprite]```;  glyphs via ```atlas_glyphs['A']```.

## License

MIT
