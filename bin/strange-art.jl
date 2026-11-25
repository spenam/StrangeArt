include(joinpath(@__DIR__, "..", "src", "StrangeArt.jl"))
using .StrangeArt

if length(ARGS) > 1
    error("usage: julia --project=. bin/strange-art.jl [output.svg]")
end

output = isempty(ARGS) ? "henon.svg" : ARGS[1]
points = henon_points()
write_svg(output, points)
println("Wrote $(length(points)) points to $output")
