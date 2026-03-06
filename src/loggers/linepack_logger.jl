export LinepackLogger

struct LinepackLogger <: Logger
    linepack::Vector{Float64}
    time::Vector{Float64}
end

function LinepackLogger(; kwargs...)
    LinepackLogger(Float64[],Float64[])
end

#=
function record!(logger::LinepackLogger, sys::PowerSystem, t::Float64)
end
=#

function record!(logger::LinepackLogger, gas_sys::LinepackModel, t::Float64)
    push!(logger.linepack, gas_sys.linepack)
    push!(logger.time, t)
end


function record!(logger::LinepackLogger, gas_sys::GasNetworkModel, t::Float64)
    push!(logger.linepack, get_linepack(gas_sys::GasNetworkModel))
    push!(logger.time, t)
end
