Base.@kwdef mutable struct TEdgeWithUC{T} <: AbstractTransformationEdgeWithUC{T}
    @AbstractTransformationEdgeBaseAttributes()
    min_up_time::Int64 = 0.0
    min_down_time::Int64 = 0.0
    start_cost::Float64 = 0.0
    start_fuel::Float64 = 0.0
    start_fuel_stoichiometry_name::Symbol = :none
end

min_up_time(e::AbstractTransformationEdgeWithUC) = e.min_up_time;
min_down_time(e::AbstractTransformationEdgeWithUC) = e.min_down_time;
start_cost(e::AbstractTransformationEdgeWithUC) = e.start_cost;
start_fuel(e::AbstractTransformationEdgeWithUC) = e.start_fuel;
start_fuel_stoichiometry_name(e::AbstractTransformationEdgeWithUC) = e.start_fuel_stoichiometry_name;
ucommit(e::AbstractTransformationEdgeWithUC) = e.operation_vars[:ucommit];
ucommit(e::AbstractTransformationEdgeWithUC,t::Int64) = ucommit(e)[t];

ustart(e::AbstractTransformationEdgeWithUC) = e.operation_vars[:ustart];
ustart(e::AbstractTransformationEdgeWithUC,t::Int64) = ustart(e)[t];

ushut(e::AbstractTransformationEdgeWithUC) = e.operation_vars[:ushut];
ushut(e::AbstractTransformationEdgeWithUC,t::Int64) = ushut(e)[t];


function add_operation_variables!(e::AbstractTransformationEdgeWithUC, model::Model)

    e.operation_vars[:flow] = @variable(
        model,
        [t in time_interval(e)],
        lower_bound = 0.0,
        base_name = "vFLOW_$(get_transformation_id(e))_$(get_id(e))"
    )

    e.operation_vars[:ucommit] = @variable(
        model,
        [t in time_interval(e)],
        lower_bound = 0.0,
        base_name = "vCOMMIT_$(get_transformation_id(e))_$(get_id(e))"
    )

    e.operation_vars[:ustart] = @variable(
        model,
        [t in time_interval(e)],
        lower_bound = 0.0,
        base_name = "vSTART_$(get_transformation_id(e))_$(get_id(e))"
    )

    e.operation_vars[:ushut] = @variable(
        model,
        [t in time_interval(e)],
        lower_bound = 0.0,
        base_name = "vSHUT_$(get_transformation_id(e))_$(get_id(e))"
    )

    dir_coeff =  (direction(e) == :input) ? -1 : (direction(e) == :output) ? 1 : error("Invalid TEdge direction")

    e_st_coeff = st_coeff(e);
    
    e_node = node(e);

    directional_flow = dir_coeff * flow(e);

    add_to_expression!.(net_balance(e_node),directional_flow)

    for t in time_interval(e)

        for i in stoichiometry_balance_names(e)
            add_to_expression!(stoichiometry_balance(e,i,t), e_st_coeff[i], directional_flow[t])
        end

        if variable_om_cost(e)>0
            add_to_expression!(model[:eVariableCost], variable_om_cost(e), flow(e,t))
        end

        if !isempty(price(e))
            add_to_expression!(model[:eVariableCost], price(e,t), flow(e,t))
        end

        if start_cost(e)>0
            add_to_expression!(model[:eVariableCost], start_cost(e)*capacity_size(e), ustart(e,t))
        end

        if start_fuel(e)>0
            add_to_expression!(stoichiometry_balance(e,start_fuel_stoichiometry_name(e),t), start_fuel(e)*capacity_size(e)*dir_coeff,ustart(e,t))
        end

    end

    @constraints(model, begin
    [t in time_interval(e)], ucommit(e,t) <= capacity(e)/capacity_size(e)    
    [t in time_interval(e)], ustart(e,t) <= capacity(e)/capacity_size(e)   
    [t in time_interval(e)], ushut(e,t) <= capacity(e)/capacity_size(e)  
    end)

    @constraint(model,
    [t in time_interval(e)], 
    ucommit(e,t)-ucommit(e,timestepbefore(t,1,subperiods(e))) == ustart(e,t) - ushut(e,t)
    )

    return nothing
end

