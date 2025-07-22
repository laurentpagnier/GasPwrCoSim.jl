export GasNetworkModel

using GasNetModel, ModelingToolkit

mutable struct GasNetworkModel <: GasSystem
    ginfo::GasInfo
    sys
    prob::ODEProblem
    u0::Vector{Float64} # the initial conditions
    sol::Union{Vector{Vector{Float64}},ModelingToolkit.ODESolution}
    nodal_pressure::Vector{Float64}
    nodal_flows::Vector{Float64}
    gas_injections::Dict{Int,Float64}
    max_injections::Dict{Int,Float64}
end

q_nodal_local = (i,t) -> 0.0 # will fix this later

function GasNetworkModel(;
        gas_folder = "../../GasNetModel.jl/data",
        duration = 96 * 15,
        dt = 15, # in min. duration of a step, not the dt used for the transient sim
        dx = 1_000, # in meters
        gas_injection = Dict{Int,Float64}(1 => 0.0, 8 => 0.0),
        max_injections = Dict{Int,Float64}(1 => 193.77, 8 => 290.83),
    )
        
    ginfo = GasInfo(gas_folder)
    T = dt * 60 # convert to seconds
    @mtkcompile sys = GasNetModel.GasSystem(ginfo=ginfo, dx=dx);
    tspan = (0.0, T);
    nodal_flows = copy(ginfo.nodes.initial_nodal_flow)
    q_nodal_local = (i,t) -> nodal_flows[i] 

    sys = substitute(sys, Dict(GasNetModel.q_nodal => q_nodal_local))
    # run a simulation with constant boundary cond to get steady initial cond
    prob = ODEProblem(sys, Dict(), (0, 40_000));
    sol = solve(prob, save_everystep=false, save_start=false)
    u0 = sol.u[end]
    
    n_sub = size(ginfo.nodes,1)
    nodal_pressure = zeros(n_sub) # will be populated later

    gas_sys = GasNetworkModel(ginfo, sys, prob, u0, sol,
        nodal_pressure, nodal_flows, gas_injection, max_injections)

    #redefine the problem to be based on directly on gas_sys quantities
    # TODO see if there is a cleaner way to do that
    @mtkcompile sys = GasNetModel.GasSystem(ginfo=ginfo, dx=dx);
    q_nodal_local = (i,t) -> gas_sys.nodal_flows[i] 
    gas_sys.sys = substitute(sys, Dict(GasNetModel.q_nodal => q_nodal_local))
    gas_sys.prob = ODEProblem(gas_sys.sys, gas_sys.u0, (0, T))
    gas_sys
end


function reset!(model::GasNetworkModel)
    model.sol = [copy(model.u0)]
    nothing
end

function step!(pwr_sys::CongestionFreeModel, gas_sys::GasNetworkModel, t)
    # power dispatch, etc.
    step!(pwr_sys, t)
    
    # compute the gas gas_withdrawal based on the power dispatch
    gas_sys.nodal_flows[:] .= 0.0 # reset
    for u in pwr_sys.units
        if u.status == :main_fuel
            coeff = 1.0
        elseif contains(string(u.status), "toward_sec")
            # symbols follow the convention toward_sec_n, thus convert the n into an integer
            n = parse(Float64, string(u.status)[12:end])
            coeff = n / (u.trans_steps + 1) # assuming it goes form 0 to 100 in n+1 steps
        else
            coeff = 0.0
        end
        gas_sys.nodal_flows[u.gas_loc] -= coeff * u.fuel_input(u.p)
    end
    
    # add gas injection (if any)
    for (i, inj) in gas_sys.gas_injections
        gas_sys.nodal_flows[i] += inj
    end
    # run gas simulation
    run_gas_step!(gas_sys)
    
    #update nodal pressures and shutdown unit if local pressure is too low
    get_nodal_pressure!(gas_sys)
    for u in pwr_sys.units
        if gas_sys.nodal_pressure[u.gas_loc] < u.pressure_out && is_on_gas(u)
            u.status = :off
        end
    end
    nothing
end

function get_nodal_pressure!(gas_sys::GasNetworkModel)
    ginfo = gas_sys.ginfo
    a = GasNetModel.get_speed_of_sound(ginfo)
    vars = unknowns(gas_sys.sys)
    ρ_vars = filter(x -> contains(string(x.metadata[ModelingToolkit.VariableSource][2]), "sub"), vars) # assumes that ρ is the only variable
    ρ_vars = sort(ρ_vars, by = x -> x.metadata[ModelingToolkit.VariableSource][2] |> 
        string |> x -> x[5:findfirst("₊", x)[1]-1] |> x->parse(Int,x)) # assume sub_xx₊ρ naming convention
    ρ = gas_sys.sol[ρ_vars][1]
    gas_sys.nodal_pressure[:] .= ρ * a^2 * 1E-5  # in bar
    nothing
end


function run_gas_step!(gas_sys::GasNetworkModel)
    prob = gas_sys.prob
    T = prob.tspan[end]
    gas_sys.sol = solve(prob, save_everystep=false, save_start=false)
    get_nodal_pressure!(gas_sys)
    nothing
end

function display(model::GasNetworkModel)
    pressure = model.nodal_pressure
    pmin, pmax = round(10*minimum(pressure))/10, round(10*maximum(pressure))/10
    inj = values(model.gas_injections) |> sum
    print("pressure=($pmin, $pmax) | inj=$inj | ")
end
