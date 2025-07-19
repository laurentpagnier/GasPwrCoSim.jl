using PowerModels, JuMP
mutable struct DCWithShedPPowerModel <: AbstractDCPModel @pm_fields end

function build_opf_w_shed(pm::DCWithShedPPowerModel)
    variable_load_shedding(pm)
    build_opf(pm)
    objective_add_shedding_cost(pm)
end


function add_energy_not_serve_price!(data, prices=nothing)
    for (i, l) in data["load"]
        l["ENS_price"] = isnothing(prices) ? 10_000.0 : prices[i]
    end
end


function variable_load_shedding(pm::AbstractPowerModel; nw::Int=nw_id_default, bounded::Bool=true, report::Bool=true)
    shed = PowerModels.var(pm, nw)[:shed] = JuMP.@variable(pm.model,
        [i in ids(pm, nw, :load)], base_name="$(nw)_shed",
        start = comp_start_value(ref(pm, nw, :load, i), "load_shedding")
    )

    if bounded
        for (i, load) in ref(pm, nw, :load)
            JuMP.set_lower_bound(shed[i], 0.0)
            JuMP.set_upper_bound(shed[i], load["pd"])
        end
    end

    report && sol_component_value(pm, nw, :load, :shed, ids(pm, nw, :load), shed)
end


function objective_add_shedding_cost(pm::DCWithShedPPowerModel)
    for (n, network) in nws(pm)
        shed = get(PowerModels.var(pm, n), :shed, Dict()); #PowerModels._check_var_keys(p_d, bus_arcs_dc, "load shedding", "load")
        shed_cost = 0.0
        for (i, load) in ref(pm, n, :load)
            shed_cost += shed[i] * load["ENS_price"]
        end
        
        set_objective_function(pm.model,objective_function(pm.model) + shed_cost)
    end
end


function PowerModels.constraint_power_balance(pm::DCWithShedPPowerModel, n::Int, i::Int, bus_arcs, bus_arcs_dc, bus_arcs_sw, bus_gens, bus_storage, bus_pd, bus_qd, bus_gs, bus_bs)
    p    = get(PowerModels.var(pm, n),    :p, Dict()); PowerModels._check_var_keys(p, bus_arcs, "active power", "branch")
    pg   = get(PowerModels.var(pm, n),   :pg, Dict()); PowerModels._check_var_keys(pg, bus_gens, "active power", "generator")
    ps   = get(PowerModels.var(pm, n),   :ps, Dict()); PowerModels._check_var_keys(ps, bus_storage, "active power", "storage")
    psw  = get(PowerModels.var(pm, n),  :psw, Dict()); PowerModels._check_var_keys(psw, bus_arcs_sw, "active power", "switch")
    p_dc = get(PowerModels.var(pm, n), :p_dc, Dict()); PowerModels._check_var_keys(p_dc, bus_arcs_dc, "active power", "dcline")
    shed = get(PowerModels.var(pm, n), :shed, Dict()); #_check_var_keys(shed, bus_arcs_dc, "load shedding", "load")
    
    cstr = JuMP.@constraint(pm.model,
        sum(p[a] for a in bus_arcs)
        + sum(p_dc[a_dc] for a_dc in bus_arcs_dc)
        + sum(psw[a_sw] for a_sw in bus_arcs_sw)
        ==
        sum(pg[g] for g in bus_gens)
        - sum(ps[s] for s in bus_storage)
        - sum(pd for pd in values(bus_pd))
        - sum(gs for gs in values(bus_gs))*1.0^2
        + sum(shed[i] for (i,pd) in bus_pd)
    )

    if PowerModels._IM.report_duals(pm)
        sol(pm, n, :bus, i)[:lam_kcl_r] = cstr
        sol(pm, n, :bus, i)[:lam_kcl_i] = NaN
    end
end

# We want DCWithShedPPowerModel to behave as AbstractAPLossLessModels
# but its cannot be redefine from outside the package so we copy-paste
# what is in src/form/dcp.jl
######## Lossless Models ########
""
function PowerModels.variable_branch_power_real(pm::DCWithShedPPowerModel; nw::Int=nw_id_default, bounded::Bool=true, report::Bool=true)
    p = PowerModels.var(pm, nw)[:p] = JuMP.@variable(pm.model,
        [(l,i,j) in ref(pm, nw, :arcs_from)], base_name="$(nw)_p",
        start = comp_start_value(ref(pm, nw, :branch, l), "p_start")
    )

    if bounded
        flow_lb, flow_ub = ref_calc_branch_flow_bounds(ref(pm, nw, :branch), ref(pm, nw, :bus))

        for arc in ref(pm, nw, :arcs_from)
            l,i,j = arc
            if !isinf(flow_lb[l])
                JuMP.set_lower_bound(p[arc], flow_lb[l])
            end
            if !isinf(flow_ub[l])
                JuMP.set_upper_bound(p[arc], flow_ub[l])
            end
        end
    end

    for (l,branch) in ref(pm, nw, :branch)
        if haskey(branch, "pf_start")
            f_idx = (l, branch["f_bus"], branch["t_bus"])
            JuMP.set_start_value(p[f_idx], branch["pf_start"])
        end
    end

    # this explicit type erasure is necessary
    p_expr = Dict{Any,Any}( ((l,i,j), p[(l,i,j)]) for (l,i,j) in ref(pm, nw, :arcs_from) )
    p_expr = merge(p_expr, Dict( ((l,j,i), -1.0*p[(l,i,j)]) for (l,i,j) in ref(pm, nw, :arcs_from)))
    PowerModels.var(pm, nw)[:p] = p_expr

    report && sol_component_value_edge(pm, nw, :branch, :pf, :pt, ref(pm, nw, :arcs_from), ref(pm, nw, :arcs_to), p_expr)
end

""
function PowerModels.variable_ne_branch_power_real(pm::DCWithShedPPowerModel; nw::Int=nw_id_default, bounded::Bool=true, report::Bool=true)
    p_ne = PowerModels.var(pm, nw)[:p_ne] = JuMP.@variable(pm.model,
        [(l,i,j) in ref(pm, nw, :ne_arcs_from)], base_name="$(nw)_p_ne",
        start = comp_start_value(ref(pm, nw, :ne_branch, l), "p_start")
    )

    if bounded
        ne_branch = ref(pm, nw, :ne_branch)
        for (l,i,j) in ref(pm, nw, :ne_arcs_from)
            JuMP.set_lower_bound(p_ne[(l,i,j)], -ne_branch[l]["rate_a"])
            JuMP.set_upper_bound(p_ne[(l,i,j)],  ne_branch[l]["rate_a"])
        end
    end

    # this explicit type erasure is necessary
    p_ne_expr = Dict{Any,Any}([((l,i,j), 1.0*var(pm, nw, :p_ne, (l,i,j))) for (l,i,j) in ref(pm, nw, :ne_arcs_from)])
    p_ne_expr = merge(p_ne_expr, Dict(((l,j,i), -1.0*var(pm, nw, :p_ne, (l,i,j))) for (l,i,j) in ref(pm, nw, :ne_arcs_from)))
    PowerModels.var(pm, nw)[:p_ne] = p_ne_expr

    report && sol_component_value_edge(pm, nw, :ne_branch, :pf, :pt, ref(pm, nw, :ne_arcs_from), ref(pm, nw, :ne_arcs_to), p_ne_expr)
end

""
function PowerModels.constraint_network_power_balance(pm::DCWithShedPPowerModel, n::Int, i, comp_gen_ids, comp_pd, comp_qd, comp_gs, comp_bs, comp_branch_g, comp_branch_b)
    pg = PowerModels.var(pm, n, :pg)

    JuMP.@constraint(pm.model, sum(pg[g] for g in comp_gen_ids) == sum(pd for (i,pd) in values(comp_pd)) + sum(gs*1.0^2 for (i,gs) in values(comp_gs)))
    # omit reactive constraint
end

"nothing to do, this model is symetric"
function PowerModels.constraint_thermal_limit_to(pm::DCWithShedPPowerModel, n::Int, t_idx, rate_a)
    # NOTE correct?
    l,i,j = t_idx
    p_fr = PowerModels.var(pm, n, :p, (l,j,i))
    if isa(p_fr, JuMP.VariableRef) && JuMP.has_upper_bound(p_fr)
        cstr = JuMP.UpperBoundRef(p_fr)
    else
        p_to = PowerModels.var(pm, n, :p, t_idx)
        cstr = JuMP.@constraint(pm.model, p_to <= rate_a)
    end

    if PowerModels._IM.report_duals(pm)
        sol(pm, n, :branch, t_idx[1])[:mu_sm_to] = cstr
    end
end

"nothing to do, this model is symetric"
function PowerModels.constraint_ohms_yt_to_on_off(pm::DCWithShedPPowerModel, n::Int, i, f_bus, t_bus, f_idx, t_idx, g, b, g_to, b_to, tr, ti, tm, vad_min, vad_max)
end

"nothing to do, this model is symetric"
function PowerModels.constraint_thermal_limit_to_on_off(pm::DCWithShedPPowerModel, n::Int, i, t_idx, rate_a)
end

"nothing to do, this model is symetric"
function PowerModels.constraint_ne_thermal_limit_to(pm::DCWithShedPPowerModel, n::Int, i, t_idx, rate_a)
end

"nothing to do, this model is symetric"
function PowerModels.constraint_ohms_yt_to(pm::DCWithShedPPowerModel, n::Int, f_bus, t_bus, f_idx, t_idx, g, b, g_to, b_to, tr, ti, tm)
end

"nothing to do, this model is symetric"
function PowerModels.constraint_ne_ohms_yt_to(pm::DCWithShedPPowerModel, n::Int, i, f_bus, t_bus, f_idx, t_idx, g, b, g_to, b_to, tr, ti, tm, vad_min, vad_max)
end

""
function PowerModels.constraint_storage_on_off(pm::DCWithShedPPowerModel, n::Int, i, pmin, pmax, qmin, qmax, charge_ub, discharge_ub)
    z_storage = var(pm, n, :z_storage, i)
    ps = var(pm, n, :ps, i)
    sc = var(pm, n, :sc, i)
    sd = var(pm, n, :sd, i)

    JuMP.@constraint(pm.model, ps <= z_storage*pmax)
    JuMP.@constraint(pm.model, ps >= z_storage*pmin)
    JuMP.@constraint(pm.model, sc <= z_storage*charge_ub)
    JuMP.@constraint(pm.model, sd <= z_storage*discharge_ub)
end

""
function PowerModels.constraint_storage_losses(pm::DCWithShedPPowerModel, n::Int, i, bus, r, x, p_loss, q_loss)
    ps = var(pm, n, :ps, i)
    sc = var(pm, n, :sc, i)
    sd = var(pm, n, :sd, i)

    JuMP.@constraint(pm.model, ps + (sd - sc) == p_loss)
end
