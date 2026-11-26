include(joinpath(@__DIR__, "..", "src", "StrangeArt.jl"))
using .StrangeArt

const OUTPUT_DIR = joinpath(@__DIR__, "..", "generated-art")
const POINTS_PER_SYSTEM = 900_000
const GRID_WIDTH = 1_000
const GRID_HEIGHT = 1_000
const DPI = 300
const ODE_PROJECTIONS = Dict(
    :lorenz => :xz,
    :rossler => :xy,
    :thomas => :xy,
)

"""
    check_density_rendering()

Generate one density PNG for each built-in attractor in `generated-art/`.
Adjust the sample count, grid dimensions, and projections near the top of
this script to explore different render settings.
"""
function check_density_rendering()
    mkpath(OUTPUT_DIR)

    for system in available_systems()
        points = if system in (:clifford, :dejong, :henon)
            generate_points(system; iterations=POINTS_PER_SYSTEM)
        else
            generate_points(
                system;
                points=POINTS_PER_SYSTEM,
                projection=get(ODE_PROJECTIONS, system, :xy),
            )
        end
        grid = density_grid(points; width=GRID_WIDTH, height=GRID_HEIGHT)
        output_path = joinpath(OUTPUT_DIR, "$system-density.png")
        write_density_png(output_path, grid; scale=:log, dpi=DPI)
        println("Wrote $output_path from $(length(points)) points")
    end
end

check_density_rendering()
