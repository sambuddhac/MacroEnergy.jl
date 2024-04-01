Base.@kwdef mutable struct Node{T} <: AbstractNode{T}
    ### Fields without defaults
    id::Symbol
    demand::Vector{Float64}
    time_interval::StepRange{Int64,Int64}
    subperiods::Vector{StepRange{Int64,Int64}} = StepRange{Int64,Int64}[]
    #### Fields with defaults
    max_nsd::Vector{Float64} = [0.0]
    price_nsd::Vector{Float64} = [0.0]
    operation_vars::Dict = Dict()
    operation_expr::Dict = Dict()
    price_unmet_policy::Dict{DataType,Float64} = Dict{DataType,Float64}()
    rhs_policy::Dict{DataType,Float64} = Dict{DataType,Float64}()
    constraints::Vector{AbstractTypeConstraint} = Vector{AbstractTypeConstraint}()
end

time_interval(n::AbstractNode) = n.time_interval;
subperiods(n::AbstractNode) = n.subperiods;

commodity_type(n::AbstractNode{T}) where {T} = T;

get_id(n::AbstractNode) = n.id;

demand(n::AbstractNode) = n.demand;
demand(n::AbstractNode,t::Int64) = demand(n)[t];

non_served_demand(n::AbstractNode) = n.operation_vars[:non_served_demand];
non_served_demand(n::AbstractNode,s::Int64,t::Int64) = non_served_demand(n)[s,t];

net_balance(n::AbstractNode) = n.operation_expr[:net_balance];
net_balance(n::AbstractNode,t::Int64) = net_balance(n)[t];

max_non_served_demand(n::AbstractNode) = n.max_nsd;
max_non_served_demand(n::AbstractNode,s::Int64) = max_non_served_demand(n)[s];

price_non_served_demand(n::AbstractNode) = n.price_nsd;
price_non_served_demand(n::AbstractNode,s::Int64) = price_non_served_demand(n)[s];

segments_non_served_demand(n::AbstractNode) = 1:length(n.max_nsd);

all_constraints(n::AbstractNode) = n.constraints;

price_unmet_policy(n::AbstractNode) = n.price_unmet_policy;
price_unmet_policy(n::AbstractNode,c::DataType) = price_unmet_policy(n)[c];

rhs_policy(n::AbstractNode) = n.rhs_policy;
rhs_policy(n::AbstractNode,c::DataType) = rhs_policy(n)[c];

function add_operation_variables!(n::AbstractNode, model::Model)

    n.operation_expr[:net_balance] =
        @expression(model, [t in time_interval(n)], 0 * model[:vREF])

    if !all(max_non_served_demand(n).==0)
        n.operation_vars[:non_served_demand] = @variable(
            model,
            [s in segments_non_served_demand(n) ,t in time_interval(n)],
            lower_bound = 0.0,
            base_name = "vNSD_$(get_id(n))"
        )

        for t in time_interval(n)
            for s in segments_non_served_demand(n)
                add_to_expression!(model[:eVariableCost], price_non_served_demand(n,s), non_served_demand(n,s,t))
                add_to_expression!(net_balance(n,t), non_served_demand(n,s,t))
            end
        end
    end

    return nothing
end

function add_planning_variables!(n::AbstractNode,model::Model)
    return nothing
end