"""
    write_sweep_png(path, points; color_values, colorbar_label="parameter",
                    width=2400, height=2400, dpi=300, bounds=nothing)

Rasterize a parameter-colored point cloud into an RGB PNG. The labeled scale
uses the same perceptually uniform palette as the SVG renderer. `dpi` is
written into the PNG physical-resolution metadata.
`bounds`, when supplied as `(x_min, x_max, y_min, y_max)`, keeps the plot
scale fixed across related images.
"""
function write_sweep_png(
    path::AbstractString,
    points::AbstractVector{<:Tuple};
    color_values::AbstractVector{<:Real},
    colorbar_label::AbstractString="parameter",
    width::Integer=2400,
    height::Integer=2400,
    dpi::Real=300,
    bounds=nothing,
)
    endswith(lowercase(path), ".png") ||
        throw(ArgumentError("PNG output path must end in .png"))
    1 <= width <= typemax(UInt32) || throw(ArgumentError("PNG width is out of range"))
    1 <= height <= typemax(UInt32) || throw(ArgumentError("PNG height is out of range"))
    length(points) == length(color_values) ||
        throw(ArgumentError("color_values must contain one value per point"))
    !isempty(points) || throw(ArgumentError("at least one point is required"))
    all(point -> length(point) == 2 && all(value -> value isa Real && isfinite(value), point), points) ||
        throw(ArgumentError("points must contain finite 2D coordinates"))
    all(isfinite, color_values) || throw(ArgumentError("color_values must be finite"))
    isfinite(dpi) && dpi > 0 || throw(ArgumentError("dpi must be finite and positive"))

    pixels_per_meter = round(Int, dpi / 0.0254)
    1 <= pixels_per_meter <= typemax(UInt32) ||
        throw(ArgumentError("dpi is outside the PNG resolution range"))

    pixels = _sweep_png_pixels(
        points,
        color_values,
        width,
        height,
        colorbar_label;
        bounds,
    )
    scanlines = _png_scanlines(pixels)
    compressed_scanlines = _zlib_compress(scanlines)
    _write_png(path, compressed_scanlines, width, height, pixels_per_meter)
    return path
end

const _PNG_FONT = Dict{Char, NTuple{5, String}}(
    '0' => ("111", "101", "101", "101", "111"),
    '1' => ("010", "110", "010", "010", "111"),
    '2' => ("111", "001", "111", "100", "111"),
    '3' => ("111", "001", "111", "001", "111"),
    '4' => ("101", "101", "111", "001", "001"),
    '5' => ("111", "100", "111", "001", "111"),
    '6' => ("111", "100", "111", "101", "111"),
    '7' => ("111", "001", "010", "010", "010"),
    '8' => ("111", "101", "111", "101", "111"),
    '9' => ("111", "101", "111", "001", "111"),
    'a' => ("010", "001", "111", "101", "111"),
    'b' => ("100", "100", "110", "101", "110"),
    'c' => ("000", "011", "100", "100", "011"),
    'e' => ("000", "010", "111", "100", "011"),
    'h' => ("100", "100", "110", "101", "101"),
    'o' => ("000", "010", "101", "101", "010"),
    'r' => ("000", "110", "101", "100", "100"),
    '.' => ("000", "000", "000", "000", "010"),
    '-' => ("000", "000", "111", "000", "000"),
    '+' => ("000", "010", "111", "010", "000"),
)

function _hex_rgb(color)
    return ntuple(channel -> parse(UInt8, color[(2 + 2(channel - 1)):(3 + 2(channel - 1))]; base=16), 3)
end

function _sweep_png_pixels(points, color_values, width, height, colorbar_label; bounds=nothing)
    if bounds === nothing
        x_min = minimum(point[1] for point in points)
        x_max = maximum(point[1] for point in points)
        y_min = minimum(point[2] for point in points)
        y_max = maximum(point[2] for point in points)
    else
        bounds isa Tuple && length(bounds) == 4 ||
            throw(ArgumentError("bounds must be (x_min, x_max, y_min, y_max)"))
        all(value -> value isa Real && isfinite(value), bounds) ||
            throw(ArgumentError("bounds must contain finite values"))
        x_min, x_max, y_min, y_max = Float64.(bounds)
        all(isfinite, (x_min, x_max, y_min, y_max)) ||
            throw(ArgumentError("bounds must be representable as finite Float64 values"))
        x_min < x_max && y_min < y_max ||
            throw(ArgumentError("bounds must have increasing minimum and maximum values"))
    end
    x_span, y_span = max(x_max - x_min, eps()), max(y_max - y_min, eps())

    margin = max(12, round(Int, min(width, height) * 0.04))
    legend_width = max(110, round(Int, width * 0.16))
    plot_width = width - 2margin - legend_width
    plot_height = height - 2margin
    plot_width > 0 && plot_height > 0 ||
        throw(ArgumentError("PNG dimensions are too small for the color legend"))

    pixels = Array{UInt8, 3}(undef, height, width, 3)
    pixels[:, :, 1] .= 0x0b
    pixels[:, :, 2] .= 0x10
    pixels[:, :, 3] .= 0x20
    lower_value, upper_value = extrema(color_values)
    color_lookup = Dict{Float64, NTuple{3, UInt8}}()
    for value in unique(Float64[value for value in color_values])
        position = lower_value == upper_value ? 0.5 :
                   (value - lower_value) / (upper_value - lower_value)
        color_lookup[value] = _hex_rgb(_perceptual_palette_color(position))
    end

    radius = max(1, round(Int, min(width, height) * 0.0007))
    opacity = 0.38
    for ((x, y), value) in zip(points, color_values)
        pixel_x = margin + 1 + round(Int, (x - x_min) / x_span * (plot_width - 1))
        pixel_y = height - margin -
                  round(Int, (y - y_min) / y_span * (plot_height - 1))
        color = color_lookup[Float64(value)]
        for dy in -radius:radius, dx in -radius:radius
            dx^2 + dy^2 <= radius^2 || continue
            xx, yy = pixel_x + dx, pixel_y + dy
            if 1 <= xx <= width && 1 <= yy <= height
                for channel in 1:3
                    old = pixels[yy, xx, channel]
                    pixels[yy, xx, channel] =
                        UInt8(round(Int, (1 - opacity) * old + opacity * color[channel]))
                end
            end
        end
    end

    _draw_png_colorbar!(pixels, colorbar_label, lower_value, upper_value, margin)
    return pixels
end

function _draw_png_colorbar!(pixels, label, lower, upper, margin)
    height, width, _ = size(pixels)
    scale = max(1, round(Int, min(width, height) / 400))
    legend_width = max(110, round(Int, width * 0.16))
    bar_x = width - margin - legend_width + 20scale
    bar_y = margin + 14scale
    bar_width = 6scale
    bar_height = height - 2margin - 54scale
    bar_height > 0 || throw(ArgumentError("PNG height is too small for the color legend"))
    text_color = (0xe5, 0xe7, 0xeb)

    _draw_png_text!(pixels, label, bar_x, margin + 2scale, text_color, scale)
    for offset in 0:(bar_height - 1)
        position = 1 - offset / max(bar_height - 1, 1)
        color = _hex_rgb(_perceptual_palette_color(position))
        for x in bar_x:(bar_x + bar_width - 1), channel in 1:3
            pixels[bar_y + offset, x, channel] = color[channel]
        end
    end
    _draw_png_text!(
        pixels,
        string(round(upper; sigdigits=4)),
        bar_x + bar_width + 3scale,
        bar_y,
        text_color,
        scale,
    )
    _draw_png_text!(
        pixels,
        string(round(lower; sigdigits=4)),
        bar_x + bar_width + 3scale,
        bar_y + bar_height - 5scale,
        text_color,
        scale,
    )
    return pixels
end

function _draw_png_text!(pixels, text, x, y, color, scale)
    height, width, _ = size(pixels)
    cursor_x = x
    for character in text
        glyph = get(_PNG_FONT, character, nothing)
        glyph === nothing && throw(ArgumentError("unsupported PNG legend character: $character"))
        for (row, pattern) in enumerate(glyph), (column, pixel) in enumerate(pattern)
            pixel == '1' || continue
            top = y + (row - 1) * scale
            left = cursor_x + (column - 1) * scale
            for dy in 0:(scale - 1), dx in 0:(scale - 1)
                yy, xx = top + dy, left + dx
                if 1 <= yy <= height && 1 <= xx <= width
                    for channel in 1:3
                        pixels[yy, xx, channel] = color[channel]
                    end
                end
            end
        end
        cursor_x += 4scale
    end
    return pixels
end

function _png_scanlines(pixels)
    height, width, _ = size(pixels)
    row_length = 1 + 3width
    scanlines = Vector{UInt8}(undef, height * row_length)
    for y in 1:height
        row_start = (y - 1) * row_length + 1
        scanlines[row_start] = 0x00
        cursor = row_start + 1
        for x in 1:width, channel in 1:3
            scanlines[cursor] = pixels[y, x, channel]
            cursor += 1
        end
    end
    return scanlines
end

function _zlib_compress(data)
    source_length = Culong(length(data))
    output_capacity = ccall((:compressBound, libz), Culong, (Culong,), source_length)
    output = Vector{UInt8}(undef, Int(output_capacity))
    output_length = Ref{Culong}(output_capacity)
    status = GC.@preserve data output begin
        ccall(
            (:compress2, libz),
            Cint,
            (Ptr{UInt8}, Ref{Culong}, Ptr{UInt8}, Culong, Cint),
            pointer(output),
            output_length,
            pointer(data),
            source_length,
            9,
        )
    end
    status == 0 || throw(ErrorException("zlib compression failed with status $status"))
    resize!(output, Int(output_length[]))
    return output
end

function _png_uint32(value)
    number = UInt32(value)
    return UInt8[
        (number >> 24) & 0xff,
        (number >> 16) & 0xff,
        (number >> 8) & 0xff,
        number & 0xff,
    ]
end

function _png_crc32(bytes)
    crc = typemax(UInt32)
    for byte in bytes
        crc ⊻= UInt32(byte)
        for _ in 1:8
            crc = isodd(crc) ? (crc >> 1) ⊻ 0xedb88320 : crc >> 1
        end
    end
    return ~crc
end

function _write_png_chunk(io, name, data)
    chunk_type = collect(codeunits(name))
    write(io, _png_uint32(length(data)))
    write(io, chunk_type)
    write(io, data)
    write(io, _png_uint32(_png_crc32(vcat(chunk_type, data))))
end

function _write_png(path, compressed_data, width, height, pixels_per_meter)
    open(path, "w") do io
        write(io, UInt8[0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])

        header = vcat(_png_uint32(width), _png_uint32(height), UInt8[8, 2, 0, 0, 0])
        _write_png_chunk(io, "IHDR", header)

        physical_resolution = vcat(
            _png_uint32(pixels_per_meter),
            _png_uint32(pixels_per_meter),
            UInt8[1],
        )
        _write_png_chunk(io, "pHYs", physical_resolution)
        _write_png_chunk(io, "IDAT", compressed_data)
        _write_png_chunk(io, "IEND", UInt8[])
    end
    return path
end
