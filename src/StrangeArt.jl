"""
    StrangeArt

Generate 2D point clouds from strange attractors and export them as SVG images.
"""
module StrangeArt

using OrdinaryDiffEqVerner: Vern7
using SciMLBase: ODEProblem, solve

export available_systems, generate_points, henon_points, lorenz_points, ode_points,
       rossler_points, thomas_points, write_svg

include("attractors/henon.jl")
include("attractors/ode.jl")
include("attractors/lorenz.jl")
include("attractors/rossler.jl")
include("attractors/thomas.jl")
include("attractors/registry.jl")
include("rendering/svg.jl")

end
