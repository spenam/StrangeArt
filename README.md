# StrangeArt

Generate 2D art from strange attractors with Julia. Hénon is simulated as a
discrete map; continuous systems use the modular `OrdinaryDiffEqVerner` package
and `SciMLBase` instead of the full `OrdinaryDiffEq` bundle. The orbit is
written to a standalone SVG. Parameter-sweep animations are available as GIFs
without a high-level image-processing dependency; giflib is supplied by the
small `Giflib_jll` package.

## Set up

With Julia installed, instantiate the project dependencies from the repository
root:

```powershell
julia --project=. -e "using Pkg; Pkg.instantiate()"
```

## Generate an image

Hénon remains the default:

```powershell
julia --project=. bin\strange-art.jl henon.svg
```

Select a continuous-time system with `--system`:

```powershell
julia --project=. bin\strange-art.jl lorenz.svg --system lorenz --points 50000 --projection xz
```

Available systems are `henon`, `lorenz`, `rossler`, and `thomas`. The three ODE
systems use the adaptive Verner `Vern7` method and default to the x-y
projection. Open the resulting SVG in a browser or vector graphics editor. The
default Hénon run discards the first 1,000 iterations and plots the next
100,000 points.
Use `--points` to choose the number of plotted points. For ODE systems this
samples evenly from the end of the transient to the end of the integration;
for Hénon it sets the number of iterations retained after burn-in. ODE systems
also accept `--projection xy`, `xz`, or `yz`; Hénon is 2D and only supports `xy`.

Use a `.gif` output path to create a parameter-sweep animation. The default
sweep controls are Hénon's `a` (0.8 to 1.4), Lorenz's `rho` (20 to 28),
Rössler's `c` (2 to 6), and Thomas's `b` (0.32 down to 0.18):

```powershell
julia --project=. bin\strange-art.jl lorenz-transition.gif --system lorenz --values "20,24,24.7,24.74,24.8,28" --points 10000
julia --project=. bin\strange-art.jl transitions.gif --system all --frames 24
```

By default, the selected system's control parameter is sampled evenly across
its default range. Use `--values` with a comma-separated list to choose the
exact values (and thus the number of frames), which lets you concentrate
samples wherever the behavior changes quickly. For example, the Lorenz
sequence above adds several values near `rho=24.74`. `--values` cannot be
combined with `--frames`, `--start`, or `--stop`, and applies to one system at
a time. Otherwise, `--frames` chooses the sample count and `--start`/`--stop`
override the range. `--delay` sets the frame delay in centiseconds, and
`--projection` selects the ODE projection. `--points` sets the number of orbit
samples in each frame.
With `--system all`, four files are written using the output path as a prefix
(for example, `transitions-lorenz.gif`); use the default `xy` projection so it
also works for the 2D Hénon system. GIF dimensions are currently fixed at
480×360 pixels.

For a reusable batch of parameter-colored PNGs, edit the per-system value lists
and settings in `scripts/generate-all-attractors.jl`, then run:

```powershell
julia --project=. scripts\generate-all-attractors.jl
```

The script overlays each system's parameter sweeps in one raster image. Point
color indicates the parameter value using a perceptually uniform, viridis-like
palette sampled uniformly along its Oklab color path; a color bar identifies
the range. It writes 2400×2400 PNGs with 300 DPI resolution metadata to
`generated-art/`, which is ignored by Git.

For custom ODE systems with two or more state variables, provide an in-place
right-hand side and parameters:

```julia
using StrangeArt

custom_system!(du, u, p, t) = (du[1] = p * u[2]; du[2] = -p * u[1])
points = ode_points(custom_system!, (1.0, 0.0); p=1.0)
```

`ode_points` returns the selected state variables as a 2D projection. Use
`duration`, `dt`, and `discard` to control integration and transient removal.
You can pass a different `solver` algorithm if you add its package to the project.

## Project layout

- `src/StrangeArt.jl` assembles the module and exports its public API.
- `src/attractors/` contains the individual attractors, shared ODE integration,
  and system registry.
- `src/rendering/` contains SVG, PNG, and GIF output code.
- `src/animation/` contains parameter-sweep generation for transition GIFs.
- `bin/` contains the command-line interface, `scripts/` contains reusable
  batch generation, and `test/` contains tests.

To add a built-in system, put its generator in `src/attractors/` and register
it in `src/attractors/registry.jl`.

The Julia REPL exposes API descriptions through help mode, for example
`?ode_points`, `?write_svg`, or `?write_transition_gif`.

## Run tests

```powershell
julia --project=. test\runtests.jl
```

The attractor generators and renderers are assembled in `src/StrangeArt.jl`.
ODE generators accept `duration`, `dt`, and `discard` keywords; system
parameters and initial states can also be customized through `generate_points`.
