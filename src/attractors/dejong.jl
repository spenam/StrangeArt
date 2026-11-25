"""
    dejong_points(; a=-2.24, b=0.43, c=-0.65, d=-2.43,
                  iterations=100_000, discard=1_000, x0=0, y0=0)

Generate points from the Peter de Jong map:
`x_next = sin(a*y) - cos(b*x)` and
`y_next = sin(c*x) - cos(d*y)`.
`discard` skips transient iterations; `iterations` is the number of points
returned afterward.
"""
function dejong_points(;
    a::Real=-2.24,
    b::Real=0.43,
    c::Real=-0.65,
    d::Real=-2.43,
    iterations::Integer=100_000,
    discard::Integer=1_000,
    x0::Real=0.0,
    y0::Real=0.0,
)
    iterations >= 0 || throw(ArgumentError("iterations must be non-negative"))
    discard >= 0 || throw(ArgumentError("discard must be non-negative"))
    all(isfinite, (a, b, c, d, x0, y0)) ||
        throw(ArgumentError("parameters and initial state must be finite"))

    a, b, c, d, x, y = Float64(a), Float64(b), Float64(c), Float64(d), Float64(x0), Float64(y0)
    all(isfinite, (a, b, c, d, x, y)) ||
        throw(ArgumentError("parameters and initial state must fit in Float64"))
    points = NTuple{2, Float64}[]
    sizehint!(points, iterations)

    for iteration in 1:(iterations + discard)
        x, y = sin(a * y) - cos(b * x), sin(c * x) - cos(d * y)
        if iteration > discard
            isfinite(x) && isfinite(y) || break
            push!(points, (x, y))
        end
    end
    return points
end
