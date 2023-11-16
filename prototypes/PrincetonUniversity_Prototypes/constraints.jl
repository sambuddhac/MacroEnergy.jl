abstract type AbstractConstraint{T <: Commodity} end

Base.@kwdef mutable struct CapacityConstraint{T} <: AbstractConstraint{T}
    value::JuMP.Containers.DenseAxisArray = Containers.@container([t in time_interval_map[T]], 0.0);
    lagrangian_multiplier::JuMP.Containers.DenseAxisArray = Containers.@container([t in time_interval_map[T]], 0.0);
    _constraintref::JuMP.Containers.DenseAxisArray = Containers.@container([t in time_interval_map[T]], ConstraintRef[])
end

constraint_value(c::AbstractConstraint) = c.value;

constraint_dual(c::AbstractConstraint) = c.langrangian_multiplier;

constraint_ref(c::AbstractConstraint) = c._constraintref;

function add_all_model_constraints!(g::AbstractResource,model::Model)

    for ct in g.constraints
        add_model_constraint!(ct,g,model)
    end

    return nothing
end

function add_model_constraint!(mycon::CapacityConstraint,g::AbstractResource,model::Model)

    mycon._constraintref = @constraint(model,[t in time_interval(g)],injection(g)[t] <= g.capacity_factor[t]*capacity(g))

    return nothing

end

