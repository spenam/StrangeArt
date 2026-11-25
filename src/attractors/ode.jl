"""
    _projection_indices(projection, dimensions)

Resolve a named x-y/x-z/y-z projection or a pair of state-variable indices.
"""
function _projection_indices(projection, dimensions)
    indices = if projection isa Symbol || projection isa AbstractString
        name = Symbol(lowercase(string(projection)))
        if name === :xy
            (1, 2)
        elseif name === :xz
            (1, 3)
        elseif name === :yz
            (2, 3)
        else
            throw(ArgumentError("projection must be xy, xz, yz, or a pair of indices"))
        end
    elseif projection isa Tuple && length(projection) == 2 &&
           all(index -> index isa Integer, projection)
        (Int(projection[1]), Int(projection[2]))
    else
        throw(ArgumentError("projection must be xy, xz, yz, or a pair of indices"))
    end

    all(index -> 1 <= index <= dimensions, indices) ||
        throw(ArgumentError("projection indices must be within the state dimension"))
    return indices
end

"""
    ode_points(rhs!, initial_state; solver=Vern7(), p=nothing,
               duration=100.0, dt=0.01, discard=20.0, points=nothing,
               projection=:xy)

Integrate an in-place ODE `rhs!(du, u, p, t)` and return the selected pair of
state variables as 2D points. `initial_state` must contain at least two finite
real values. `dt` controls saved-output spacing when `points` is not set; the
solver may use adaptive internal steps. `discard` is the transient time omitted
from the output. Set `points` to save an exact number of evenly spaced output
points after `discard`. `projection` can be `:xy`, `:xz`, `:yz`, or a pair of
state indices.

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
    points::Union{Nothing, Integer}=nothing,
    projection=:xy,
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
    points === nothing || points > 0 ||
        throw(ArgumentError("points must be positive"))

    duration, dt, discard = Float64(duration), Float64(dt), Float64(discard)
    initial = Float64[value for value in initial_state]
    all(isfinite, (duration, dt, discard, initial...)) ||
        throw(ArgumentError("solver inputs must be representable as finite Float64 values"))
    duration > 0 && dt > 0 ||
        throw(ArgumentError("duration and dt must remain positive when represented as Float64"))
    0 <= discard < duration ||
        throw(ArgumentError("discard must remain less than duration when represented as Float64"))
    projection_indices = _projection_indices(projection, length(initial))

    problem = ODEProblem(rhs!, initial, (0.0, duration), p)
    saveat = points === nothing ? dt : range(discard, duration; length=points)
    solution = solve(problem, solver; saveat, reltol=1e-8, abstol=1e-10)

    return NTuple{2, Float64}[
        (state[projection_indices[1]], state[projection_indices[2]])
        for (time, state) in zip(solution.t, solution.u)
        if time >= discard
    ]
end
