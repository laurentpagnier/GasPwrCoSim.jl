export Logger, NoLogger

struct NoLogger <: Logger
    dummy::String # prevent recursive error
end


function record!(logger::Logger, sys::Union{PowerSystem, GasSystem}, t::Float64)
    # if not defined do nothing
end


function NoLogger(;kwargs...)
    NoLogger("dummy")
end

include("combined_logger.jl")
include("linepack_logger.jl")
include("electric_logger.jl")
