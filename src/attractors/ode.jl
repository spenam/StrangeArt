"""
    ode_points(rhs!, initial_state; solver=Vern7(), p=nothing,
               duration=100.0, dt=0.01, discard=20.0)

Integrate an in-place ODE `rhs!(du, u, p, t)` and return its first two state
variables as 2D points. `initial_state` must contain at least two finite real
values. `dt` controls saved-output spacing; the solver may use adaptive
internal steps. `discard` is the transient time omitted from the output.

Pass ODE parameters with `p`, choose a compatible algorithm with `solver`, and
set the integration end time with `duration`.
"""
function ode_points(
    rhs!,
    initial_state;
    solver=Vern7(),
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
