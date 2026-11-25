"""
    thomas_points(; b=0.208186, initial_state=(0.1, 0, 0),
                  solver=Vern7(), duration=100.0, dt=0.01, discard=20.0)

Integrate the Thomas cyclically symmetric system and return its x-y
projection. Integration and solver keywords are forwarded to
[`ode_points`](@ref).
"""
function thomas_points(;
    b::Real=0.208186,
    initial_state=(0.1, 0.0, 0.0),
    solver=Vern7(),
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
