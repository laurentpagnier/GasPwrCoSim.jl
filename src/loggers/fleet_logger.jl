export FleetLogger

mutable struct FleetLogger <: Logger
    main::Vector{Int}
    sec::Vector{Int}
    off::Vector{Int} # start as sec
    twd_m::Vector{Int} # transition towards main
    twd_s::Vector{Int} # transition towards main
    st_m::Vector{Int} # start as main
    st_s::Vector{Int} # start as sec
    time::Vector{Float64}
end

function FleetLogger(; kwargs...)
    FleetLogger(Int[], Int[], Int[], Int[], Int[], Int[], Int[], Float64[])
end

function reset!(logger::FleetLogger)
    logger.main = Int[]
    logger.sec = Int[]
    logger.off = Int[]
    logger.twd_m = Int[]
    logger.twd_s = Int[]
    logger.st_m = Int[]
    logger.st_s = Int[]
	logger.time = Float64[]
end


function record!(logger::FleetLogger, elc_sys::Union{CongestionFreeModel,OPFModel}, t::Float64) 
    push!(logger.main, sum([is_on_main(u) for u in elc_sys.units]))
    push!(logger.sec, sum([is_on_sec(u) for u in elc_sys.units]))
    push!(logger.off, sum([is_offline(u) for u in elc_sys.units]))
    push!(logger.twd_m, sum([is_trans_main(u) for u in elc_sys.units]))
    push!(logger.twd_s, sum([is_trans_sec(u) for u in elc_sys.units]))
    push!(logger.st_m, sum([is_start_main(u) for u in elc_sys.units]))
    push!(logger.st_s, sum([is_start_sec(u) for u in elc_sys.units]))
    push!(logger.time, t)
end

