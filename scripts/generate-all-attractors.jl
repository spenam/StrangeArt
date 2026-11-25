include(joinpath(@__DIR__, "..", "src", "StrangeArt.jl"))
using .StrangeArt

const OUTPUT_DIR = joinpath(@__DIR__, "..", "generated-art")
const POINTS_PER_FRAME = 5_000
const FRAME_DELAY = 12
const PROJECTION = :xy

const SWEEP_VALUES = (
    henon=[0.8, 0.9, 1.0, 1.1, 1.2, 1.3, 1.4],
    lorenz=[20.0, 21.0, 22.0, 23.0, 24.0, 25.0, 26.0, 27.0, 28.0],
    rossler=[2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0, 5.5, 6.0],
    thomas=[0.32, 0.30, 0.28, 0.26, 0.24, 0.22, 0.20, 0.18],
)

"""
    generate_all_attractors()

Generate one custom parameter-sweep GIF for every built-in attractor.
Edit `SWEEP_VALUES` and the rendering settings near the top of this script.
"""
function generate_all_attractors()
    mkpath(OUTPUT_DIR)

    for system in available_systems()
        output_path = joinpath(OUTPUT_DIR, "$system.gif")
        write_transition_gif(
            output_path;
            system,
            parameter_values=SWEEP_VALUES[system],
            points=POINTS_PER_FRAME,
            projection=PROJECTION,
            frame_delay=FRAME_DELAY,
        )
        println("Wrote $output_path")
    end
end

generate_all_attractors()
