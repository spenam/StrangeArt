"""
    rossler_points(; a=0.2, b=0.2, c=5.7,
                   initial_state=(1, 0, 0), solver=Vern7(),
                   points=nothing, projection=:xy,
                   duration=200.0, dt=0.01, discard=50.0)

Integrate the Rössler system and return the selected 2D projection. The
parameters `a`, `b`, and `c` control the equations; integration, point-count,
projection, and solver keywords are forwarded to [`ode_points`](@ref).
"""
function rossler_points(;
    a::Real=0.2,
    b::Real=0.2,
    c::Real=5.7,
    initial_state=(1.0, 0.0, 0.0),
    solver=Vern7(),
    points::Union{Nothing, Integer}=nothing,
    projection=:xy,
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
    return ode_points(rhs!, initial_state; solver, points, projection, duration, dt, discard)
end
