export SimpleController
using GasPwrCoSim

mutable struct SimpleController <: GasPwrCoSim.Controller
    max_act::Int
    emergency_mode::Symbol
end

function SimpleController(; max_act= 5, kwargs...)
    return SimpleController(max_act, :regular)
end

function reset!(controller::SimpleController)
    controller.emergency_mode = :regular
end

function display(controller::SimpleController)
    print("status=$(controller.emergency_mode) | ")
end

function control!(model::Union{CongestionFreeModel,OPFModel}, controller::SimpleController, t)
    demand = GasPwrCoSim.get_current_demand(model, t)
    if typeof(model) == OPFModel
        demand = model.PMModel["baseMVA"] * sum([v for (i,v) in demand])
    end
    avail_act = copy(controller.max_act)
    units = model.units
    action = repeat([:do_nothing],length(units))
    
    if controller.emergency_mode == :emergency
        # check if in a load shed situation
        #k = controler.max_act
        avail_units = findall([u.status == :main_fuel for u in units])
        #avail_units = findall((env.params.class .== policy.favored_class) .& is_on_main)
        n = length(avail_units)
        if avail_act > 0 && length(avail_units) > 0
            id = rand(1:length(avail_units))
            action[avail_units[id]] = :transition
            deleteat!(avail_units, id)
            avail_act -= 1
            # TODO better selection based on pressures (min first)
        end

    end
    
    sense, amount = trival_fleet_adjustment(model, demand)
    if sense == :start
        pool = findall([u.status == :off for u in units])
        while amount > 0.0
            if avail_act == 0 || isempty(pool)
                 break   
            end
            id = rand(pool)
            action[id] = controller.emergency_mode == :regular ? :start_main : :start_sec
            deleteat!(pool, pool .== id)
            avail_act -= 1
            amount -= units[id].pmax
        end    
    elseif sense == :shutdown
        # first stop unit running on gas
        
        pool = findall([u.status ∈ [:main_fuel, :sec_fuel] for u in units])
        while amount > 0.0
            if avail_act == 0 || isempty(pool)
                 break   
            end
            id = rand(pool)
            action[id] = :shutdown
            deleteat!(pool, pool .== id)
            avail_act -= 1
            amount -= units[id].pmax
        end
    end

    for (i, a) in enumerate(action)
        GasPwrCoSim.action_on_unit!(units[i], a)
    end
    nothing
end

function trival_fleet_adjustment(model, demand)
    gen_min = [GasPwrCoSim.is_generating(u) ? u.pmin : 0.0 for u in model.units] |> sum
    gen_max = [GasPwrCoSim.is_generating(u) ? u.pmax : 0.0 for u in model.units] |> sum
    reserve = model.reserve
    if  demand  < gen_min
        amount = gen_min - demand
        return :shutdown, amount
    elseif gen_max < demand + reserve
        amount = demand + reserve - gen_max
        return :start, amount
    else
        return :do_nothing, 0. 
    end
end



function control!(model::LinepackModel, controller::SimpleController, t)
    if model.linepack < 50_000 
        model.injection = model.max_injection
    elseif model.linepack > 60_000 
        model.injection = 0.0
    end
    
    if model.linepack < 40_000 && controller.emergency_mode == :regular
        controller.emergency_mode = :emergency
    elseif model.linepack > 50_000 && controller.emergency_mode == :emergency
        controller.emergency_mode = :regular
    end
    nothing
end


function control!(model::GasNetworkModel, controller::SimpleController, t)
    above_min = true
    for i in keys(model.gas_injections)
        pressure = model.nodal_pressure[i]
        if pressure < 60.0
            model.gas_injections[i] = model.max_injections[i]
            above_min = false
        elseif 80.0 < pressure
            model.gas_injections[i] = 0.0
        end
        if pressure < 50.0 && controller.emergency_mode == :regular
            controller.emergency_mode = :emergency
        end
    end
    if above_min && controller.emergency_mode == :emergency
        controller.emergency_mode = :regular
    end
    nothing
end
