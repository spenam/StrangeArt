"""
    write_svg(path, points; width=1000, height=1000)

Write finite 2D points to an SVG file, scaling them to fit while preserving
their aspect ratio. `width` and `height` set the output dimensions in pixels.
Pass one finite `color_values` entry per point to color the cloud with a
perceptually uniform viridis-like palette and include a labeled color scale.
Returns `path`.
"""
function write_svg(
    path::AbstractString,
    points::AbstractVector{<:Tuple};
    width::Integer=1000,
    height::Integer=1000,
    color_values::Union{Nothing, AbstractVector{<:Real}}=nothing,
    colorbar_label::AbstractString="parameter",
)
    width > 0 || throw(ArgumentError("width must be positive"))
    height > 0 || throw(ArgumentError("height must be positive"))
    all(point -> length(point) == 2 && all(value -> value isa Real && isfinite(value), point), points) ||
        throw(ArgumentError("points must contain finite 2D coordinates"))
    if color_values !== nothing
        length(color_values) == length(points) ||
            throw(ArgumentError("color_values must contain one value per point"))
        all(isfinite, color_values) ||
            throw(ArgumentError("color_values must contain finite values"))
        !isempty(color_values) ||
            throw(ArgumentError("color_values cannot be empty"))
        width >= 240 || throw(ArgumentError("colored SVG output requires width of at least 240"))
        height >= 100 || throw(ArgumentError("colored SVG output requires height of at least 100"))
    end

    margin = min(24.0, min(width, height) / 10)
    legend_width = color_values === nothing ? 0.0 : 100.0
    if isempty(points)
        x_min, x_max, y_min, y_max = -1.0, 1.0, -1.0, 1.0
    else
        x_min = minimum(point[1] for point in points)
        x_max = maximum(point[1] for point in points)
        y_min = minimum(point[2] for point in points)
        y_max = maximum(point[2] for point in points)
    end

    x_span, y_span = max(x_max - x_min, eps()), max(y_max - y_min, eps())
    available_width = max(width - 2margin - legend_width, 1)
    available_height = max(height - 2margin, 1)
    scale = min(available_width / x_span, available_height / y_span)
    x_offset = margin + (available_width - x_span * scale) / 2
    y_offset = margin + (available_height - y_span * scale) / 2
    point_colors = color_values === nothing ? nothing :
                   _colors_for_values(color_values)

    open(path, "w") do io
        print(io, "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"", width,
              "\" height=\"", height, "\" viewBox=\"0 0 ", width, " ", height, "\">\n")
        print(io, "<rect width=\"100%\" height=\"100%\" fill=\"#0b1020\"/>\n")
        for (index, (x, y)) in enumerate(points)
            cx = x_offset + (x - x_min) * scale
            cy = height - y_offset - (y - y_min) * scale
            print(io, "<circle cx=\"", round(cx; digits=2), "\" cy=\"",
                  round(cy; digits=2), "\" r=\"0.7\" fill=\"",
                  point_colors === nothing ? "#a78bfa" : point_colors[index],
                  "\" opacity=\"0.35\"/>\n")
        end
        if color_values !== nothing
            _write_svg_colorbar(
                io,
                colorbar_label,
                minimum(color_values),
                maximum(color_values),
                width,
                height,
                margin,
            )
        end
        print(io, "</svg>\n")
    end

    return path
end

"""
    _srgb_to_linear(channel)

Convert an sRGB channel to its linear-light representation.
"""
function _srgb_to_linear(channel)
    return channel <= 0.04045 ? channel / 12.92 : ((channel + 0.055) / 1.055)^2.4
end

"""
    _rgb_to_oklab(rgb)

Convert an sRGB triplet into the perceptually uniform Oklab color space.
"""
function _rgb_to_oklab(rgb)
    red, green, blue = _srgb_to_linear.(rgb)
    l_root = cbrt(0.4122214708red + 0.5363325363green + 0.0514459929blue)
    m_root = cbrt(0.2119034982red + 0.6806995451green + 0.1073969566blue)
    s_root = cbrt(0.0883024619red + 0.2817188376green + 0.6299787005blue)
    return (
        0.2104542553l_root + 0.7936177850m_root - 0.0040720468s_root,
        1.9779984951l_root - 2.4285922050m_root + 0.4505937099s_root,
        0.0259040371l_root + 0.7827717662m_root - 0.8086757660s_root,
    )
end

"""
    _oklab_to_rgb(lab)

Convert an Oklab color triplet back to displayable sRGB channels.
"""
function _oklab_to_rgb(lab)
    lightness, green_red, blue_yellow = lab
    l_root = lightness + 0.3963377774green_red + 0.2158037573blue_yellow
    m_root = lightness - 0.1055613458green_red - 0.0638541728blue_yellow
    s_root = lightness - 0.0894841775green_red - 1.2914855480blue_yellow
    l, m, s = l_root^3, m_root^3, s_root^3
    linear_rgb = (
        4.0767416621l - 3.3077115913m + 0.2309699292s,
        -1.2684380046l + 2.6097574011m - 0.3413193965s,
        -0.0041960863l - 0.7034186147m + 1.7076147010s,
    )
    return map(linear_rgb) do channel
        bounded = clamp(channel, 0.0, 1.0)
        bounded <= 0.0031308 ? 12.92bounded : 1.055bounded^(1 / 2.4) - 0.055
    end
end

const _VIRIDIS_RGB_STOPS = (
    (68 / 255, 1 / 255, 84 / 255),
    (59 / 255, 82 / 255, 139 / 255),
    (33 / 255, 145 / 255, 140 / 255),
    (94 / 255, 201 / 255, 98 / 255),
    (253 / 255, 231 / 255, 37 / 255),
)
const _VIRIDIS_OKLAB_STOPS = map(_rgb_to_oklab, _VIRIDIS_RGB_STOPS)

"""
    _oklab_stop_positions(stops)

Return normalized cumulative Oklab distances along a sequence of color stops.
"""
function _oklab_stop_positions(stops)
    positions = zeros(Float64, length(stops))
    for index in 2:length(stops)
        distance = sqrt(sum(
            abs2(stops[index][channel] - stops[index - 1][channel])
            for channel in 1:3
        ))
        positions[index] = positions[index - 1] + distance
    end
    return positions ./ last(positions)
end

const _VIRIDIS_STOP_POSITIONS = _oklab_stop_positions(_VIRIDIS_OKLAB_STOPS)

"""
    _perceptual_palette_color(position)

Sample the viridis-like palette at a uniform Oklab distance and return an SVG
hex color.
"""
function _perceptual_palette_color(position)
    stops = _VIRIDIS_OKLAB_STOPS
    normalized_position = clamp(Float64(position), 0.0, 1.0)
    stop_positions = _VIRIDIS_STOP_POSITIONS
    lower_index = clamp(
        searchsortedlast(stop_positions, normalized_position),
        1,
        length(stops) - 1,
    )
    fraction = (normalized_position - stop_positions[lower_index]) /
               (stop_positions[lower_index + 1] - stop_positions[lower_index])
    lower, upper = stops[lower_index], stops[lower_index + 1]
    lab = ntuple(index -> lower[index] + fraction * (upper[index] - lower[index]), 3)
    rgb = _oklab_to_rgb(lab)
    return "#" * join(string(round(Int, 255 * channel); base=16, pad=2) for channel in rgb)
end

"""
    _colors_for_values(values)

Map scalar values to palette colors across their observed minimum and maximum.
"""
function _colors_for_values(values)
    lower, upper = extrema(values)
    colors = Dict{Float64, String}()
    for value in unique(Float64[value for value in values])
        position = lower == upper ? 0.5 : (value - lower) / (upper - lower)
        colors[value] = _perceptual_palette_color(position)
    end
    return [colors[Float64(value)] for value in values]
end

"""
    _escape_svg_text(text)

Escape XML metacharacters before inserting user-provided text into SVG.
"""
function _escape_svg_text(text)
    return replace(
        text,
        "&" => "&amp;",
        "<" => "&lt;",
        ">" => "&gt;",
        "\"" => "&quot;",
        "'" => "&apos;",
    )
end

"""
    _write_svg_colorbar(io, label, lower, upper, width, height, margin)

Write a vertical viridis-like color scale and its numeric endpoints.
"""
function _write_svg_colorbar(io, label, lower, upper, width, height, margin)
    segments = 128
    bar_x = width - margin - 76
    bar_y = margin + 20
    bar_width = 16
    bar_height = max(height - 2margin - 44, 1)
    segment_height = bar_height / segments

    print(io, "<text x=\"", round(bar_x; digits=2), "\" y=\"",
          round(bar_y - 7; digits=2),
          "\" fill=\"#e5e7eb\" font-family=\"sans-serif\" font-size=\"12\">",
          _escape_svg_text(label), "</text>\n")
    for index in 0:(segments - 1)
        y = bar_y + index * segment_height
        color = _perceptual_palette_color(1 - index / (segments - 1))
        print(io, "<rect x=\"", bar_x, "\" y=\"", round(y; digits=2),
              "\" width=\"", bar_width, "\" height=\"",
              round(segment_height + 0.5; digits=2), "\" fill=\"", color, "\"/>\n")
    end
    print(io, "<rect x=\"", bar_x, "\" y=\"", round(bar_y; digits=2),
          "\" width=\"", bar_width, "\" height=\"", round(bar_height; digits=2),
          "\" fill=\"none\" stroke=\"#e5e7eb\" stroke-width=\"0.5\"/>\n")
    print(io, "<text x=\"", bar_x + 21, "\" y=\"", round(bar_y + 4; digits=2),
          "\" fill=\"#e5e7eb\" font-family=\"sans-serif\" font-size=\"11\">",
          round(upper; sigdigits=4), "</text>\n")
    print(io, "<text x=\"", bar_x + 21, "\" y=\"",
          round(bar_y + bar_height; digits=2),
          "\" fill=\"#e5e7eb\" font-family=\"sans-serif\" font-size=\"11\">",
          round(lower; sigdigits=4), "</text>\n")
end
