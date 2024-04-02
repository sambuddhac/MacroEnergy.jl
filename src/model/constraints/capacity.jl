Base.@kwdef mutable struct CapacityConstraint <: OperationConstraint
    value::Union{Missing,Vector{Float64}} = missing
    lagrangian_multiplier::Union{Missing,Vector{Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint} = missing
end

Base.@kwdef mutable struct StorageCapacityConstraint <: OperationConstraint
    value::Union{Missing,Vector{Float64}} = missing
    lagrangian_multiplier::Union{Missing,Vector{Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint} = missing
end

Base.@kwdef mutable struct SymmetricCapacityConstraint <: OperationConstraint
    value::Union{Missing,Vector{Float64}} = missing
    lagrangian_multiplier::Union{Missing,Vector{Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint} = missing
end

Base.@kwdef mutable struct WithdrawalCapacityConstraint <: OperationConstraint
    value::Union{Missing,Vector{Float64}} = missing
    lagrangian_multiplier::Union{Missing,Vector{Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint} = missing
end

function add_model_constraint!(ct::CapacityConstraint, e::AbstractTransformationEdge, model::Model)

    if isempty(capacity_factor(e))
        ct.constraint_ref = @constraint(
            model, 
            [t in time_interval(e)], 
            flow(e,t) <= capacity(e))
    else
        ct.constraint_ref = @constraint(
            model,
            [t in time_interval(e)],
            flow(e,t) <= capacity_factor(e,t)*capacity(e)
            )
    end

    return nothing

end

function add_model_constraint!(
    ct::StorageCapacityConstraint,
    g::AbstractTransformation,
    model::Model,
)

    ct.constraint_ref = @constraint(
        model,
        [t in time_interval(g)],
        storage_level(g,t) <= capacity_storage(g)
    )

    return nothing
end

function add_model_constraint!(
    ct::SymmetricCapacityConstraint,
    g::AbstractTransformation,
    model::Model,
)
    e_discharge = g.TEdges[g.discharge_edge]
    e_charge = g.TEdges[g.charge_edge]
    ct.constraint_ref = @constraint(
        model,
        [t in time_interval(g)],
        flow(e_discharge,t) + flow(e_charge,t) <= capacity(e_discharge)
    )

    return nothing
end

function add_model_constraint!(ct::CapacityConstraint, e::AbstractTransformationEdgeWithUC, model::Model)

    if isempty(capacity_factor(e))
        ct.constraint_ref = @constraint(
            model, 
            [t in time_interval(e)], 
            flow(e,t) <= capacity_size(e)*ucommit(e,t))
    else
        ct.constraint_ref = @constraint(
            model,
            [t in time_interval(e)],
            flow(e,t) <= capacity_factor(e,t)*capacity_size(e)*ucommit(e,t)
            )
    end

    return nothing

end


function add_model_constraint!(ct::CapacityConstraint, e::AbstractEdge, model::Model)

    if e.unidirectional
        ct.constraint_ref =
            @constraint(model, [t in time_interval(e)], flow(e,t) <= capacity(e))
    else
        ct.constraint_ref = @constraint(
            model,
            [i in [-1, 1], t in time_interval(e)],
            i * flow(e,t) <= capacity(e)
        )
    end

    return nothing

end