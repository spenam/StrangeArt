include(joinpath(@__DIR__, "..", "src", "StrangeArt.jl"))
using .StrangeArt

const OUTPUT_DIR = joinpath(@__DIR__, "..", "generated-art")
const POINTS_PER_PARAMETER = 5_000
const PROJECTION = :xy
const IMAGE_WIDTH = 2_400
const IMAGE_HEIGHT = 2_400
const DPI = 300

const SWEEPS = (
    henon=(parameter="a", values=range(0.8, 1.4, length=100)),
    lorenz=(parameter="rho", values=range(20.0, 28.0, length=100)),
    rossler=(parameter="c", values=range(2.0, 6.0, length=100)),
    thomas=(parameter="b", values=range(0.32, 0.18, length=100)),
)

"""
    generate_all_attractors()

Generate one high-resolution, parameter-colored PNG for every built-in
attractor. Edit `SWEEPS` and the rendering settings near the top of this script.
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

        output_path = joinpath(OUTPUT_DIR, "$system.png")
        write_sweep_png(
            output_path,
            points;
            color_values,
            colorbar_label=sweep.parameter,
            width=IMAGE_WIDTH,
            height=IMAGE_HEIGHT,
            dpi=DPI,
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
