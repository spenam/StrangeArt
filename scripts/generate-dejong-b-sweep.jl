include(joinpath(@__DIR__, "..", "src", "StrangeArt.jl"))
using .StrangeArt
using Zlib_jll: libz

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

function read_uint32(bytes, index)
    return (UInt32(bytes[index]) << 24) |
           (UInt32(bytes[index + 1]) << 16) |
           (UInt32(bytes[index + 2]) << 8) |
           UInt32(bytes[index + 3])
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

function read_png_frame(path, colors, cache)
    bytes = read(path)
    bytes[1:8] == UInt8[0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a] ||
        throw(ArgumentError("invalid PNG signature in $path"))

    width = 0
    height = 0
    compressed = UInt8[]
    offset = 9
    while offset <= length(bytes)
        chunk_size = Int(read_uint32(bytes, offset))
        chunk_name = String(bytes[(offset + 4):(offset + 7)])
        data_start = offset + 8
        data_end = data_start + chunk_size - 1

        if chunk_name == "IHDR"
            width = Int(read_uint32(bytes, data_start))
            height = Int(read_uint32(bytes, data_start + 4))
            bytes[data_start + 8] == 8 && bytes[data_start + 9] == 2 &&
                bytes[data_start + 12] == 0 ||
                throw(ArgumentError("expected a non-interlaced RGB PNG: $path"))
        elseif chunk_name == "IDAT"
            append!(compressed, @view bytes[data_start:data_end])
        elseif chunk_name == "IEND"
            break
        end

        offset += chunk_size + 12
    end

    width > 0 && height > 0 && !isempty(compressed) ||
        throw(ArgumentError("PNG is missing image data: $path"))
    expected_size = height * (1 + 3width)
    raw = Vector{UInt8}(undef, expected_size)
    raw_size = Ref{Culong}(Culong(expected_size))
    status = GC.@preserve compressed raw begin
        ccall(
            (:uncompress, libz),
            Cint,
            (Ptr{UInt8}, Ref{Culong}, Ptr{UInt8}, Culong),
            pointer(raw),
            raw_size,
            pointer(compressed),
            Culong(length(compressed)),
        )
    end
    status == 0 || throw(ErrorException("failed to decompress PNG frame $path"))
    raw_size[] == expected_size ||
        throw(ArgumentError("unexpected decompressed PNG size in $path"))

    indexed = Matrix{UInt8}(undef, height, width)
    for y in 1:height
        row_start = (y - 1) * (1 + 3width) + 1
        raw[row_start] == 0 || throw(ArgumentError("unsupported PNG row filter in $path"))
        for x in 1:width
            pixel_start = row_start + 1 + 3(x - 1)
            rgb = (raw[pixel_start], raw[pixel_start + 1], raw[pixel_start + 2])
            indexed[y, x] = quantize_color(rgb, colors, cache)
        end
    end
    return indexed
end

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

        png_path = joinpath(FRAMES_DIR, "frame-$(lpad(frame_index, 3, '0')).png")
        write_sweep_png(
            png_path,
            points;
            color_values,
            colorbar_label="a",
            width=WIDTH,
            height=HEIGHT,
            dpi=DPI,
            bounds=BOUNDS,
        )
        indexed = read_png_frame(png_path, colors, quantized_colors)
        StrangeArt._draw_gif_text!(indexed, "b=$(round(b; sigdigits=3))")
        frames[:, :, frame_index] = indexed
        println("Rendered frame $frame_index/$(length(B_VALUES))")
    end

    StrangeArt._encode_gif(OUTPUT_PATH, frames; frame_delay=8, palette)
    println("Wrote $OUTPUT_PATH")
end

generate_dejong_b_sweep()
