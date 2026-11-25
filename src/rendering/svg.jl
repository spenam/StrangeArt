function write_svg(path::AbstractString, points::AbstractVector{<:Tuple};
                   width::Integer=1000, height::Integer=1000)
    width > 0 || throw(ArgumentError("width must be positive"))
    height > 0 || throw(ArgumentError("height must be positive"))
    all(point -> length(point) == 2 && all(value -> value isa Real && isfinite(value), point), points) ||
        throw(ArgumentError("points must contain finite 2D coordinates"))

    margin = min(24.0, min(width, height) / 10)
    if isempty(points)
        x_min, x_max, y_min, y_max = -1.0, 1.0, -1.0, 1.0
    else
        x_min = minimum(point[1] for point in points)
        x_max = maximum(point[1] for point in points)
        y_min = minimum(point[2] for point in points)
        y_max = maximum(point[2] for point in points)
    end

    x_span, y_span = max(x_max - x_min, eps()), max(y_max - y_min, eps())
    available_width = max(width - 2margin, 1)
    available_height = max(height - 2margin, 1)
    scale = min(available_width / x_span, available_height / y_span)
    x_offset = margin + (available_width - x_span * scale) / 2
    y_offset = margin + (available_height - y_span * scale) / 2

    open(path, "w") do io
        print(io, "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"", width,
              "\" height=\"", height, "\" viewBox=\"0 0 ", width, " ", height, "\">\n")
        print(io, "<rect width=\"100%\" height=\"100%\" fill=\"#0b1020\"/>\n")
        for (x, y) in points
            cx = x_offset + (x - x_min) * scale
            cy = height - y_offset - (y - y_min) * scale
            print(io, "<circle cx=\"", round(cx; digits=2), "\" cy=\"",
                  round(cy; digits=2), "\" r=\"0.7\" fill=\"#a78bfa\" opacity=\"0.35\"/>\n")
        end
        print(io, "</svg>\n")
    end

    return path
end
