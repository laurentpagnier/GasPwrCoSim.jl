export Unit

mutable struct Unit
    pmin::Real
    pmax::Real
    p::Real
    fuel_input::Function
    trans_steps::Int
    start_steps::Int
    cost::Dict{Symbol, Any}
    prob::Dict{Symbol, Any}
    pressure_out::Real
    gas_loc::Union{Int, Nothing}
    pwr_bus::Int
    status::Symbol
    state2int::Dict{Symbol, Int}
    int2state::Dict{Int, Symbol}
    act2int::Dict{Symbol, Int}
    int2act::Dict{Int, Symbol}
end


function Unit(;pmin = 75, pmax = 125, turbine_efficiency = 0.1,
    pressure_out = 50, gas_loc = nothing,  status=:off, p = 0.0,
    cost = Dict(:main_cost => 30, :sec_cost => 400),
    prob = Dict(:p_abort => 0.01, :p_succ => 0.98, :p_fail => 0.01, :p_start => 0.95),
    state2int = Dict{Symbol, Int}(:main_fuel => 1, :sec_fuel => 2, :off => 3),
    int2act = Dict{Int,Symbol}(1 => :do_nothing, 2 => :transition, 3 => :shutdown,
            4 => :start_main, 5 => :start_sec), 
    trans_steps = 1, start_steps = 1, pwr_bus = 0)
    
    # add the appropriated number of transition states
    for i = 1:trans_steps
        push!(state2int, Symbol("toward_sec_$i") => length(state2int)+1)
    end
    
    for i = 1:trans_steps
        push!(state2int, Symbol("toward_main_$i") => length(state2int)+1)
    end
    
    for i = 1:start_steps
        push!(state2int, Symbol("start_main_$i") => length(state2int)+1)
    end
    
    for i = 1:start_steps
        push!(state2int, Symbol("start_sec_$i") => length(state2int)+1)
    end
    
    
    # create the two reciprocal dictionaries
    act2int = Dict{Symbol,Int64}()
    for e in int2act
        push!(act2int, e.second => e.first)
    end

    int2state = Dict{Int64,Symbol}()
    for e in state2int
        push!(int2state, e.second => e.first)
    end
    state2int, int2state, act2int, int2act
    
    Unit(pmin, pmax, p, p -> get_fuel_input(p,pmax,:CC_eff), trans_steps,
        start_steps, cost, prob, pressure_out, gas_loc, pwr_bus, status,
        state2int, int2state, act2int, int2act)
        
end


function action_on_unit!(unit::Unit, a::Symbol)
    changed = false # here to make sure that the state is update only once
    if unit.status == :main_fuel

        if a == :transition
            outcome = rand(Categorical([unit.prob[:p_abort]; unit.prob[:p_succ]; unit.prob[:p_fail]]))
            if outcome == 1
                # Do Nothing
            elseif outcome == 2
                unit.status = unit.trans_steps > 0 ? :toward_sec_1 : :sec_fuel
            else
                unit.status = :off
            end
        elseif a == :shutdown
            unit.status = :off
        else
            if a != :do_nothing
                @warn "Action \"$(a)\" is not available when unit status is \"$(unit.status)\". Used :do_nothing instead."
            end
        end
        changed = true
    end
    
    if unit.status == :sec_fuel && changed == false

        if a == :transition
            # TODO fixe that by adding  distinct states for the reverse transition
            outcome = rand(Categorical([unit.prob[:p_abort]; unit.prob[:p_succ]; unit.prob[:p_fail]]))
            if outcome == 1
                # Do Nothing
            elseif outcome == 2
                unit.status = unit.trans_steps > 0 ? :toward_main_1 : :main_fuel
            else
                unit.status = :off
            end  
        elseif a == :shutdown
            unit.status = :off
        else
            if a != :do_nothing
                @warn "Action \"$(a)\" is not available when unit status is \"$(unit.status)\". Used :do_nothing instead."
            end
        end
        changed = true
    end
    
    if unit.status == :off && changed == false

        if a == :start_main
            outcome = rand(Categorical([unit.prob[:p_start]; 1-unit.prob[:p_start]]))
            if outcome == 1
                #unit.status = :main_fuel
                unit.status = unit.start_steps > 0 ? :start_main_1 : :main_fuel
            else
                unit.status = :off
            end  
        elseif a == :start_sec
            outcome = rand(Categorical([unit.prob[:p_start]; 1-unit.prob[:p_start]]))
            if outcome == 1
                #unit.status = :sec_fuel
                unit.status = unit.start_steps > 0 ? :start_sec_1 : :sec_fuel
            else
                unit.status = :off
            end 
        else
            if a != :do_nothing
                @warn "Action \"$(a)\" is not available when unit status is \"$(unit.status)\". Used :do_nothing instead."
            end
        end
        changed = true
    end
    
    # intermediate transtion states
    for i = 1:unit.trans_steps-1
        if unit.status == Symbol("toward_sec_$i")  && changed == false
            if a == :shutdown
                unit.status = :off
            else
                if a != :do_nothing
                    @warn "Action \"$(a)\" is not available when unit status is \"$(unit.status)\". Used :do_nothing instead"
                end
                outcome = rand(Categorical([unit.prob[:p_abort]; unit.prob[:p_succ]; unit.prob[:p_fail]]))
                if outcome == 1
                    unit.status = :main_fuel
                elseif outcome == 2
                    unit.status = Symbol("toward_sec_$(i+1)")
                else
                    unit.status = :off
                end
            end
            changed = true
        end
    end

    if unit.status == Symbol("toward_sec_$(unit.trans_steps)") && changed == false

        if a == :shutdown
            unit.status = :off
        else
            if a != :do_nothing
                @warn "Action \"$(a)\" is not available when unit status is \"$(unit.status)\". Used :do_nothing instead."
            end
            outcome = rand(Categorical([unit.prob[:p_abort]; unit.prob[:p_succ]; unit.prob[:p_fail]]))
            if outcome == 1
                unit.status = :main_fuel
            elseif outcome == 2
                unit.status = :sec_fuel
            else
                unit.status = :off
            end
        end
        changed = true
    end

    for i = 1:unit.trans_steps-1
        if unit.status == Symbol("toward_main_$i")  && changed == false
            if a == :shutdown
                unit.status = :off
            else
                if a != :do_nothing
                    @warn "Action \"$(a)\" is not available when unit status is \"$(unit.status)\". Used :do_nothing instead"
                end
                outcome = rand(Categorical([unit.prob[:p_abort]; unit.prob[:p_succ]; unit.prob[:p_fail]]))
                if outcome == 1
                    unit.status = :sec_fuel
                elseif outcome == 2
                    unit.status = Symbol("toward_main_$(i+1)")
                else
                    unit.status = :off
                end
            end
            changed = true
        end
    end

    if unit.status == Symbol("toward_sec_$(unit.trans_steps)") && changed == false

        if a == :shutdown
            unit.status = :off
        else
            if a != :do_nothing
                @warn "Action \"$(a)\" is not available when unit status is \"$(unit.status)\". Used :do_nothing instead."
            end
            outcome = rand(Categorical([unit.prob[:p_abort]; unit.prob[:p_succ]; unit.prob[:p_fail]]))
            if outcome == 1
                unit.status = :sec_fuel
            elseif outcome == 2
                unit.status = :main_fuel
            else
                unit.status = :off
            end
        end
        changed = true
    end

    
    # intermediate start states
    for i = 1:unit.start_steps-1
        if unit.status == Symbol("start_main_$i")  && changed == false
            if a == :shutdown
                unit.status = :off
            else
                if a != :do_nothing
                    @warn "Action \"$(a)\" is not available when unit status is \"$(unit.status)\". Used :do_nothing instead"
                end
                outcome = rand(Categorical([unit.prob[:p_start]; 1-unit.prob[:p_start]]))
                if outcome == 1
                    unit.status = Symbol("start_main_$(i+1)")
                else
                    unit.status = :off
                end
            end
            changed = true
        end
    end

    if unit.status == Symbol("start_main_$(unit.start_steps)") && changed == false
        if a == :shutdown
            unit.status = :off
        else
            if a != :do_nothing
                @warn "Action \"$(a)\" is not available when unit status is \"$(unit.status)\". Used :do_nothing instead."
            end
            outcome = rand(Categorical([unit.prob[:p_start]; 1-unit.prob[:p_start]]))
            if outcome == 1
                unit.status = :main_fuel
            else
                unit.status = :off
            end
        end
        changed = true
    end
    
    for i = 1:unit.start_steps-1
        if unit.status == Symbol("start_sec_$i")  && changed == false
            if a == :shutdown
                unit.status = :off
            else
                if a != :do_nothing
                    @warn "Action \"$(a)\" is not available when unit status is \"$(unit.status)\". Used :do_nothing instead"
                end
                outcome = rand(Categorical([unit.prob[:p_start]; 1-unit.prob[:p_start]]))
                if outcome == 1
                    unit.status = Symbol("start_sec_$(i+1)")
                else
                    unit.status = :off
                end
            end
            changed = true
        end
    end

    if unit.status == Symbol("start_sec_$(unit.start_steps)") && changed == false
        if a == :shutdown
            unit.status = :off
        else
            if a != :do_nothing
                @warn "Action \"$(a)\" is not available when unit status is \"$(unit.status)\". Used :do_nothing instead."
            end
            outcome = rand(Categorical([unit.prob[:p_start]; 1-unit.prob[:p_start]]))
            if outcome == 1
                unit.status = :sec_fuel
            else
                unit.status = :off
            end
        end
        changed = true
    end

end


is_generating(u::Unit) = u.status in [:main_fuel; :sec_fuel] || contains(string(u.status),"toward")
is_on_gas(u::Unit) = u.status == :main_fuel || contains(string(u.status),"toward_sec")

function get_fuel_input(output, pmax, unit_type;
    unit_type_params = Dict(
        :GT_avg => (fl_hr = 10.1,  a = 0.328147, b = 0.372438, c = 0.299031),
        :GT_eff => (fl_hr = 9.0,  a = 0.328147, b = 0.372438, c = 0.299031),
        :CC_eff => (fl_hr = 6.75,  a = 0.328147, b = 0.372438, c = 0.299031),
        :CC_avg => (fl_hr = 6.75,  a = 0.328147, b = 0.372438, c = 0.299031),
        :ST_avg => (fl_hr = 10.8,  a = 0.068195, b = 0.851957, c = 0.078793),
    )
)
    #fl_hr [mmBtu/MWh]
    # output [MW]
    # pmax [MW]
    # unit_type should be a label in unit_type_params
    # fuel_input [mmBtu/h]
    kappa = 0.020262 / 0.453592 # [mmBtu/kg]
    p = unit_type_params[unit_type]
    norm_out = output / pmax
    norm_fuel = p.a * norm_out^2 + p.b * norm_out + p.c
    return p.fl_hr / kappa / 3600 * pmax *  norm_fuel # in [kg/s]
end

function set_output!(unit::Unit, p)
    unit.p = max(min(p, unit.pmax), unit.pmin)
    nothing
end



function create_fleet(;
        pwr_folder = "../data/power_data",
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
    df = DataFrame(CSV.File(joinpath(pwr_folder, "units.csv")))
    units = Unit[]
    for d in eachrow(df)
        push!(units, Unit(pmin = d.p_min, pmax = d.p_max, gas_loc = d."station #",
            cost = Dict(:main_cost => d.main_cost, :sec_cost => d.sec_cost),
            prob = prob_per_class[Symbol(class)],
            trans_steps = div(d.transition_duration, dt)-1,
            start_steps = div(d.start_duration, dt)-1))
    end

    units
end


#=
function create_fleet(;
        pwr_folder = "../data/power_data",
        prob_per_class = Dict(
            :super_reliable => Dict(:p_abort => 0.01, :p_succ => 0.98, :p_fail => 0.01, :p_start => 0.95),
            :reliable => Dict(:p_abort => 0.05, :p_succ => 0.9, :p_fail => 0.05, :p_start => 0.90),
            :fairly_reliable => Dict(:p_abort => 0.10, :p_succ => 0.8, :p_fail => 0.10, :p_start => 0.80),
            :unreliable => Dict(:p_abort => 0.15, :p_succ => 0.70, :p_fail => 0.15, :p_start => 0.70)
        ),
        state2int = Dict{Symbol, Int}(:main_fuel => 1, :sec_fuel => 2, :off => 3),
        int2act = Dict{Int,Symbol}(1 => :do_nothing, 2 => :transition, 3 => :shutdown,
            4 => :start_main, 5 => :start_sec), 
        class = :reliable,
        dt = 5.0
)

    # load units
    df = DataFrame(CSV.File(joinpath(pwr_folder, "units.csv")))
    units = Unit[]
    for d in eachrow(df)
        push!(units, Unit(pmin = d.p_min, pmax = d.p_max, gas_loc = d."station #",
            cost = Dict(:main_cost => d.main_cost, :sec_cost => d.sec_cost),
            prob = prob_per_class[Symbol(class)],
            trans_steps = div(d.transition_duration, dt)-1,
            start_steps = div(d.start_duration, dt)-1))
    end
    
    max_trans_steps = [u.trans_steps for u in units] |> maximum
    max_start_steps = [u.start_steps for u in units] |> maximum
    for i = 1:max_trans_steps
        push!(state2int, Symbol("toward_sec_$i") => length(state2int)+1)
    end
    
    for i = 1:max_trans_steps
        push!(state2int, Symbol("toward_main_$i") => length(state2int)+1)
    end
    
    for i = 1:max_start_steps
        push!(state2int, Symbol("start_main_$i") => length(state2int)+1)
    end
    
    for i = 1:max_start_steps
        push!(state2int, Symbol("start_sec_$i") => length(state2int)+1)
    end

    # create the two reciprocal dictionaries
    act2int = Dict{Symbol,Int64}()
    for e in int2act
        push!(act2int, e.second => e.first)
    end

    int2state = Dict{Int64,Symbol}()
    for e in state2int
        push!(int2state, e.second => e.first)
    end
    units, state2int, int2state, act2int, int2act
end
=#
