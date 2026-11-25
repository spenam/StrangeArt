available_systems() = (:henon, :lorenz, :rossler, :thomas)

function generate_points(system::Union{Symbol, AbstractString}; kwargs...)
    selected = Symbol(lowercase(string(system)))
    selected === :henon && return henon_points(; kwargs...)
    selected === :lorenz && return lorenz_points(; kwargs...)
    selected === :rossler && return rossler_points(; kwargs...)
    selected === :thomas && return thomas_points(; kwargs...)

    options = join(string.(available_systems()), ", ")
    throw(ArgumentError("unknown attractor '$system'; choose one of: $options"))
end
