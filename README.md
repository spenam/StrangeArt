# StrangeArt

Generate 2D art from strange attractors with Julia. The first version simulates
the Hénon map and writes its orbit as a standalone SVG, with no external
packages required.

## Generate an image

With Julia installed, run this from the repository root:

```powershell
julia --project=. bin\strange-art.jl henon.svg
```

Open `henon.svg` in a browser or vector graphics editor. The default run
discards the first 1,000 iterations and plots the next 100,000 points.

## Run tests

```powershell
julia --project=. test\runtests.jl
```

The simulation and SVG writer are in `src/StrangeArt.jl`. The next steps can
build on this small base with adjustable parameters, other attractors, and
additional rendering options.
