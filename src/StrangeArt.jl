module StrangeArt

using OrdinaryDiffEq: ODEProblem, Tsit5, solve

export available_systems, generate_points, henon_points, lorenz_points, ode_points,
       rossler_points, thomas_points, write_svg

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

function ode_points(
    rhs!,
    initial_state;
    solver=Tsit5(),
    p=nothing,
    duration=100.0,
    dt=0.01,
    discard=20.0,
)
    ((initial_state isa Tuple || initial_state isa AbstractVector) &&
     length(initial_state) >= 2) ||
        throw(ArgumentError("initial_state must contain at least two finite real values"))
    all(value -> value isa Real && isfinite(value), initial_state) ||
        throw(ArgumentError("initial_state must contain at least two finite real values"))
    all(value -> value isa Real && isfinite(value), (duration, dt, discard)) ||
        throw(ArgumentError("duration, dt, and discard must be finite real values"))
    duration > 0 || throw(ArgumentError("duration must be positive"))
    dt > 0 || throw(ArgumentError("dt must be positive"))
    0 <= discard < duration ||
        throw(ArgumentError("discard must be non-negative and less than duration"))

    duration, dt, discard = Float64(duration), Float64(dt), Float64(discard)
    initial = Float64[value for value in initial_state]
    all(isfinite, (duration, dt, discard, initial...)) ||
        throw(ArgumentError("solver inputs must be representable as finite Float64 values"))

    problem = ODEProblem(rhs!, initial, (0.0, duration), p)
    solution = solve(problem, solver; saveat=dt, reltol=1e-8, abstol=1e-10)

    return NTuple{2, Float64}[
        (state[1], state[2])
        for (time, state) in zip(solution.t, solution.u)
        if time >= discard
    ]
end

function lorenz_points(;
    sigma::Real=10.0,
    rho::Real=28.0,
    beta::Real=8 / 3,
    initial_state=(1.0, 0.0, 0.0),
    solver=Tsit5(),
    duration::Real=100.0,
    dt::Real=0.01,
    discard::Real=20.0,
)
    all(isfinite, (sigma, rho, beta)) ||
        throw(ArgumentError("Lorenz parameters must be finite"))
    rhs! = function (du, u, _, _)
        du[1] = sigma * (u[2] - u[1])
        du[2] = u[1] * (rho - u[3]) - u[2]
        du[3] = u[1] * u[2] - beta * u[3]
    end
    return ode_points(rhs!, initial_state; solver, duration, dt, discard)
end

function rossler_points(;
    a::Real=0.2,
    b::Real=0.2,
    c::Real=5.7,
    initial_state=(1.0, 0.0, 0.0),
    solver=Tsit5(),
    duration::Real=200.0,
    dt::Real=0.01,
    discard::Real=50.0,
)
    all(isfinite, (a, b, c)) || throw(ArgumentError("Rössler parameters must be finite"))
    rhs! = function (du, u, _, _)
        du[1] = -u[2] - u[3]
        du[2] = u[1] + a * u[2]
        du[3] = b + u[3] * (u[1] - c)
    end
    return ode_points(rhs!, initial_state; solver, duration, dt, discard)
end

function thomas_points(;
    b::Real=0.208186,
    initial_state=(0.1, 0.0, 0.0),
    solver=Tsit5(),
    duration::Real=100.0,
    dt::Real=0.01,
    discard::Real=20.0,
)
    isfinite(b) || throw(ArgumentError("Thomas parameter must be finite"))
    rhs! = function (du, u, _, _)
        du[1] = sin(u[2]) - b * u[1]
        du[2] = sin(u[3]) - b * u[2]
        du[3] = sin(u[1]) - b * u[3]
    end
    return ode_points(rhs!, initial_state; solver, duration, dt, discard)
end

available_systems() = (:henon, :lorenz, :rossler, :thomas)

function generate_points(system::Union{Symbol, AbstractString}; kwargs...)
    selected = Symbol(lowercase(string(system)))
    selected === :henon && return henon_points(; kwargs...)
    selected === :lorenz && return lorenz_points(; kwargs...)
    selected === :rossler && return rossler_points(; kwargs...)
    selected === :thomas && return thomas_points(; kwargs...)

    options = join(string.(available_systems()), ", ")
    throw(ArgumentError("unknown attractor '$system'; choose one of: $options"))
end

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

end
