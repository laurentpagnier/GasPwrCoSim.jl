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

function control!(model::CongestionFreeModel, controller::SimpleController, t)
    
    avail_act = copy(controller.max_act)
    units = model.units
    action = repeat([:do_nothing],length(units))
    
    if controller.emergency_mode == :emergency
        # check if in a load shed situation
        #k = controler.max_act
        avail_units = findall([u.status == :main_fuel for u in units])
        #avail_units = findall((env.params.class .== policy.favored_class) .& is_on_main)
        n = length(avail_units)
        while avail_act > 0 && length(avail_units) > 0
            id = rand(1:length(avail_units))
            action[avail_units[id]] = :transition
            deleteat!(avail_units, id)
            avail_act -= 1
            # TODO better selection based on pressures (min first)
        end
    end
    demand = GasPwrCoSim.get_current_demand(model, t)
    direction, amount = trival_fleet_adjustment(model, demand)
    if direction == :startup
        pool = findall([u.status == :offline for u in units])
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
    elseif direction  == :shutdown
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


function GasPwrCoSim.control!(model::OPFModel, controller::SimpleController, t)
    # prepare the PMModel to run an OPF
    #=
    GasPwrCoSim.update_demand!(model, t)
    # reset the MP case and and run an OPF
    for (i, g) in model.pwr_sys.PMModel["gen"]
        if "shed_g" ∈ keys(g)
            g["shed_g"] = 0.0 # reset
        end
        g["pg"] = 0.0 # reset power outputs
    end
    for (i, l) in model.pwr_sys.PMModel["load"]
        if "shed" ∈ keys(l)
            l["shed"] = 0.0 # reset
        end
    end
    =#
    
    avail_act = copy(controller.max_act)
    units = model.units
    action = repeat([:do_nothing],length(units))
    
    if controller.emergency_mode == :emergency
        # check if in a load shed situation
        #k = controler.max_act
        avail_units = findall([u.status == :main_fuel for u in units])
        #avail_units = findall((env.params.class .== policy.favored_class) .& is_on_main)
        n = length(avail_units)
        while avail_act > 0 && length(avail_units) > 0
            id = rand(1:length(avail_units))
            action[avail_units[id]] = :transition
            deleteat!(avail_units, id)
            avail_act -= 1
            # TODO better selection based on pressures (min first)
        end
    end
    
    ptdf = calc_eigen_ptdf(model.PMModel)
    demand = model.PMModel["baseMVA"] * sum([v for (i,v) in  GasPwrCoSim.get_current_demand(model, t)])
    direction, amount = GasPwrCoSim.trival_fleet_adjustment(model, demand)
    # select units to shut based on their effects on
    # normalized flows
    fn = zeros(length(model.PMModel["branch"]))
    fmax = zeros(length(model.PMModel["branch"]))
    for (i,b) in model.PMModel["branch"]
        fn[parse(Int, i)] = b["pf"] / b["rate_a"]
        fmax[parse(Int, i)] = b["rate_a"]
    end
     
    bus_id = [g["gen_bus"] for (i, g) in model.PMModel["gen"]]
    fnabs = sort(abs.(fn), rev=true)
    selected = max(findfirst( fnabs .< 0.9), 5) # any number of 90% or more or 5 lines
    id_perm = sortperm(abs.(fn), rev=true)
    f_sense = 2*(fn[id_perm[1:selected]] .> 0.0) .- 1 # will inverse the ptdf entries if flow is reverse
    
    if direction == :shutdown
        id_on = findall([u.status ∈ [:main_fuel, :sec_fuel] for u in units])
        sensitivity = vec(sum(f_sense .* ptdf[id_perm[1:selected],bus_id[id_on]], dims=1))
        sens_order = sortperm(sensitivity)
        i = 1
        while amount > 0.0  && i <= length(id_on) && avail_act > 0
            action[id_on[sens_order[i]]] = :shutdown
            amount -= units[id_on[sens_order[i]]].pmin
            avail_act -= 1
            i += 1
        end
    end

    if direction == :startup
        id_off = findall([u.status == :offline for u in units])
        sensitivity = vec(sum(f_sense .* ptdf[id_perm[1:selected],bus_id[id_off]], dims=1))
        sens_order = sortperm(sensitivity,rev=true)
        i = 1
        while amount > 0.0 && i <= length(id_off) && avail_act > 0
            action[id_off[sens_order[i]]] = controller.emergency_mode == :regular ? :start_main : :start_sec
            amount -= units[id_off[sens_order[i]]].pmax
            avail_act -= 1
            i += 1
        end
    end

    #=
    GasPwrCoSim.update_gen_status!(model.pwr_sys)

    res = GasPwrCoSim.solve_model(model.pwr_sys.PMModel, GasPwrCoSim.DCWithShedPPowerModel,
        GasPwrCoSim.optimizer_with_attributes(GasPwrCoSim.Ipopt.Optimizer, "print_level" =>0),
        GasPwrCoSim.build_opf_w_shed, setting=Dict("output" => Dict("duals" => true)))
    GasPwrCoSim.PowerModels.update_data!(model.pwr_sys.PMModel, res["solution"])
    =#

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
        return :startup, amount
    else
        return :do_nothing, 0. 
    end
end



function control!(model::LinepackModel, controller::SimpleController, t)
    if model.linepack < 3.789e6
        model.injection = model.max_injection
    elseif model.linepack > 4.21E6
        model.injection = 0.0
    end
    
    if model.linepack < 3.368e6 && controller.emergency_mode == :regular
        controller.emergency_mode = :emergency
    elseif model.linepack > 3.9995e6 && controller.emergency_mode == :emergency
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
