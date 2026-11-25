"""
    available_systems()

Return the tuple of built-in attractor names accepted by [`generate_points`](@ref).
"""
available_systems() = (:clifford, :dejong, :henon, :lorenz, :rossler, :thomas)

"""
    generate_points(system; kwargs...)

Generate points for a built-in attractor, selected by a case-insensitive
symbol or string. Remaining keywords are forwarded to that system's generator.
Throws `ArgumentError` when `system` is not available.
"""
function generate_points(system::Union{Symbol, AbstractString}; kwargs...)
    selected = Symbol(lowercase(string(system)))
    selected === :clifford && return clifford_points(; kwargs...)
    selected === :dejong && return dejong_points(; kwargs...)
    selected === :henon && return henon_points(; kwargs...)
    selected === :lorenz && return lorenz_points(; kwargs...)
    selected === :rossler && return rossler_points(; kwargs...)
    selected === :thomas && return thomas_points(; kwargs...)

    options = join(string.(available_systems()), ", ")
    throw(ArgumentError("unknown attractor '$system'; choose one of: $options"))
end
