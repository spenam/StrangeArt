"""
    henon_points(; a=1.4, b=0.3, iterations=100_000, discard=1_000, x0=0, y0=0)

Generate an orbit of the discrete Hénon map:
`x_next = 1 - a*x^2 + y`, `y_next = b*x`.

`discard` sets the number of initial transient iterations to skip; `iterations`
sets how many points to return afterward. Returns 2D points as
`Vector{NTuple{2, Float64}}`.
"""
function henon_points(;
    a::Real=1.4,
    b::Real=0.3,
    iterations::Integer=100_000,
    discard::Integer=1_000,
    x0::Real=0.0,
    y0::Real=0.0,
)
    iterations >= 0 || throw(ArgumentError("iterations must be non-negative"))
    discard >= 0 || throw(ArgumentError("discard must be non-negative"))
    all(isfinite, (a, b, x0, y0)) || throw(ArgumentError("parameters must be finite"))

    points = NTuple{2, Float64}[]
    sizehint!(points, iterations)
    x, y = Float64(x0), Float64(y0)

    for i in 1:(iterations + discard)
        x, y = 1 - a * x^2 + y, b * x
        if i > discard
            isfinite(x) && isfinite(y) || break
            push!(points, (x, y))
        end
    end

    return points
end
