include(joinpath(@__DIR__, "..", "src", "StrangeArt.jl"))
using .StrangeArt

"""
    parse_arguments(args)

Parse output, system, point-count, and projection CLI options. Returns a
named tuple; the output path defaults to `<system>.svg`.
"""
function parse_arguments(args)
    output = nothing
    system = "henon"
    points = nothing
    projection = :xy
    index = 1

    while index <= length(args)
        argument = args[index]
        if argument in ("--system", "--points", "--projection")
            index < length(args) || error("$argument requires a value")
            value = args[index + 1]
            if argument == "--system"
                system = value
            elseif argument == "--points"
                points = parse(Int, value)
                points > 0 || error("--points must be positive")
            else
                projection = Symbol(lowercase(value))
                projection in (:xy, :xz, :yz) ||
                    error("--projection must be xy, xz, or yz")
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
    output === nothing && (output = "$selected.svg")
    return (system=selected, output=output, points=points, projection=projection)
end

options = parse_arguments(ARGS)
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
