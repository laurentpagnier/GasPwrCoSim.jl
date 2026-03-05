export control!
struct NoController <: Controller
    dummy::String # prevent recursive error
end

function NoController(;kwargs...)
    NoController("dummy")
end

function reset!(controller::Controller)
    nothing # by default nothing nothing
end

function display(controller::Controller)
    nothing # by default nothing nothing
end

function control!(sys::Union{PowerSystem, GasSystem}, controller::Controller, t)
    if typeof(controller) == NoController
        return nothing
    else
        t_cont = typeof(controller)
        t_sys = typeof(sys)
        @error "$(t_cont) 's actuation on $(t_sys) is not defined, please define control!(sys::$(t_sys), cont::$(t_cont), t)"
    end
end

include("simple_controller.jl")
#include("scheduledplan.jl")

