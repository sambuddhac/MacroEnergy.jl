constraint_value(c::AbstractTypeConstraint) = c.constraint_dict[:constraint_value];

constraint_dual(c::AbstractTypeConstraint) = c.constraint_dict[:constraint_dual];

constraint_ref(c::AbstractTypeConstraint) = c.contraint_dict[:constraint_ref];


Base.@kwdef mutable struct CapacityConstraint <: AbstractTypeConstraint
    value::Union{Missing,Vector{Float64}} = missing
    lagrangian_multiplier::Union{Missing,Vector{Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint} = missing
end


Base.@kwdef mutable struct DemandBalanceConstraint <: AbstractTypeConstraint
    value::Union{Missing,Vector{Float64}} = missing
    lagrangian_multiplier::Union{Missing,Vector{Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint} = missing
end

Base.@kwdef mutable struct FlowBalanceConstraint <: AbstractTypeConstraint
    value::Union{Missing,Vector{Float64}} = missing
    lagrangian_multiplier::Union{Missing,Vector{Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint} = missing
end

Base.@kwdef mutable struct StorageCapacityConstraint <: AbstractTypeConstraint
    value::Union{Missing,Vector{Float64}} = missing
    lagrangian_multiplier::Union{Missing,Vector{Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint} = missing
end

Base.@kwdef mutable struct WithdrawalCapacityConstraint <: AbstractTypeConstraint
    value::Union{Missing,Vector{Float64}} = missing
    lagrangian_multiplier::Union{Missing,Vector{Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint} = missing
end

Base.@kwdef mutable struct MinStorageDurationConstraint<: AbstractTypeConstraint
    value::Union{Missing,Vector{Float64}} = missing
    lagrangian_multiplier::Union{Missing,Vector{Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint} = missing
end

Base.@kwdef mutable struct MaxStorageDurationConstraint<: AbstractTypeConstraint
    value::Union{Missing,Vector{Float64}} = missing
    lagrangian_multiplier::Union{Missing,Vector{Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint} = missing
end

Base.@kwdef mutable struct MaxNonServedDemandConstraint <: AbstractTypeConstraint
    value::Union{Missing,Vector{Float64}} = missing
    lagrangian_multiplier::Union{Missing,Vector{Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint} = missing
end

Base.@kwdef mutable struct StoichiometryBalanceConstraint <:AbstractTypeConstraint
    value::Union{Missing,Vector{Float64}} = missing
    lagrangian_multiplier::Union{Missing,Vector{Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint} = missing
end

Base.@kwdef mutable struct CO2CapConstraint <:AbstractTypeConstraint
    value::Union{Missing,Vector{Float64}} = missing
    lagrangian_multiplier::Union{Missing,Vector{Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint} = missing
end