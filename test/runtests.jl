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
    @test_throws ArgumentError henon_points(x0=big"1e1000")
end

@testset "Clifford and de Jong attractors" begin
    clifford = clifford_points(iterations=2, discard=0)
    @test clifford[1] == (1.0, 0.7)
    @test clifford[2][1] ≈ sin(-1.4 * 0.7) + cos(-1.4)
    @test clifford[2][2] ≈ sin(1.6) + 0.7 * cos(1.6 * 0.7)
    @test isempty(clifford_points(iterations=0, discard=0))
    @test_throws ArgumentError clifford_points(iterations=-1)
    @test_throws ArgumentError clifford_points(discard=-1)
    @test_throws ArgumentError clifford_points(a=Inf)

    dejong = dejong_points(iterations=2, discard=0)
    @test dejong[1] == (-1.0, -1.0)
    @test dejong[2][1] ≈ sin(2.24) - cos(-0.43)
    @test dejong[2][2] ≈ sin(0.65) - cos(2.43)
    @test length(dejong_points(iterations=5, discard=0)) == 5
    @test_throws ArgumentError dejong_points(discard=-1)
    @test_throws ArgumentError dejong_points(d=NaN)

    @test generate_points("Clifford"; iterations=3, discard=0) ==
          clifford_points(iterations=3, discard=0)
    @test generate_points(:dejong; iterations=3, discard=0) ==
          dejong_points(iterations=3, discard=0)
end

@testset "ODE attractors" begin
    @test available_systems() ==
          (:clifford, :dejong, :henon, :lorenz, :rossler, :thomas)
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
    @test_throws ArgumentError ode_points(
        oscillator!,
        [1.0, 0.0];
        dt=big"1e-1000",
    )
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

    mktemp() do path, io
        close(io)
        write_svg(
            path,
            [(0.0, 0.0), (1.0, 1.0), (2.0, 0.0)];
            width=320,
            height=240,
            color_values=[0.0, 0.5, 1.0],
            colorbar_label="a&b",
        )
        svg = read(path, String)
        @test occursin("#440154", svg)
        @test occursin("#fde725", svg)
        @test occursin(">a&amp;b</text>", svg)
    end

    @test_throws ArgumentError write_svg("unused.svg", [(0.0, Inf)])
    @test_throws ArgumentError write_svg("unused.svg", [(0im, 0im)])
    @test_throws ArgumentError write_svg("unused.svg", NTuple{2, Float64}[]; width=0)
    @test_throws ArgumentError write_svg(
        "unused.svg",
        [(0.0, 0.0), (1.0, 1.0)];
        color_values=[0.0],
    )
end

function read_png_uint32(bytes, offset)
    return (UInt32(bytes[offset]) << 24) |
           (UInt32(bytes[offset + 1]) << 16) |
           (UInt32(bytes[offset + 2]) << 8) |
           UInt32(bytes[offset + 3])
end

function read_png_chunks(bytes)
    chunks = Dict{String, Vector{UInt8}}()
    index = 9
    while index <= length(bytes)
        chunk_length = Int(read_png_uint32(bytes, index))
        chunk_name = String(bytes[(index + 4):(index + 7)])
        data_start = index + 8
        data_end = data_start + chunk_length - 1
        data = bytes[data_start:data_end]
        stored_crc = read_png_uint32(bytes, data_end + 1)
        chunk_type = collect(codeunits(chunk_name))
        @test stored_crc == StrangeArt._png_crc32(vcat(chunk_type, data))
        chunks[chunk_name] = data
        index = data_end + 5
        chunk_name == "IEND" && break
    end
    return chunks
end

@testset "PNG parameter-sweep export" begin
    mktempdir() do directory
        path = joinpath(directory, "sweep.png")
        @test write_sweep_png(
            path,
            [(0.0, 0.0), (1.0, 1.0)];
            color_values=[0.0, 1.0],
            colorbar_label="a",
            width=320,
            height=240,
            dpi=300,
            bounds=(-2.0, 2.0, -2.0, 2.0),
        ) == path

        bytes = read(path)
        @test bytes[1:8] == UInt8[0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]
        chunks = read_png_chunks(bytes)
        @test read_png_uint32(chunks["IHDR"], 1) == 320
        @test read_png_uint32(chunks["IHDR"], 5) == 240
        @test chunks["IHDR"][10] == 2
        @test read_png_uint32(chunks["pHYs"], 1) == round(UInt32, 300 / 0.0254)
        @test chunks["pHYs"][9] == 1
        @test !isempty(chunks["IDAT"])
    end

    @test_throws ArgumentError write_sweep_png(
        "unused.png",
        [(0.0, 0.0), (1.0, 1.0)];
        color_values=[1.0],
    )
    @test_throws ArgumentError write_sweep_png(
        "unused.png",
        [(0.0, 0.0)];
        color_values=[1.0],
        dpi=0,
    )
    @test_throws ArgumentError write_sweep_png(
        "unused.png",
        [(0.0, 0.0)];
        color_values=[1.0],
        bounds=(-2.0, -2.0, -1.0, 1.0),
    )
end

@testset "Density grid and PNG export" begin
    grid = density_grid(
        [(0.0, 0.0), (0.0, 0.0), (1.0, 0.0), (2.0, 1.0), (3.0, 1.0)];
        width=3,
        height=2,
        bounds=(0.0, 2.0, 0.0, 1.0),
    )
    @test size(grid) == (2, 3)
    @test grid[2, 1] == 2
    @test grid[2, 2] == 1
    @test grid[1, 3] == 1
    @test sum(grid) == 4

    singleton = density_grid([(1.0, 1.0)]; width=3, height=3)
    @test singleton[2, 2] == 1
    @test sum(singleton) == 1

    pixels = StrangeArt._density_png_pixels(UInt32[0 1 2], :linear)
    @test pixels[1, 1, :] == UInt8[0x0b, 0x10, 0x20]
    @test pixels[1, 2, :] != pixels[1, 3, :]

    mktempdir() do directory
        path = joinpath(directory, "density.png")
        @test write_density_png(path, grid; dpi=150) == path
        chunks = read_png_chunks(read(path))
        @test read_png_uint32(chunks["IHDR"], 1) == 3
        @test read_png_uint32(chunks["IHDR"], 5) == 2
        @test read_png_uint32(chunks["pHYs"], 1) == round(UInt32, 150 / 0.0254)
        @test !isempty(chunks["IDAT"])
    end

    @test_throws ArgumentError density_grid(Tuple[])
    @test_throws ArgumentError density_grid([(0.0, Inf)])
    @test_throws ArgumentError density_grid(
        [(0.0, 0.0)];
        bounds=(0.0, 0.0, -1.0, 1.0),
    )
    @test_throws ArgumentError write_density_png("unused.png", [-1 1])
    @test_throws ArgumentError write_density_png("unused.png", [0 1]; scale=:sqrt)
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
    label = zeros(UInt8, 20, 220)
    @test StrangeArt._draw_gif_text!(label, "a=1.3 b=2.5 c=2.4 d=-2.1") === label
    @test any(==(0xff), label)

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

        palette_path = joinpath(directory, "custom-palette.gif")
        palette = StrangeArt._gif_palette()
        palette[2] = StrangeArt._GifColor(0x12, 0x34, 0x56)
        @test StrangeArt._encode_gif(
            palette_path,
            fill(UInt8(1), 2, 2, 1);
            palette,
        ) == palette_path
        @test read(palette_path)[17:19] == UInt8[0x12, 0x34, 0x56]

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

        for system in (:clifford, :dejong)
            path = joinpath(directory, "$system.gif")
            @test write_transition_gif(
                path;
                system,
                frames=2,
                points=20,
                width=160,
                height=80,
            ) == path
            @test gif_frame_count(read(path)) == 2
        end
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
