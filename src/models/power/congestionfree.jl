export CongestionFreeModel
import Interpolations.LinearInterpolation
import Interpolations.Extrapolation

include("unit.jl")

mutable struct CongestionFreeModel <: PowerSystem
    units::Vector{Unit}
    demand::Union{Extrapolation, Function}
    reserve::Float64
    generation::Float64
    load_shedding::Float64
    load_shedding_cost::Float64
end


function CongestionFreeModel(;
        pwr_folder = "../data/power_data",
        reserve = 450.0, # in MW 
        dt = 5, # min
        init_interval = nothing,
        elc_demand = t -> 10_000.0, # MW
        load_shedding_cost = 20_000.0, # $/MWh
        kwargs...
    ) 
      
    df = DataFrame(CSV.File(joinpath(pwr_folder, "demand.csv")))
    elc_demand = LinearInterpolation(df.var"time [s]", df.var"demand [MW]") 
    
    units = create_fleet(dt = dt)
    generation, load_shedding = 0., 0.
    pwr_sys = CongestionFreeModel(units, elc_demand, reserve, generation, load_shedding,
        load_shedding_cost)
end

function reset!(model::CongestionFreeModel)
    model.units .|>  u -> u.status = :off
    model.load_shedding = 0.0

    demand = get_current_demand(model, 0.0)
    reserve = model.reserve
    units =  model.units
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

function step!(model::CongestionFreeModel, t)
    # generation dispatch
    demand = get_current_demand(model, t)
    w = avail_capacity(model)
    p = w / sum(w) * demand   
    for (g, u) in enumerate(model.units)
        if is_generating(u)
            set_output!(u, p[g]) # this function makes sure that pmin <= p[g] <= pmax
        else
            u.p = 0.0
        end
    end
    
    # compute load_shedding
    gen = [u.p for u in model.units] |> sum
    model.load_shedding = max(demand - gen, 0.0)
    nothing
end


function get_sys_shedding(model::CongestionFreeModel)
    model.load_shedding
end

avail_capacity(model) = [is_generating(u) ? u.pmax : 0.0 for u in model.units]

get_current_demand(model, t::Float64) = model.demand(60*t)


function display(model::CongestionFreeModel)
    n_main = [u.status == :main_fuel for u in model.units] |> sum
    n_sec = [u.status == :sec_fuel for u in model.units] |> sum
    n_off = [u.status == :off for u in model.units] |> sum
    #shed = get_sys_shedding(model) < 1E-5 ? 0.0 : get_sys_shedding(model)
    shed = round(Int, get_sys_shedding(model)) 
    print("fleet=($n_main,$n_sec,$n_off) | shed=$shed | ")
end
