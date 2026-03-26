export CombinedLogger

struct CombinedLogger <: Logger
    loggers::Dict{Symbol, Logger}
end

function record!(logger::CombinedLogger, sys::Union{PowerSystem, GasSystem}, t::Float64)
    for (tag, l) in logger.loggers
    	record!(l, sys, t)
    end
end

function CombinedLogger(;logger_list = [], kwargs...)
    loggers = Dict{Symbol, Logger}()
    for (tag, l) in logger_list
    	push!(loggers, tag => l())
    end
    CombinedLogger(loggers)
end

(l::CombinedLogger)(s::Symbol) = l.loggers[s]

function reset!(logger::CombinedLogger)
    for (tag, l) in logger.loggers
    	reset!(l)
    end
end
