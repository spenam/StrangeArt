include(joinpath(@__DIR__, "..", "src", "StrangeArt.jl"))
using .StrangeArt

const OUTPUT_DIR = joinpath(@__DIR__, "..", "generated-art")
const POINTS_PER_PARAMETER = 5_000
const PROJECTION = :xy

const SWEEPS = (
    henon=(parameter="a", values=[0.8, 0.9, 1.0, 1.1, 1.2, 1.3, 1.4]),
    lorenz=(parameter="rho", values=[20.0, 21.0, 22.0, 23.0, 24.0, 25.0, 26.0, 27.0, 28.0]),
    rossler=(parameter="c", values=[2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0, 5.5, 6.0]),
    thomas=(parameter="b", values=[0.32, 0.30, 0.28, 0.26, 0.24, 0.22, 0.20, 0.18]),
)

"""
    generate_all_attractors()

Generate one parameter-colored SVG for every built-in attractor. Edit `SWEEPS`
and the rendering settings near the top of this script.
"""
function generate_all_attractors()
    mkpath(OUTPUT_DIR)

    for system in available_systems()
        sweep = SWEEPS[system]
        points = NTuple{2, Float64}[]
        color_values = Float64[]

        for value in sweep.values
            orbit = points_at_parameter(system, value)
            append!(points, orbit)
            append!(color_values, fill(value, length(orbit)))
        end

        output_path = joinpath(OUTPUT_DIR, "$system.svg")
        write_svg(
            output_path,
            points;
            color_values,
            colorbar_label=sweep.parameter,
        )
        println("Wrote $output_path")
    end
end

"""
    points_at_parameter(system, value)

Generate one orbit for the configured control-parameter value.
"""
function points_at_parameter(system, value)
    if system === :henon
        return henon_points(a=value, iterations=POINTS_PER_PARAMETER)
    elseif system === :lorenz
        return lorenz_points(rho=value, points=POINTS_PER_PARAMETER, projection=PROJECTION)
    elseif system === :rossler
        return rossler_points(c=value, points=POINTS_PER_PARAMETER, projection=PROJECTION)
    elseif system === :thomas
        return thomas_points(b=value, points=POINTS_PER_PARAMETER, projection=PROJECTION)
    end
    throw(ArgumentError("unknown attractor: $system"))
end

generate_all_attractors()
