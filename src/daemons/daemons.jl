struct NoDaemon <: Daemon
    dummy::String # prevent recursive error
end

function NoDaemon(;kwargs...)
    NoDaemon("dummy")
end

function perturb!(daemon::Daemon, system::Union{PowerSystem,GasSystem}, t::Float64)
    nothing # by default nothing nothing
end


include("fixeddurationfault.jl")
