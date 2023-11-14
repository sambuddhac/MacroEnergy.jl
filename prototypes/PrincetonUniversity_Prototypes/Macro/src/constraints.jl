abstract type AbstractConstraint{T <: Commodity} end

Base.@kwdef mutable struct CapacityConstraint{T} <: AbstractConstraint{T}
    value::DenseAxisArray = Containers.@container([t in time_interval_map[T]], 0.0);
    lagrangian_multiplier::DenseAxisArray = Containers.@container([t in time_interval_map[T]], 0.0);
    _constraintref::DenseAxisArray = Containers.@container([t in time_interval_map[T]], JuMP.ConstraintRef[])
end

constraint_value(c::AbstractConstraint) = c.value;

constraint_dual(c::AbstractConstraint) = c.langrangian_multiplier;

constraint_ref(c::AbstractConstraint) = c._constraintref;



