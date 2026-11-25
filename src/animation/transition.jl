"""
    _transition_configuration(system)

Return the control parameter and default sweep range for a built-in system.
"""
function _transition_configuration(system::Symbol)
    system === :clifford && return (parameter=:a, start=-1.6, stop=-1.2)
    system === :dejong && return (parameter=:a, start=-2.6, stop=-1.9)
    system === :henon && return (parameter=:a, start=0.8, stop=1.4)
    system === :lorenz && return (parameter=:rho, start=20.0, stop=28.0)
    system === :rossler && return (parameter=:c, start=2.0, stop=6.0)
    system === :thomas && return (parameter=:b, start=0.32, stop=0.18)
    throw(ArgumentError("unknown attractor '$system'; choose one of: $(join(available_systems(), ", "))"))
end

"""
    _transition_points(system, value, count, projection)

Generate one orbit from a built-in system at a single control-parameter value.
"""
function _transition_points(system, value, count, projection)
    if system === :clifford
        indices = _projection_indices(projection, 2)
        orbit = clifford_points(a=value, iterations=count)
        return [(point[indices[1]], point[indices[2]]) for point in orbit]
    elseif system === :dejong
        indices = _projection_indices(projection, 2)
        orbit = dejong_points(a=value, iterations=count)
        return [(point[indices[1]], point[indices[2]]) for point in orbit]
    elseif system === :henon
        indices = _projection_indices(projection, 2)
        orbit = henon_points(a=value, iterations=count)
        return [(point[indices[1]], point[indices[2]]) for point in orbit]
    elseif system === :lorenz
        return lorenz_points(rho=value, points=count, projection=projection)
    elseif system === :rossler
        return rossler_points(c=value, points=count, projection=projection)
    elseif system === :thomas
        return thomas_points(b=value, points=count, projection=projection)
    end
    throw(ArgumentError("unknown attractor '$system'"))
end

function _sweep_bounds(clouds)
    all(cloud -> !isempty(cloud), clouds) ||
        throw(ArgumentError("the parameter sweep produced an empty orbit"))
    all(cloud -> all(point -> all(isfinite, point), cloud), clouds) ||
        throw(ArgumentError("the parameter sweep produced non-finite points"))

    return (
        minimum(point[1] for cloud in clouds for point in cloud),
        maximum(point[1] for cloud in clouds for point in cloud),
        minimum(point[2] for cloud in clouds for point in cloud),
        maximum(point[2] for cloud in clouds for point in cloud),
    )
end

"""
    write_transition_gif(path; system=:lorenz, frames=24, points=5_000,
                         projection=:xy, start=nothing, stop=nothing,
                         parameter_values=nothing,
                         width=480, height=360, frame_delay=8)

Create a looping GIF that sweeps a system's default control parameter and
labels each frame with its value. `start` and `stop` define an evenly spaced
sweep; provide `parameter_values` to choose the exact values and frame count.
`points` is the orbit size per frame; `projection` selects the 2D view.
`frame_delay` is measured in centiseconds. Returns `path`.
"""
function write_transition_gif(
    path::AbstractString;
    system::Union{Symbol, AbstractString}=:lorenz,
    frames::Union{Nothing, Integer}=nothing,
    points::Integer=5_000,
    projection=:xy,
    start::Union{Nothing, Real}=nothing,
    stop::Union{Nothing, Real}=nothing,
    parameter_values=nothing,
    width::Integer=480,
    height::Integer=360,
    frame_delay::Integer=8,
)
    selected = Symbol(lowercase(string(system)))
    configuration = _transition_configuration(selected)
    points > 0 || throw(ArgumentError("points must be positive"))
    width >= 128 || throw(ArgumentError("GIF width must be at least 128 pixels"))
    height >= 64 || throw(ArgumentError("GIF height must be at least 64 pixels"))
    width <= typemax(UInt16) || throw(ArgumentError("GIF width must not exceed 65535 pixels"))
    height <= typemax(UInt16) || throw(ArgumentError("GIF height must not exceed 65535 pixels"))
    1 <= frame_delay <= typemax(UInt16) ||
        throw(ArgumentError("frame delay must be between 1 and 65535 centiseconds"))
    endswith(lowercase(path), ".gif") ||
        throw(ArgumentError("transition animation output path must end in .gif"))

    first_value = start === nothing ? configuration.start : Float64(start)
    last_value = stop === nothing ? configuration.stop : Float64(stop)
    dimensions = selected in (:clifford, :dejong, :henon) ? 2 : 3
    _projection_indices(projection, dimensions)

    if parameter_values === nothing
        frame_count = frames === nothing ? 24 : frames
        frame_count >= 2 || throw(ArgumentError("frames must be at least 2"))
        all(isfinite, (first_value, last_value)) ||
            throw(ArgumentError("sweep limits must be finite"))
        first_value != last_value || throw(ArgumentError("sweep limits must differ"))
        sampled_parameters = collect(range(first_value, last_value; length=frame_count))
    else
        (frames === nothing && start === nothing && stop === nothing) ||
            throw(ArgumentError("parameter_values cannot be combined with frames, start, or stop"))
        (parameter_values isa AbstractVector || parameter_values isa Tuple) ||
            throw(ArgumentError("parameter_values must be a vector or tuple of real numbers"))
        length(parameter_values) >= 2 ||
            throw(ArgumentError("parameter_values must contain at least 2 values"))
        all(value -> value isa Real && isfinite(value), parameter_values) ||
            throw(ArgumentError("parameter_values must contain finite real numbers"))
        sampled_parameters = Float64[value for value in parameter_values]
        all(isfinite, sampled_parameters) ||
            throw(ArgumentError("parameter_values must be representable as finite Float64 values"))
        frame_count = length(sampled_parameters)
    end

    clouds = [
        _transition_points(selected, value, points, projection)
        for value in sampled_parameters
    ]
    bounds = _sweep_bounds(clouds)
    indexed_frames = Array{UInt8, 3}(undef, height, width, frame_count)

    for (frame_index, (value, cloud)) in enumerate(zip(sampled_parameters, clouds))
        label = string(configuration.parameter, "=", round(value; sigdigits=4))
        indexed_frames[:, :, frame_index] =
            _render_gif_frame(cloud, bounds, width, height, label)
    end

    return _encode_gif(path, indexed_frames; frame_delay)
end

"""
    write_transition_gifs(prefix; systems=available_systems(), kwargs...)

Write one parameter-sweep GIF per selected system, using filenames derived
from `prefix` (for example, `chaos-lorenz.gif`). Returns the output paths.
"""
function write_transition_gifs(
    prefix::AbstractString;
    systems=available_systems(),
    projection=:xy,
    parameter_values=nothing,
    kwargs...,
)
    isempty(systems) && throw(ArgumentError("at least one system must be selected"))
    all(system -> system in available_systems(), systems) ||
        throw(ArgumentError("systems must be selected from available_systems()"))
    parameter_values !== nothing && length(systems) > 1 &&
        throw(ArgumentError("parameter_values can only be used with one selected system"))
    if any(system -> system in (:clifford, :dejong, :henon), systems)
        _projection_indices(projection, 2)
    end

    stem, extension = splitext(prefix)
    (isempty(extension) || lowercase(extension) == ".gif") ||
        throw(ArgumentError("GIF output prefix must use the .gif extension"))
    base = isempty(extension) ? prefix : stem
    paths = String[]

    for system in systems
        path = "$base-$system.gif"
        write_transition_gif(path; system, projection, parameter_values, kwargs...)
        push!(paths, path)
    end

    return paths
end
