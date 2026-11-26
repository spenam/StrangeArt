"""
    density_grid(points; width=1600, height=1600, bounds=nothing)

Accumulate point occupancy in a `height`-by-`width` `UInt32` matrix. Matrix
indices are `[y, x]`. By default, the point extents fill the grid; `bounds`
can fix the plot range as `(x_min, x_max, y_min, y_max)`. Points outside
explicit bounds are omitted.
"""
function density_grid(
    points::AbstractVector{<:Tuple};
    width::Integer=1600,
    height::Integer=1600,
    bounds=nothing,
)
    1 <= width <= typemax(UInt32) ||
        throw(ArgumentError("width must be in the PNG dimension range"))
    1 <= height <= typemax(UInt32) ||
        throw(ArgumentError("height must be in the PNG dimension range"))
    width <= typemax(Int) && height <= typemax(Int) &&
        width <= typemax(Int) ÷ height ||
        throw(ArgumentError("density grid dimensions are too large"))
    !isempty(points) || throw(ArgumentError("at least one point is required"))
    all(
        point -> length(point) == 2 &&
                 all(value -> value isa Real && isfinite(Float64(value)), point),
        points,
    ) || throw(ArgumentError("points must contain finite 2D coordinates representable as Float64"))

    if bounds === nothing
        x_min = minimum(Float64(point[1]) for point in points)
        x_max = maximum(Float64(point[1]) for point in points)
        y_min = minimum(Float64(point[2]) for point in points)
        y_max = maximum(Float64(point[2]) for point in points)
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
    isfinite(x_max - x_min) && isfinite(y_max - y_min) ||
        throw(ArgumentError("coordinate ranges must be representable as finite Float64 values"))

    grid = zeros(UInt32, Int(height), Int(width))
    for point in points
        x, y = Float64(point[1]), Float64(point[2])
        if x < x_min || x > x_max || y < y_min || y > y_max
            continue
        end
        column = _density_index(x, x_min, x_max, Int(width))
        row = Int(height) - _density_index(y, y_min, y_max, Int(height)) + 1
        grid[row, column] < typemax(UInt32) ||
            throw(OverflowError("density count exceeds UInt32 range"))
        grid[row, column] += 1
    end
    return grid
end

function _density_index(value, lower, upper, size)
    lower == upper && return fld(size, 2) + 1
    return round(Int, (value - lower) / (upper - lower) * (size - 1)) + 1
end

"""
    write_density_png(path, grid; scale=:log, dpi=300)

Apply the perceptually uniform palette to a density grid and write an RGB PNG.
Zero-occupancy pixels use a dark background. `scale=:log` compresses the
density range for smoother gradients; `:linear` maps counts directly.
"""
function write_density_png(
    path::AbstractString,
    grid::AbstractMatrix{<:Integer};
    scale::Symbol=:log,
    dpi::Real=300,
)
    endswith(lowercase(path), ".png") ||
        throw(ArgumentError("PNG output path must end in .png"))
    height, width = size(grid)
    1 <= width <= typemax(UInt32) ||
        throw(ArgumentError("grid width is outside the PNG dimension range"))
    1 <= height <= typemax(UInt32) ||
        throw(ArgumentError("grid height is outside the PNG dimension range"))
    scale in (:log, :linear) ||
        throw(ArgumentError("scale must be :log or :linear"))
    all(value -> value >= 0 && isfinite(Float64(value)), grid) ||
        throw(ArgumentError("density values must be finite and non-negative"))

    pixels = _density_png_pixels(grid, scale)
    pixels_per_meter = _png_pixels_per_meter(dpi)
    _write_png(path, _zlib_compress(_png_scanlines(pixels)), width, height, pixels_per_meter)
    return path
end

function _density_png_pixels(grid, scale)
    height, width = size(grid)
    pixels = Array{UInt8, 3}(undef, height, width, 3)
    pixels[:, :, 1] .= 0x0b
    pixels[:, :, 2] .= 0x10
    pixels[:, :, 3] .= 0x20

    max_density = maximum(Float64(value) for value in grid)
    max_density == 0 && return pixels
    log_max_density = log1p(max_density)
    palette_size = 4096
    palette = [
        _hex_rgb(_perceptual_palette_color(index / (palette_size - 1)))
        for index in 0:(palette_size - 1)
    ]

    for row in 1:height, column in 1:width
        density = Float64(grid[row, column])
        density == 0 && continue
        intensity = scale === :log ?
                    log1p(density) / log_max_density :
                    density / max_density
        palette_index = round(Int, intensity * (palette_size - 1)) + 1
        color = palette[palette_index]
        for channel in 1:3
            pixels[row, column, channel] = color[channel]
        end
    end
    return pixels
end
