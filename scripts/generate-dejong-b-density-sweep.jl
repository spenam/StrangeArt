include(joinpath(@__DIR__, "..", "src", "StrangeArt.jl"))
using .StrangeArt

const OUTPUT_DIR = joinpath(@__DIR__, "..", "generated-art")
const FRAMES_DIR = joinpath(OUTPUT_DIR, "dejong-b-density-frames")
const OUTPUT_PATH = joinpath(OUTPUT_DIR, "dejong-b-density.gif")
const A_VALUE = 1.3
const B_VALUES = range(1.5, 2.5; length=100)
const C_VALUE = 2.4
const D_VALUE = -2.1
const POINTS_PER_FRAME = 900_000
const WIDTH = 800
const HEIGHT = 600
const BOUNDS = (-2.0, 2.0, -2.0, 2.0)
const DPI = 300

function palette_colors()
    colors = Vector{NTuple{3, UInt8}}(undef, 256)
    colors[1] = (0x0b, 0x10, 0x20)
    for index in 0:254
        colors[index + 2] =
            StrangeArt._hex_rgb(StrangeArt._perceptual_palette_color(index / 254))
    end
    return colors
end

function gif_palette(colors)
    return StrangeArt._GifColor[
        StrangeArt._GifColor(color...) for color in colors
    ]
end

function quantize_color(rgb, colors, cache)
    return get!(cache, rgb) do
        if rgb == colors[1]
            0x00
        else
            best_index = 1
            best_distance = typemax(Int)
            for index in 1:255
                color = colors[index + 1]
                distance =
                    (Int(rgb[1]) - Int(color[1]))^2 +
                    (Int(rgb[2]) - Int(color[2]))^2 +
                    (Int(rgb[3]) - Int(color[3]))^2
                if distance < best_distance
                    best_index = index
                    best_distance = distance
                end
            end
            UInt8(best_index)
        end
    end
end

function indexed_frame(pixels, colors, cache)
    height, width, _ = size(pixels)
    indexed = Matrix{UInt8}(undef, height, width)
    for y in 1:height, x in 1:width
        rgb = (pixels[y, x, 1], pixels[y, x, 2], pixels[y, x, 3])
        indexed[y, x] = quantize_color(rgb, colors, cache)
    end
    return indexed
end

function write_png_frame(path, pixels)
    scanlines = StrangeArt._png_scanlines(pixels)
    compressed = StrangeArt._zlib_compress(scanlines)
    pixels_per_meter = StrangeArt._png_pixels_per_meter(DPI)
    StrangeArt._write_png(path, compressed, WIDTH, HEIGHT, pixels_per_meter)
end

function density_pixels(points)
    plot_size = min(WIDTH, HEIGHT)
    grid = density_grid(
        points;
        width=plot_size,
        height=plot_size,
        bounds=BOUNDS,
    )
    plot = StrangeArt._density_png_pixels(grid, :log)
    pixels = Array{UInt8, 3}(undef, HEIGHT, WIDTH, 3)
    pixels[:, :, 1] .= 0x0b
    pixels[:, :, 2] .= 0x10
    pixels[:, :, 3] .= 0x20
    left = div(WIDTH - plot_size, 2) + 1
    pixels[:, left:(left + plot_size - 1), :] .= plot
    return pixels
end

"""
    generate_dejong_b_density_sweep()

Render the density of the de Jong map for each `b` value and assemble the PNG
frames into a GIF. The frame label displays all four map parameters.
"""
function generate_dejong_b_density_sweep()
    mkpath(FRAMES_DIR)
    colors = palette_colors()
    palette = gif_palette(colors)
    quantized_colors = Dict{NTuple{3, UInt8}, UInt8}()
    frames = Array{UInt8, 3}(undef, HEIGHT, WIDTH, length(B_VALUES))

    for (frame_index, b) in enumerate(B_VALUES)
        points = dejong_points(;
            a=A_VALUE,
            b,
            c=C_VALUE,
            d=D_VALUE,
            iterations=POINTS_PER_FRAME,
        )
        pixels = density_pixels(points)
        png_path = joinpath(FRAMES_DIR, "frame-$(lpad(frame_index, 3, '0')).png")
        write_png_frame(png_path, pixels)
        indexed = indexed_frame(pixels, colors, quantized_colors)
        label = "a=$A_VALUE b=$(round(b; sigdigits=3)) c=$C_VALUE d=$D_VALUE"
        StrangeArt._draw_gif_text!(indexed, label)
        frames[:, :, frame_index] = indexed
        println("Rendered frame $frame_index/$(length(B_VALUES))")
    end

    StrangeArt._encode_gif(OUTPUT_PATH, frames; frame_delay=8, palette)
    println("Wrote $OUTPUT_PATH")
end

generate_dejong_b_density_sweep()
