include(joinpath(@__DIR__, "..", "src", "StrangeArt.jl"))
using .StrangeArt

"""
    parse_arguments(args)

Parse output, system, point-count, projection, and animation CLI options.
Returns a named tuple; the output path defaults to `<system>.svg`, or
`attractors.gif` when all systems are selected.
"""
function parse_arguments(args)
    output = nothing
    system = "henon"
    points = nothing
    projection = :xy
    frames = nothing
    start = nothing
    stop = nothing
    parameter_values = nothing
    frame_delay = 8
    index = 1

    while index <= length(args)
        argument = args[index]
        if argument in (
            "--system",
            "--points",
            "--projection",
            "--frames",
            "--start",
            "--stop",
            "--values",
            "--delay",
        )
            index < length(args) || error("$argument requires a value")
            value = args[index + 1]
            if argument == "--system"
                system = value
            elseif argument == "--points"
                points = parse(Int, value)
                points > 0 || error("--points must be positive")
            elseif argument == "--projection"
                projection = Symbol(lowercase(value))
                projection in (:xy, :xz, :yz) ||
                    error("--projection must be xy, xz, or yz")
            elseif argument == "--frames"
                frames = parse(Int, value)
                frames >= 2 || error("--frames must be at least 2")
            elseif argument == "--start"
                start = parse(Float64, value)
            elseif argument == "--stop"
                stop = parse(Float64, value)
            elseif argument == "--values"
                parameter_values = Float64[
                    parse(Float64, strip(parameter)) for parameter in split(value, ',')
                ]
            else
                frame_delay = parse(Int, value)
                frame_delay > 0 || error("--delay must be positive")
            end
            index += 2
        elseif startswith(argument, "--")
            error("unknown option: $argument")
        elseif output === nothing
            output = argument
            index += 1
        else
            error("unexpected argument: $argument")
        end
    end

    selected = Symbol(lowercase(system))
    selected in (:all, available_systems()...) ||
        error("--system must be henon, lorenz, rossler, thomas, or all")
    if parameter_values !== nothing
        selected !== :all || error("--values can only be used with one selected system")
        (frames === nothing && start === nothing && stop === nothing) ||
            error("--values cannot be combined with --frames, --start, or --stop")
    end
    output === nothing &&
        (output = selected === :all ? "attractors.gif" : "$selected.svg")
    return (
        system=selected,
        output=output,
        points=points,
        projection=projection,
        frames=frames,
        start=start,
        stop=stop,
        parameter_values=parameter_values,
        frame_delay=frame_delay,
    )
end

options = parse_arguments(ARGS)
if endswith(lowercase(options.output), ".gif")
    if options.system === :all
        options.projection === :xy ||
            error("--system all requires --projection xy because Hénon is 2D")
        paths = write_transition_gifs(
            options.output;
            systems=available_systems(),
            points=options.points === nothing ? 5_000 : options.points,
            frames=options.frames,
            start=options.start,
            stop=options.stop,
            parameter_values=options.parameter_values,
            frame_delay=options.frame_delay,
        )
        println("Wrote transition GIFs: $(join(paths, ", "))")
    else
        if options.system === :henon
            options.projection === :xy ||
                error("Hénon is 2D; --projection is available for ODE systems")
        end
        write_transition_gif(
            options.output;
            system=options.system,
            points=options.points === nothing ? 5_000 : options.points,
            projection=options.projection,
            frames=options.frames,
            start=options.start,
            stop=options.stop,
            parameter_values=options.parameter_values,
            frame_delay=options.frame_delay,
        )
        println("Wrote $(options.system) transition GIF to $(options.output)")
    end
else
    options.system !== :all || error("--system all requires a .gif output path")
    (options.frames === nothing && options.start === nothing &&
     options.stop === nothing && options.parameter_values === nothing &&
     options.frame_delay == 8) ||
        error("--frames, --start, --stop, --values, and --delay require a .gif output path")
    if options.system === :henon
        options.projection === :xy ||
            error("Hénon is 2D; --projection is available for ODE systems")
        points = options.points === nothing ?
                 generate_points(options.system) :
                 generate_points(options.system; iterations=options.points)
    else
        points = generate_points(
            options.system;
            points=options.points,
            projection=options.projection,
        )
    end
    write_svg(options.output, points)
    println("Wrote $(length(points)) $(options.system) points to $(options.output)")
end
