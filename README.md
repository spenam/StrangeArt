# StrangeArt

Generate 2D art from strange attractors with Julia. Hénon is simulated as a
discrete map; continuous systems use the modular `OrdinaryDiffEqVerner` package
and `SciMLBase` instead of the full `OrdinaryDiffEq` bundle. The orbit is
written to a standalone SVG.

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
julia --project=. bin\strange-art.jl lorenz.svg --system lorenz
```

Available systems are `henon`, `lorenz`, `rossler`, and `thomas`. The three ODE
systems use the adaptive Verner `Vern7` method and render the x-y projection.
Open the resulting SVG in a browser or vector graphics editor. The default
Hénon run discards the first 1,000 iterations and plots the next 100,000 points.

For custom ODE systems with two or more state variables, provide an in-place
right-hand side and parameters:

```julia
using StrangeArt

custom_system!(du, u, p, t) = (du[1] = p * u[2]; du[2] = -p * u[1])
points = ode_points(custom_system!, (1.0, 0.0); p=1.0)
```

`ode_points` returns the first two state variables as x-y; use `duration`,
`dt`, and `discard` to control integration and transient removal. You can pass
a different `solver` algorithm if you add its package to the project.

## Run tests

```powershell
julia --project=. test\runtests.jl
```

The attractor generators and SVG writer are in `src/StrangeArt.jl`. ODE
generators accept `duration`, `dt`, and `discard` keywords; system parameters
and initial states can also be customized through `generate_points`.
