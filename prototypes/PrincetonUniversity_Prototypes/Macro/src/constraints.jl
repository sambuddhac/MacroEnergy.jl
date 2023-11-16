constraint_value(c::AbstractTypeConstraint) = c.constraint_dict[:constraint_value];

constraint_dual(c::AbstractTypeConstraint) = c.constraint_dict[:constraint_dual];

constraint_ref(c::AbstractTypeConstraint) = c.contraint_dict[:constraint_ref];


Base.@kwdef mutable struct CapacityConstraint{T} <: AbstractTypeConstraint{T}
    value::Union{Missing,Vector{Float64}} = missing
    lagrangian_multiplier::Union{Missing,Vector{Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint} = missing
end


Base.@kwdef mutable struct EnergyBalanceConstraint{T} <: AbstractTypeConstraint{T}
    value::Union{Missing,Vector{Float64}} = missing
    lagrangian_multiplier::Union{Missing,Vector{Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint} = missing
end


Base.@kwdef mutable struct StorageCapacityConstraint{T} <: AbstractTypeConstraint{T}
    value::Union{Missing,Vector{Float64}} = missing
    lagrangian_multiplier::Union{Missing,Vector{Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint} = missing
end

Base.@kwdef mutable struct WithdrawalCapacityConstraint{T} <: AbstractTypeConstraint{T}
    value::Union{Missing,Vector{Float64}} = missing
    lagrangian_multiplier::Union{Missing,Vector{Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint} = missing
end

Base.@kwdef mutable struct MinStorageDurationConstraint{T} <: AbstractTypeConstraint{T}
    value::Union{Missing,Vector{Float64}} = missing
    lagrangian_multiplier::Union{Missing,Vector{Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint} = missing
end

Base.@kwdef mutable struct MaxStorageDurationConstraint{T} <: AbstractTypeConstraint{T}
    value::Union{Missing,Vector{Float64}} = missing
    lagrangian_multiplier::Union{Missing,Vector{Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint} = missing
end

Base.@kwdef mutable struct MaxNonServedEnergyConstraint{T} <: AbstractTypeConstraint{T}
    value::Union{Missing,Vector{Float64}} = missing
    lagrangian_multiplier::Union{Missing,Vector{Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint} = missing
end

# Base.@kwdef mutable struct TransformationCapacityConstraint<: AbstractTypeTransformationConstraint
#     value::Union{Missing,Vector{Float64}} = missing
#     lagrangian_multiplier::Union{Missing,Vector{Float64}} = missing
#     constraint_ref::Union{Missing,JuMPConstraint} = missing
# end

function add_all_model_constraints!(y::Union{AbstractResource,AbstractEdge,AbstractNode},model::Model)

    for ct in all_constraints(y)
        add_model_constraint!(ct,y,model)
    end
    ##### This does not work because can't broadcast when passing g : add_model_constraints!.(all_constraints(g),g,model);

    return nothing
end

function add_model_constraint!(ct::CapacityConstraint, g::AbstractResource, model::Model)

    cap_factor = Dict(collect(time_interval(g)) .=> capacity_factor(g))

    ct.constraint_ref = @constraint(
        model,
        [t in time_interval(g)],
        injection(g)[t] <= cap_factor[t] * capacity(g)
    )

    return nothing

end

function add_model_constraint!(ct::CapacityConstraint,e::AbstractEdge,model::Model)

    if e.unidirectional
        ct.constraint_ref = @constraint(model,[t in time_interval(e)],flow(e)[t] <= capacity(e))
    else
        ct.constraint_ref = @constraint(model,[i in [-1,1],t in time_interval(e)], i*flow(e)[t] <= capacity(e))
    end

    return nothing

end

function add_model_constraint!(ct::StorageCapacityConstraint,g::AbstractStorage,model::Model)

    ct.constraint_ref = @constraint(
        model,
        [t in time_interval(g)],
        storage_level(g)[t] <= capacity_storage(g)
    )

end


function add_model_constraint!(
    ct::WithdrawalCapacityConstraint,
    g::AsymmetricStorage,
    model::Model,
)

    ct.constraint_ref = @constraint(
        model,
        [t in time_interval(g)],
        withdrawal(g)[t] <= capacity_withdrawal(g)
    )

end

function add_model_constraint!(ct::MinStorageDurationConstraint,g::AbstractStorage,model::Model)

    ct.constraint_ref = @constraint(model,capacity_storage(g) >= g.min_duration*capacity(g))
    
end

function add_model_constraint!(ct::MaxStorageDurationConstraint,g::AbstractStorage,model::Model)

    ct.constraint_ref = @constraint(model,capacity_storage(g) <= g.max_duration*capacity(g))
    
end

function add_model_constraint!(ct::EnergyBalanceConstraint,n::AbstractNode,model::Model)

    ct.constraint_ref = @constraint(model, [t in time_interval(n)], net_energy_production(n)[t] + non_served_energy(n)[t] == demand(n)[t])

end

function add_model_constraint!(ct::MaxNonServedEnergyConstraint,n::AbstractNode,model::Model)

    ct.constraint_ref = @constraint(model, [t in time_interval(n)], non_served_energy(n)[t] <= max_non_served_energy(n)*demand(n)[t])

end