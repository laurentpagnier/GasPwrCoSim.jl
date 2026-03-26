export OPFModel

import Interpolations.LinearInterpolation
import Interpolations.Extrapolation
using Ipopt, SparseArrays, LinearAlgebra

include("opf_util.jl")

(dic::Dict{String, <:Extrapolation})(t::T)  where T <: Real = Dict([k => v(t) for (k,v) in dic])

mutable struct OPFModel <: PowerSystem
    units::Vector{Unit}
    demand::Union{Dict{String,<:Extrapolation}, Dict{String, Function}}
    PMModel::Dict{String, Any} # a PowerModels model
    reserve::Float64
end


function OPFModel(;
        pwr_folder = "../data/power_data",
        PM_case = "../data/power_data/network.json",
        reserve = 450.0, # in MW 
        dt = 5, # min
        init_interval = nothing,
        #elc_demand = t -> 10_000.0, # MW
        load_shedding_cost = 20_000.0, # $/MWh
        kwargs...
    ) 
      
    df = DataFrame(CSV.File(joinpath(pwr_folder, "demand_profile.csv")))
    elc_demand = Dict([k => LinearInterpolation(df[:,:time], df[:,Symbol(k)]./100)  for k in setdiff(names(df), ["time"])]) # 100 = BaseMVA
    PMModel = PowerModels.parse_file(PM_case)
    units = create_fleet(PMModel, dt = dt)
    add_energy_not_serve_price!(PMModel)
    pwr_sys = OPFModel(units, elc_demand, PMModel, reserve)
end


function update_demand!(model::OPFModel, t)
    for (i,d) in model.demand(60*t)
        model.PMModel["load"][i]["pd"] = d
    end
end

function update_gen_status!(model::OPFModel)
    for (i,u) in enumerate(model.units)
        if is_generating(u)
            model.PMModel["gen"]["$i"]["gen_status"] = 1
        else
            model.PMModel["gen"]["$i"]["gen_status"] = 0
        end
    end
end


function get_hourly_generation_cost(model::OPFModel)
    cost = 0.0
    sb = model.PMModel["baseMVA"]
    for (i, g) in model.PMModel["gen"]
        marginal_cost = is_on_gas(model.units[parse(Int,i)]) ? model.units[parse(Int,i)].cost[:main_cost] : 
            model.units[parse(Int,i)].cost[:sec_cost]
        cost += sb*g["pg"] * marginal_cost
    end
    cost
end

function get_hourly_shedding_cost(model::OPFModel)
    shed = 0.0
    sb = model.PMModel["baseMVA"]
    for (i,l) in model.PMModel["load"]
        shed += sb*l["shed"] * l["ENS_price"]
    end
    
    for (i,g) in model.PMModel["gen"]
        if "shed_g" ∈ keys(g)
            shed += sb*g["shed_g"] * 10000 #!!!!!! FIX THIS
        end
    end
    
    shed
end


function get_sys_shedding(model::OPFModel)
    shed = 0.0
    sb = model.PMModel["baseMVA"]
    for (i,l) in model.PMModel["load"]
        shed += sb*l["shed"]
    end
    shed
end

function step!(model::OPFModel, t)
    # update the PowerModels models
    update_demand!(model, t)
    update_gen_status!(model)
    for (i, g) in model.PMModel["gen"]
        g["pg"] = 0.0 # reset power outputs
    end
    
    # run an OPF with the updated model
    res = solve_model(model.PMModel, DCWithShedPPowerModel, optimizer_with_attributes(Ipopt.Optimizer, "print_level" =>0), build_opf_w_shed)

    PowerModels.update_data!(model.PMModel, res["solution"])
    for (i, g) in model.PMModel["gen"]
        model.units[parse(Int,i)].p = 100*g["pg"]
    end
    nothing
end


function create_fleet(
        model::Dict{String, Any};
        prob_per_class = Dict(
            :super_reliable => Dict(:p_abort => 0.01, :p_succ => 0.98, :p_fail => 0.01, :p_start => 0.95),
            :reliable => Dict(:p_abort => 0.05, :p_succ => 0.9, :p_fail => 0.05, :p_start => 0.90),
            :fairly_reliable => Dict(:p_abort => 0.10, :p_succ => 0.8, :p_fail => 0.10, :p_start => 0.80),
            :unreliable => Dict(:p_abort => 0.15, :p_succ => 0.70, :p_fail => 0.15, :p_start => 0.70)
        ),
        class = :reliable,
        dt = 5.0
)

    # load units
    sb = model["baseMVA"]
    units = Unit[]
    for (i, g) in model["gen"]
        push!(units, Unit(pmin = sb*g["pmin"], pmax = sb*g["pmax"],
            gas_loc = g["gas_loc"],
            cost = Dict(:main_cost => g["main_cost"], :sec_cost => g["sec_cost"]),
            prob = prob_per_class[Symbol(class)],
            trans_steps = div(g["transition_duration"], dt)-1,
            start_steps = div(g["start_duration"], dt)-1, pwr_bus = g["gen_bus"],)
            )
    end

    units
end


#=
function reset!(model::OPFModel)
    # For the time being the initial state is assumed to be the 
    # result of an OPF
    model.units .|>  u -> u.status = :offline

    update_demand!(model::OPFModel, 0.0)
    demand = 0.0
    sb = model.PMModel["baseMVA"]
    for (i, l) in model.PMModel["load"]
        demand += sb*l["pd"]
    end
    reserve = model.reserve
    units = model.units
    gen = 0.0
    pool = collect(1:length(units))
    while gen < demand + reserve && !isempty(pool)
        id = rand(pool)
        deleteat!(pool, findfirst(pool .== id))
        units[id].status = :main_fuel 
        gen += units[id].pmax
    end
    nothing
end
=#

function reset!(model::OPFModel)
    # start from an empty fleet
    model.units .|>  u -> u.status = :offline
    GasPwrCoSim.update_demand!(model, 0.0)
    demand = 0.0
    sb = model.PMModel["baseMVA"]
    for (i, l) in model.PMModel["load"]
        demand += sb*l["pd"]
    end
    reserve = model.reserve
    units = model.units
    gen = 0.0
    pool = collect(1:length(units))
    # add random units until gen capacity is sufficient
    while gen < demand + reserve && !isempty(pool)
        id = rand(pool)
        deleteat!(pool, findfirst(pool .== id))
        units[id].status = :main_fuel 
        gen += units[id].pmax
    end
    GasPwrCoSim.update_gen_status!(model)

    # reset the MP case and and run an OPF
    for (i, g) in model.PMModel["gen"]
        if "shed_g" ∈ keys(g)
            g["shed_g"] = 0.0 # reset
        end
        g["pg"] = 0.0 # reset power outputs
    end
    for (i, l) in model.PMModel["load"]
        if "shed" ∈ keys(l)
            l["shed"] = 0.0 # reset
        end
    end

    # run an OPF with the updated model
    res = solve_model(model.PMModel, GasPwrCoSim.DCWithShedPPowerModel,
        GasPwrCoSim.optimizer_with_attributes(GasPwrCoSim.Ipopt.Optimizer, "print_level" =>0),
        GasPwrCoSim.build_opf_w_shed, setting=Dict("output" => Dict("duals" => true)))
    
    PowerModels.update_data!(model.PMModel, res["solution"])

    missing_power = 0.0 
    for (i, g) in model.PMModel["gen"]
        if "shed_g" ∈ keys(g)
            if g["shed_g"] > 1E-3
                #missing_power += g["pg"] - g["shed_g"]
                missing_power += g["pmax"]
                model.units[parse(Int,i)].status = :off
            end
            g["shed_g"] = 0.0 # reset power outputs
        end
        g["pg"] = 0.0 # reset power outputs
    end

    for (i, l) in model.PMModel["load"]
        if "shed" ∈ keys(l)
            l["shed"] = 0.0 # reset
        end
    end

    # check congestion through line dual variables
    mu_fr = zeros(length(model.PMModel["branch"]))
    mu_to = zeros(length(model.PMModel["branch"]))
    
    for (i, b) in model.PMModel["branch"]
        mu_fr[parse(Int,i)] = b["mu_sm_fr"] 
        mu_to[parse(Int,i)] = b["mu_sm_to"]
    end

    id_off = findall([g["gen_status"] == 0 for (i, g) in model.PMModel["gen"]])
    bus_id = [g["gen_bus"] for (i, g) in model.PMModel["gen"]]

    id_to = findall(abs.(mu_to) .> 1E-3)
    id_fr = findall(abs.(mu_fr) .> 1E-3)

    #start units that reduce the congestion
    ptdf = calc_eigen_ptdf(model.PMModel)

    sensitivity = vec(sum([-ptdf[id_to, bus_id[id_off]];  ptdf[id_fr, bus_id[id_off]]], dims=1))
    sens_order = sortperm(sensitivity, rev=true)
    i = 1
    pos_contrib = sensitivity[sens_order[i]] > 0
    model.units[id_off[sens_order[i]]].status = :main_fuel
    missing_power -= model.units[id_off[sens_order[i]]].pmax / model.PMModel["baseMVA"]
    #while missing_power > 0 && pos_contrib
    while missing_power > 0
        i += 1
        model.units[id_off[sens_order[i]]].status = :main_fuel
        pos_contrib = sensitivity[sens_order[i]] > 0
        missing_power -= model.units[id_off[sens_order[i]]].pmax / model.PMModel["baseMVA"]
    end

    GasPwrCoSim.update_gen_status!(model)
    
    res = GasPwrCoSim.solve_model(model.PMModel, GasPwrCoSim.DCWithShedPPowerModel,
        GasPwrCoSim.optimizer_with_attributes(GasPwrCoSim.Ipopt.Optimizer, "print_level" =>0),
        GasPwrCoSim.build_opf_w_shed, setting=Dict("output" => Dict("duals" => true)))
    GasPwrCoSim.PowerModels.update_data!(model.PMModel, res["solution"])
end


function calc_eigen_ptdf(data)
    # this definition of the ptdf is equivalent to fully distributed
    # slack instead of the single slack implemented in MPs.jl
    id1 = Int[]
    id2 = Int[]
    id = Int[]
    b_vec = Float64[]
    n = length(data["branch"])
    for (i, b) in data["branch"]
        push!(id1, b["f_bus"])
        push!(id2, b["t_bus"])
        push!(id, b["index"])
        #push!(b_vec, 1 / b["br_x"])
        push!(b_vec,  -imag(1.0 / (b["br_r"] +im*b["br_x"])))
    end
    id_perm = sortperm(id)
    b_vec = b_vec[id_perm]
    
    B = sparse([id1[id_perm];id2[id_perm]], [1:n;1:n], [-ones(n);ones(n)])
    L =  B * (b_vec .* B')
    d, v = eigen(Matrix(L))
    d[abs.(d) .> 1E-4] =  1 ./ d[abs.(d) .> 1E-4]
    Linv = v * (d .* v')
    
    return b_vec .* (B'*Linv)
end


function display(model::OPFModel)
    n_main = [u.status == :main_fuel for u in model.units] |> sum
    n_sec = [u.status == :sec_fuel for u in model.units] |> sum
    n_off = [u.status == :offline for u in model.units] |> sum
    demand = [l["pd"] for (i,l) in model.PMModel["load"]] |> sum
    demand = round(Int, model.PMModel["baseMVA"] * demand)
    shed =  round(Int, get_sys_shedding(model))
    print("fleet=(main:$n_main, sec:$n_sec, off:$n_off) | shed=$shed | demand=$demand | ")
end

