include(joinpath(@__DIR__, "..", "src", "StrangeArt.jl"))
using .StrangeArt

"""
    parse_arguments(args)

Parse the optional output path and `--system name` CLI argument. Returns the
selected system symbol and output path; the path defaults to `<system>.svg`.
"""
function parse_arguments(args)
    output = nothing
    system = "henon"
    index = 1

    while index <= length(args)
        if args[index] == "--system"
            index < length(args) || error("--system requires a system name")
            system = args[index + 1]
            index += 2
        elseif startswith(args[index], "--")
            error("unknown option: $(args[index])")
        elseif output === nothing
            output = args[index]
            index += 1
        else
            error("unexpected argument: $(args[index])")
        end
    end

    selected = Symbol(lowercase(system))
    output === nothing && (output = "$selected.svg")
    return selected, output
end

system, output = parse_arguments(ARGS)
points = generate_points(system)
write_svg(output, points)
println("Wrote $(length(points)) $(system) points to $output")
