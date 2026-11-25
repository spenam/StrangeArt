include(joinpath(@__DIR__, "..", "src", "StrangeArt.jl"))
using .StrangeArt

const OUTPUT_DIR = joinpath(@__DIR__, "..", "generated-art")
const FRAMES_DIR = joinpath(OUTPUT_DIR, "dejong-b-sweep-frames")
const OUTPUT_PATH = joinpath(OUTPUT_DIR, "dejong-b-sweep.gif")
const A_VALUES = range(-2.6, -1.9; length=40)
const B_VALUES = range(-2.5, 2.5; length=60)
const POINTS_PER_A = 10_000
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

function write_png_frame(path, pixels)
    scanlines = StrangeArt._png_scanlines(pixels)
    compressed = StrangeArt._zlib_compress(scanlines)
    pixels_per_meter = round(Int, DPI / 0.0254)
    StrangeArt._write_png(path, compressed, WIDTH, HEIGHT, pixels_per_meter)
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

"""
    generate_dejong_b_sweep()

Render the color-coded `a` sweep at each `b` value and assemble a GIF.
"""
function generate_dejong_b_sweep()
    mkpath(FRAMES_DIR)
    colors = palette_colors()
    palette = gif_palette(colors)
    quantized_colors = Dict{NTuple{3, UInt8}, UInt8}()
    frames = Array{UInt8, 3}(undef, HEIGHT, WIDTH, length(B_VALUES))

    for (frame_index, b) in enumerate(B_VALUES)
        points = NTuple{2, Float64}[]
        color_values = Float64[]
        for a in A_VALUES
            orbit = dejong_points(; a, b, iterations=POINTS_PER_A)
            append!(points, orbit)
            append!(color_values, fill(a, length(orbit)))
        end

        pixels = StrangeArt._sweep_png_pixels(
            points,
            color_values,
            WIDTH,
            HEIGHT,
            "a";
            bounds=BOUNDS,
        )
        png_path = joinpath(FRAMES_DIR, "frame-$(lpad(frame_index, 3, '0')).png")
        write_png_frame(png_path, pixels)
        indexed = indexed_frame(pixels, colors, quantized_colors)
        StrangeArt._draw_gif_text!(indexed, "b=$(round(b; sigdigits=3))")
        frames[:, :, frame_index] = indexed
        println("Rendered frame $frame_index/$(length(B_VALUES))")
    end

    StrangeArt._encode_gif(OUTPUT_PATH, frames; frame_delay=8, palette)
    println("Wrote $OUTPUT_PATH")
end

generate_dejong_b_sweep()
