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

@testset "ODE attractors" begin
    @test available_systems() == (:henon, :lorenz, :rossler, :thomas)
    @test generate_points("HeNoN"; iterations=2, discard=0) ==
          henon_points(iterations=2, discard=0)

    for system in (:lorenz, :rossler, :thomas)
        points = generate_points(system; duration=0.1, dt=0.02, discard=0.0)
        @test !isempty(points)
        @test all(point -> all(isfinite, point), points)
    end
    sampled = lorenz_points(duration=0.1, discard=0.0, points=5)
    @test length(sampled) == 5
    xz_points = lorenz_points(
        duration=0.1,
        discard=0.0,
        points=5,
        projection=:xz,
    )
    @test length(xz_points) == 5
    @test xz_points != sampled

    oscillator! = function (du, u, p, t)
        du[1] = p * u[2]
        du[2] = -p * u[1]
        du[3] = 0.0
        du[4] = 0.0
    end
    custom_points = ode_points(
        oscillator!,
        [1.0, 0.0, 0.0, 0.0];
        p=1.0,
        duration=0.1,
        discard=0.0,
        points=6,
        projection=(1, 4),
    )
    @test length(custom_points) == 6
    @test custom_points[1] == (1.0, 0.0)
    @test all(point -> point[2] == 0.0, custom_points)

    @test_throws ArgumentError generate_points(:unknown)
    @test_throws ArgumentError ode_points(oscillator!, [1.0])
    @test_throws ArgumentError ode_points(oscillator!, [1.0, 0.0]; points=0)
    @test_throws ArgumentError ode_points(oscillator!, [1.0, 0.0]; projection=:yz)
    @test_throws ArgumentError lorenz_points(duration=0.0)
    @test_throws ArgumentError rossler_points(initial_state=(Inf, 0.0, 0.0))
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
