"""
    clifford_points(; a=-1.4, b=1.6, c=1.0, d=0.7,
                    iterations=100_000, discard=1_000, x0=0, y0=0)

Generate points from the Clifford map:
`x_next = sin(a*y) + c*cos(a*x)` and
`y_next = sin(b*x) + d*cos(b*y)`.
`discard` skips transient iterations; `iterations` is the number of points
returned afterward.
"""
function clifford_points(;
    a::Real=-1.4,
    b::Real=1.6,
    c::Real=1.0,
    d::Real=0.7,
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
        x, y = sin(a * y) + c * cos(a * x), sin(b * x) + d * cos(b * y)
        if iteration > discard
            isfinite(x) && isfinite(y) || break
            push!(points, (x, y))
        end
    end
    return points
end
