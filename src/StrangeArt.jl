"""
    StrangeArt

Generate 2D point clouds from strange attractors and export them as SVG images.
"""
module StrangeArt

using OrdinaryDiffEqVerner: Vern7
using Giflib_jll: libgif
using SciMLBase: ODEProblem, solve
using Zlib_jll: libz

export available_systems, generate_points, henon_points, lorenz_points, ode_points,
       rossler_points, thomas_points, write_svg, write_sweep_png,
       write_transition_gif, write_transition_gifs

include("attractors/henon.jl")
include("attractors/ode.jl")
include("attractors/lorenz.jl")
include("attractors/rossler.jl")
include("attractors/thomas.jl")
include("attractors/registry.jl")
include("rendering/svg.jl")
include("rendering/png.jl")
include("rendering/gif.jl")
include("animation/transition.jl")

end
