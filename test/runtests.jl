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

function gif_frame_count(bytes)
    @test bytes[1:6] == collect(codeunits("GIF89a"))
    screen_flags = bytes[11]
    index = 14
    if screen_flags & 0x80 != 0
        index += 3 * (1 << ((screen_flags & 0x07) + 1))
    end

    frames = 0
    while index <= length(bytes)
        marker = bytes[index]
        index += 1
        if marker == 0x2c
            frames += 1
            index += 9
            image_flags = bytes[index - 1]
            if image_flags & 0x80 != 0
                index += 3 * (1 << ((image_flags & 0x07) + 1))
            end
            index += 1
            while true
                block_size = bytes[index]
                index += 1
                block_size == 0 && break
                index += block_size
            end
        elseif marker == 0x21
            index += 1
            while true
                block_size = bytes[index]
                index += 1
                block_size == 0 && break
                index += block_size
            end
        elseif marker == 0x3b
            break
        else
            error("unexpected GIF record marker: $marker")
        end
    end
    return frames
end

@testset "Transition GIF export" begin
    mktempdir() do directory
        henon_path = joinpath(directory, "henon.gif")
        @test write_transition_gif(
            henon_path;
            system=:henon,
            frames=3,
            points=100,
            width=160,
            height=80,
        ) == henon_path
        @test gif_frame_count(read(henon_path)) == 3

        lorenz_path = joinpath(directory, "sweep-lorenz.gif")
        paths = write_transition_gifs(
            joinpath(directory, "sweep");
            systems=(:lorenz,),
            frames=2,
            points=20,
            width=160,
            height=80,
        )
        @test paths == [joinpath(directory, "sweep-lorenz.gif")]
        @test gif_frame_count(read(lorenz_path)) == 2

        values_path = joinpath(directory, "henon-values.gif")
        @test write_transition_gif(
            values_path;
            system=:henon,
            parameter_values=[1.0, 1.05, 1.06, 1.1],
            points=100,
            width=160,
            height=80,
        ) == values_path
        @test gif_frame_count(read(values_path)) == 4
    end

    @test_throws ArgumentError write_transition_gif(
        "unused.gif";
        system=:henon,
        frames=1,
    )
    @test_throws ArgumentError write_transition_gif(
        "unused.gif";
        system=:henon,
        parameter_values=[1.0],
    )
    @test_throws ArgumentError write_transition_gif(
        "unused.gif";
        system=:henon,
        parameter_values=[1.0, 1.1],
        frames=2,
    )
end

@testset "Explicit parameter sampling" begin
    @test_throws ArgumentError write_transition_gif(
        "unused.gif";
        system=:henon,
        parameter_values=[1.0, Inf],
    )
end
