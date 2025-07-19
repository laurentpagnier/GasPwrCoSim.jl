export OPFModel

import Interpolations.LinearInterpolation
import Interpolations.Extrapolation
using Ipopt

include("opf_util.jl")
include("unit.jl")

(dic::Dict{String, <:Extrapolation})(t::T)  where T <: Real = Dict([k => v(t) for (k,v) in dic])

mutable struct OPFModel <: PowerSystem
    units::Vector{Unit}
    demand::Union{Dict{String,<:Extrapolation}, Dict{String, Function}}
    PMModel::Dict{String, Any} # a PowerModels model
    reserve::Float64
end


function OPFModel(;
        pwr_folder = "../data/power_data",
        MP_case = "../data/Israeli Grid New/israel.json",
        reserve = 450.0, # in MW 
        dt = 5, # min
        init_interval = nothing,
        #elc_demand = t -> 10_000.0, # MW
        load_shedding_cost = 20_000.0, # $/MWh
        kwargs...
    ) 
      
    df = DataFrame(CSV.File(joinpath(pwr_folder, "demand_profile.csv")))
    elc_demand = Dict([k => LinearInterpolation(df[:,:time], df[:,Symbol(k)]./100)  for k in setdiff(names(df), ["time"])]) # 100 = BaseMVA
    PMModel = PowerModels.parse_file(MP_case)
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



function reset!(model::OPFModel)
    model.units .|>  u -> u.status = :off

    update_demand!(model::OPFModel, 0.0)
    demand = 0.0
    sb = model.PMModel["baseMVA"]
    for (i, l) in model.PMModel["load"]
        demand += sb*l["pd"]
    end
    reserve = model.reserve
    units = model.units
    gen = 0
    pool = collect(1:length(units))
    while gen < demand + reserve && !isempty(pool)
        id = rand(pool)
        deleteat!(pool, findfirst(pool .== id))
        units[id].status = :main_fuel 
        gen += units[id].pmax
    end
    nothing
end


function display(model::OPFModel)
    n_main = [u.status == :main_fuel for u in model.units] |> sum
    n_sec = [u.status == :sec_fuel for u in model.units] |> sum
    n_off = [u.status == :off for u in model.units] |> sum
    demand = [l["pd"] for (i,l) in model.PMModel["load"]] |> sum
    demand = round(Int, model.PMModel["baseMVA"] * demand)
    shed =  round(Int, get_sys_shedding(model))
    print("fleet=($n_main,$n_sec,$n_off) | shed=$shed | demand=$demand")
end

