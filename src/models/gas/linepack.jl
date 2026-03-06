export LinepackModel

mutable struct LinepackModel <: GasSystem
    linepack::Float64
    initial_linepack::Union{Float64, ClosedInterval{Float64}}
    injection::Float64
    max_injection::Float64
    dt::Float64 # in sec to be consistent the network sim and unit fuel input
end


function LinepackModel(;
    gas_folder = "../data/gas_data",
    initial_linepack = 4.21E6, # in kg
    max_injection = 484.6, # in kg/s 
    dt = 5, # still in min
    kwargs...
)
    injection = 0.0
    LinepackModel(initial_linepack, initial_linepack, injection, max_injection, dt*60)
end


function reset!(model::LinepackModel)
    model.linepack = typeof(model.initial_linepack) == Float64 ? model.initial_linepack :
        rand(model.initial_linepack)
end

#=
function step!(pwr_sys::CongestionFreeModel, gas_sys::LinepackModel, t)
    # power dispatch, etc.
    step!(pwr_sys, t)
    
    # compute the gas gas_withdrawal
    for u in pwr_sys.units
        if u.status == :main_fuel
            coeff = 1.0
        elseif contains(string(u.status), "toward_sec")
            # symbols follow toward_sec_n, convert the n into an integer
            n = parse(Float64, string(u.status)[12:end])
            coeff = n / (u.trans_steps + 1)
        else
            coeff = 0.0
        end
        gas_sys.linepack -= coeff * u.fuel_input(u.p)
    end
    
    # add gas injection (if any)
    gas_sys.linepack += gas_sys.injection 
    
    gas_sys.linepack = max(gas_sys.linepack, 0.0)

    # if linepack exhausted, stop remaining units
    for u in pwr_sys.units
        if gas_sys.linepack == 0 && is_on_gas(u)
            u.status = :off
        end
    end
    nothing
end
=#

function step!(pwr_sys::Union{OPFModel,CongestionFreeModel}, gas_sys::LinepackModel, t)
    # power dispatch, etc.
    step!(pwr_sys, t)
    
    # compute the gas gas_withdrawal
    gas_withdrawal = 0.0
    for u in pwr_sys.units
        if u.status == :main_fuel
            coeff = 1.0
        elseif contains(string(u.status), "toward_sec")
            # symbols follow toward_sec_n, convert the n into an integer
            n = parse(Float64, string(u.status)[12:end])
            coeff = n / (u.trans_steps + 1)
        else
            coeff = 0.0
        end
        gas_withdrawal += coeff * u.fuel_input(u.p)
    end
    
    # injection and withdrawal are assumed to be constant over the step step
    gas_sys.linepack += (gas_sys.injection - gas_withdrawal) * gas_sys.dt
    gas_sys.linepack = max(gas_sys.linepack, 0.0)

    # if linepack exhausted, stop remaining units
    for u in pwr_sys.units
        if gas_sys.linepack == 0 && is_on_gas(u)
            u.status = :off
        end
    end
    nothing
end




function display(model::LinepackModel)
    linepack = model.linepack
    print("linepack=$(round(Int,linepack)) | inj=$(model.injection) | ")
end
