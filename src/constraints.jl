constraint_value(c::AbstractTypeConstraint) = c.constraint_dict[:constraint_value];

constraint_dual(c::AbstractTypeConstraint) = c.constraint_dict[:constraint_dual];

constraint_ref(c::AbstractTypeConstraint) = c.contraint_dict[:constraint_ref];


Base.@kwdef mutable struct CapacityConstraint <: OperationConstraint
    value::Union{Missing,Vector{Float64}} = missing
    lagrangian_multiplier::Union{Missing,Vector{Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint} = missing
end


Base.@kwdef mutable struct DemandBalanceConstraint <: OperationConstraint
    value::Union{Missing,Vector{Float64}} = missing
    lagrangian_multiplier::Union{Missing,Vector{Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint} = missing
end

Base.@kwdef mutable struct StorageCapacityConstraint <: OperationConstraint
    value::Union{Missing,Vector{Float64}} = missing
    lagrangian_multiplier::Union{Missing,Vector{Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint} = missing
end

Base.@kwdef mutable struct WithdrawalCapacityConstraint <: OperationConstraint
    value::Union{Missing,Vector{Float64}} = missing
    lagrangian_multiplier::Union{Missing,Vector{Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint} = missing
end

Base.@kwdef mutable struct MaxNonServedDemandConstraint <: OperationConstraint
    value::Union{Missing,Vector{Float64}} = missing
    lagrangian_multiplier::Union{Missing,Vector{Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint} = missing
end

Base.@kwdef mutable struct StoichiometryBalanceConstraint <:OperationConstraint
    value::Union{Missing,Vector{Float64}} = missing
    lagrangian_multiplier::Union{Missing,Vector{Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint} = missing
end

Base.@kwdef mutable struct CO2CapConstraint <:OperationConstraint
    value::Union{Missing,Vector{Float64}} = missing
    lagrangian_multiplier::Union{Missing,Vector{Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint} = missing
end



function add_all_model_constraints!(
    y::Union{AbstractEdge,AbstractNode},
    model::Model,
)

    for ct in all_constraints(y)
        add_model_constraint!(ct, y, model)
    end
    ##### This does not work because can't broadcast when passing g : add_model_constraints!.(all_constraints(g),g,model);

    return nothing
end

function add_all_model_constraints!(y::AbstractTransformation, model::Model)

    for ct in all_constraints(y)
        add_model_constraint!(ct, y, model)
    end

    edges_vec = collect(values(edges(y)));

    add_all_model_constraints!.(edges_vec,model)

    return nothing
end

function add_all_model_constraints!(e::AbstractTransformationEdge, model::Model)

    for ct in all_constraints(e)
        add_model_constraint!(ct, e, model)
    end

    return nothing
end
