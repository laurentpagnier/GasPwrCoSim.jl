export SimpleController

struct SimpleController <: Controller
end


function control!(model::Union{CongestionFreeModel,OPFModel}, controller::SimpleController, t)
    demand = get_current_demand(model, t)
    if typeof(model) == OPFModel
        demand = model.PMModel["baseMVA"] * sum([v for (i,v) in demand])
    end
    avail_act = 5
    units = model.units
    action = repeat([:do_nothing],length(units))
    sense, amount = trival_fleet_adjustment(model, demand)
    if sense == :start
        pool = findall([u.status == :off for u in units])
        while amount > 0
            if avail_act == 0 || isempty(pool)
                 break   
            end
            id = rand(pool)
            action[id] = :start_main
            deleteat!(pool, pool .== id)
            avail_act -= 1
            amount -= units[id].pmax
        end    
    elseif sense == :shutdown
        # first stop unit running on gas
        pool = findall([u.status == :main_fuel for u in units])
        while amount > 0
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
        action_on_unit!(units[i], a)
    end
    nothing
end

function trival_fleet_adjustment(model, demand)
    gen_min = [is_generating(u) ? u.pmin : 0.0 for u in model.units] |> sum
    gen_max = [is_generating(u) ? u.pmax : 0.0 for u in model.units] |> sum
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
    nothing
end


#=
function control!(model::GasNetworkModel, controller::SimpleController, t)
    for i in keys(model.gas_injections)
        pressure = model.nodal_pressure[i]
        if pressure < 60.0
            model.gas_injections[i] = model.max_injections[i]
        elseif 80.0 < pressure
            model.gas_injections[i] = 0.0
        end
    end
    nothing
end
=#
