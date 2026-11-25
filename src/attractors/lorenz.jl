"""
    lorenz_points(; sigma=10.0, rho=28.0, beta=8/3,
                  initial_state=(1, 0, 0), solver=Vern7(),
                  points=nothing, projection=:xy,
                  duration=100.0, dt=0.01, discard=20.0)

Integrate the Lorenz system and return the selected 2D projection. `sigma`,
`rho`, and `beta` control the equations; integration, point-count, projection,
and solver keywords are forwarded to [`ode_points`](@ref).
"""
function lorenz_points(;
    sigma::Real=10.0,
    rho::Real=28.0,
    beta::Real=8 / 3,
    initial_state=(1.0, 0.0, 0.0),
    solver=Vern7(),
    points::Union{Nothing, Integer}=nothing,
    projection=:xy,
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
    return ode_points(rhs!, initial_state; solver, points, projection, duration, dt, discard)
end
