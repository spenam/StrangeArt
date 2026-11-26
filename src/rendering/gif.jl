"""
    _GifColor(red, green, blue)

RGB entry matching giflib's three-byte color table representation.
"""
struct _GifColor
    red::UInt8
    green::UInt8
    blue::UInt8
end

const _GIF_FONT = Dict{Char, NTuple{5, String}}(
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
    'd' => ("001", "001", "011", "101", "011"),
    'e' => ("000", "010", "111", "100", "011"),
    'h' => ("100", "100", "110", "101", "101"),
    'o' => ("000", "010", "101", "101", "010"),
    'r' => ("000", "110", "101", "100", "100"),
    ' ' => ("000", "000", "000", "000", "000"),
    '=' => ("000", "111", "000", "111", "000"),
    '.' => ("000", "000", "000", "000", "010"),
    '-' => ("000", "000", "111", "000", "000"),
    '+' => ("000", "010", "111", "010", "000"),
)

function _gif_palette()
    palette = Vector{_GifColor}(undef, 256)
    palette[1] = _GifColor(0x0b, 0x10, 0x20)
    for level in 0:254
        brightness = level / 254
        palette[level + 2] = _GifColor(
            UInt8(round(Int, 35 + 172brightness)),
            UInt8(round(Int, 22 + 134brightness)),
            UInt8(round(Int, 78 + 177brightness)),
        )
    end
    return palette
end

"""
    _draw_gif_text!(image, label)

Draw a compact parameter label using the GIF's brightest palette entry.
"""
function _draw_gif_text!(image, label)
    x_start, y_start, scale = 7, 5, 2
    for (character_index, character) in enumerate(label)
        glyph = get(_GIF_FONT, character, nothing)
        glyph === nothing && throw(ArgumentError("unsupported GIF label character: $character"))
        x_offset = x_start + (character_index - 1) * 4scale
        for (row, pattern) in enumerate(glyph), (column, pixel) in enumerate(pattern)
            pixel == '1' || continue
            for dy in 0:(scale - 1), dx in 0:(scale - 1)
                image[y_start + (row - 1) * scale + dy,
                      x_offset + (column - 1) * scale + dx] = 0xff
            end
        end
    end
    return image
end

"""
    _render_gif_frame(points, bounds, width, height, label)

Rasterize one density plot using the shared bounds for a parameter sweep.
"""
function _render_gif_frame(points, bounds, width, height, label)
    x_min, x_max, y_min, y_max = bounds
    x_span, y_span = max(x_max - x_min, eps()), max(y_max - y_min, eps())
    margin_x, margin_top, margin_bottom = 12, 20, 12
    plot_width = width - 2margin_x
    plot_height = height - margin_top - margin_bottom
    density = zeros(UInt32, height, width)

    for (x, y) in points
        pixel_x = margin_x + 1 + round(Int, (x - x_min) / x_span * (plot_width - 1))
        pixel_y = height - margin_bottom -
                  round(Int, (y - y_min) / y_span * (plot_height - 1))
        for dy in -1:1, dx in -1:1
            xx, yy = pixel_x + dx, pixel_y + dy
            if 1 <= xx <= width && margin_top <= yy <= height - margin_bottom
                density[yy, xx] += 1
            end
        end
    end

    image = zeros(UInt8, height, width)
    for index in eachindex(density)
        count = density[index]
        if count > 0
            image[index] = UInt8(clamp(round(Int, 56 * log2(count + 1)), 1, 255))
        end
    end

    return _draw_gif_text!(image, label)
end

function _check_gif_status(status, action)
    status == 1 || throw(ErrorException("GIF encoding failed while trying to $action"))
    return nothing
end

"""
    _write_gif_extension(gif, code, blocks)

Write one GIF extension record with one or more data sub-blocks.
"""
function _write_gif_extension(gif, code, blocks)
    _check_gif_status(
        ccall((:EGifPutExtensionLeader, libgif), Cint, (Ptr{Cvoid}, Cint), gif, code),
        "write an extension",
    )
    for block in blocks
        length(block) <= 255 || throw(ArgumentError("GIF extension blocks cannot exceed 255 bytes"))
        GC.@preserve block begin
            _check_gif_status(
                ccall(
                    (:EGifPutExtensionBlock, libgif),
                    Cint,
                    (Ptr{Cvoid}, Cint, Ptr{Cvoid}),
                    gif,
                    length(block),
                    pointer(block),
                ),
                "write an extension block",
            )
        end
    end
    _check_gif_status(
        ccall((:EGifPutExtensionTrailer, libgif), Cint, (Ptr{Cvoid},), gif),
        "finish an extension",
    )
end

"""
    _encode_gif(path, frames; frame_delay=8, palette=_gif_palette())

Encode indexed animation frames as a looping GIF with a shared 256-color palette.
"""
function _encode_gif(
    path,
    frames;
    frame_delay=8,
    palette::Vector{_GifColor}=_gif_palette(),
)
    height, width, frame_count = size(frames)
    frame_count > 0 || throw(ArgumentError("GIF must contain at least one frame"))
    1 <= width <= typemax(UInt16) || throw(ArgumentError("GIF width is out of range"))
    1 <= height <= typemax(UInt16) || throw(ArgumentError("GIF height is out of range"))
    1 <= frame_delay <= typemax(UInt16) ||
        throw(ArgumentError("frame delay must be between 1 and 65535 centiseconds"))
    length(palette) == 256 ||
        throw(ArgumentError("GIF palette must contain exactly 256 colors"))

    color_map = GC.@preserve palette begin
        ccall(
            (:GifMakeMapObject, libgif),
            Ptr{Cvoid},
            (Cint, Ptr{_GifColor}),
            length(palette),
            pointer(palette),
        )
    end
    color_map == C_NULL && throw(ErrorException("giflib could not create the color table"))

    filename = String(path)
    open_error = Ref{Cint}(0)
    gif = ccall(
        (:EGifOpenFileName, libgif),
        Ptr{Cvoid},
        (Cstring, Bool, Ref{Cint}),
        filename,
        false,
        open_error,
    )
    if gif == C_NULL
        ccall((:GifFreeMapObject, libgif), Cvoid, (Ptr{Cvoid},), color_map)
        throw(ErrorException("giflib could not open '$filename' (error $(open_error[]) )"))
    end

    try
        ccall((:EGifSetGifVersion, libgif), Cvoid, (Ptr{Cvoid}, Bool), gif, true)
        _check_gif_status(
            ccall(
                (:EGifPutScreenDesc, libgif),
                Cint,
                (Ptr{Cvoid}, Cint, Cint, Cint, Cint, Ptr{Cvoid}),
                gif,
                width,
                height,
                8,
                0,
                color_map,
            ),
            "write the screen descriptor",
        )
        _write_gif_extension(
            gif,
            0xff,
            [collect(codeunits("NETSCAPE2.0")), UInt8[0x01, 0x00, 0x00]],
        )

        for frame_index in 1:frame_count
            delay_block = UInt8[
                0x00,
                frame_delay & 0xff,
                (frame_delay >> 8) & 0xff,
                0x00,
            ]
            _write_gif_extension(gif, 0xf9, [delay_block])
            _check_gif_status(
                ccall(
                    (:EGifPutImageDesc, libgif),
                    Cint,
                    (Ptr{Cvoid}, Cint, Cint, Cint, Cint, Bool, Ptr{Cvoid}),
                    gif,
                    0,
                    0,
                    width,
                    height,
                    false,
                    C_NULL,
                ),
                "write a frame descriptor",
            )
            for row_index in 1:height
                row = collect(@view frames[row_index, :, frame_index])
                GC.@preserve row begin
                    _check_gif_status(
                        ccall(
                            (:EGifPutLine, libgif),
                            Cint,
                            (Ptr{Cvoid}, Ptr{UInt8}, Cint),
                            gif,
                            pointer(row),
                            width,
                        ),
                        "write a frame row",
                    )
                end
            end
        end
    finally
        close_error = Ref{Cint}(0)
        close_status = ccall(
            (:EGifCloseFile, libgif),
            Cint,
            (Ptr{Cvoid}, Ref{Cint}),
            gif,
            close_error,
        )
        ccall((:GifFreeMapObject, libgif), Cvoid, (Ptr{Cvoid},), color_map)
        _check_gif_status(close_status, "close the GIF file")
    end

    return path
end
