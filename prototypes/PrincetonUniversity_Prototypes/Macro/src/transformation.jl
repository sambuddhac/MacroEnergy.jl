abstract type AbstractTransformation end


Base.@kwdef mutable struct Transformation <: AbstractTransformation
    id::Int64
    nodes::Dict = Dict()
    stochiometry::Dict = Dict()
    direction::Dict = Dict()
    time_interval::Dict = Dict() 
    subperiods::Dict = Dict()
    #### Fields with defaults
    min_capacity::Float64 = 0.0
    max_capacity::Float64 = Inf
    existing_capacity::Float64 = 0.0
    can_expand::Bool = true
    can_retire::Bool = true
    investment_cost::Float64 = 0.0
    fixed_om_cost::Float64 = 0.0
    variable_om_cost::Float64 = 0.0
    planning_vars::Dict = Dict()
    operation_vars::Dict = Dict()
    constraints ::Vector{AbstractTypeTransformationConstraint}=[TransformationCapacityConstraint()]
end

time_interval(g::AbstractTransformation) = g.time_interval;
subperiods(g::AbstractTransformation) = g.subperiods;
existing_capacity(g::AbstractTransformation) = g.existing_capacity;
min_capacity(g::AbstractTransformation) = g.min_capacity;
max_capacity(g::AbstractTransformation) = g.max_capacity;
can_expand(g::AbstractTransformation) = g.can_expand;
can_retire(g::AbstractTransformation) = g.can_retire;
new_capacity(g::AbstractTransformation) = g.planning_vars[:new_capacity];
ret_capacity(g::AbstractTransformation) = g.planning_vars[:ret_capacity];
capacity(g::AbstractTransformation) = g.planning_vars[:capacity];
injection(g::AbstractTransformation) = g.operation_vars[:injection];
all_constraints(g::AbstractTransformation) = g.constraints;

function add_operation_variables!(g::AbstractTransformation, nodes::Vector{AbstractNode},  model::Model)
    
    for c in keys(g.nodes)
        g.operation_vars[Symbol("flux_$c")] = @variable(model, [t in g.time_interval[c]], lower_bound = 0.0, base_name = "vFLUX_$(c)_$(g.id)")
    end

    @constraint(model, power_out = 0.5*natural_gas_in)
    @constraint(model, co2_out = 0.05*natural_gas_in)


    return nothing


end