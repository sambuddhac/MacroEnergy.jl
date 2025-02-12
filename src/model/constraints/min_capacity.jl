Base.@kwdef mutable struct MinCapacityConstraint <: PlanningConstraint
    value::Union{Missing,Vector{Float64}} = missing
    lagrangian_multiplier::Union{Missing,Vector{Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint} = missing
end


function add_model_constraint!(ct::MinCapacityConstraint, y::Union{AbstractEdge,AbstractStorage}, model::Model)

    ct.constraint_ref = @constraint(model, capacity(y) >= min_capacity(y))

    return nothing

end
