using Test
include(joinpath(@__DIR__, "..", "src", "StrangeArt.jl"))
using .StrangeArt

@testset "Hénon attractor" begin
    points = henon_points(iterations=2, discard=0)
    @test points[1] == (1.0, 0.0)
    @test points[2][1] ≈ -0.4
    @test points[2][2] ≈ 0.3
    all_points = henon_points(iterations=5, discard=0)
    discarded_points = henon_points(iterations=3, discard=2)
    @test length(discarded_points) == 3
    @test discarded_points == all_points[3:5]
    @test isempty(henon_points(iterations=0, discard=0))
    @test_throws ArgumentError henon_points(iterations=-1)
    @test_throws ArgumentError henon_points(discard=-1)
    @test_throws ArgumentError henon_points(a=Inf)
end

@testset "SVG export" begin
    mktemp() do path, io
        close(io)
        write_svg(path, [(0.0, 0.0), (1.0, 1.0)]; width=320, height=240)
        svg = read(path, String)
        @test occursin("width=\"320\" height=\"240\"", svg)
        @test occursin("<circle", svg)
        @test endswith(svg, "</svg>\n")
    end

    @test_throws ArgumentError write_svg("unused.svg", [(0.0, Inf)])
    @test_throws ArgumentError write_svg("unused.svg", [(0im, 0im)])
    @test_throws ArgumentError write_svg("unused.svg", NTuple{2, Float64}[]; width=0)
end
