macro AbstractVertexBaseAttributes()
    esc(quote
        id::Symbol
        timedata::TimeData
        balance_ids::Vector{Symbol} = Vector{Symbol}()
        operation_expr::Dict = Dict()
        operation_vars::Dict = Dict()
        planning_vars::Dict = Dict()
        constraints::Vector{AbstractTypeConstraint} = Vector{AbstractTypeConstraint}()
    end)
end

get_id(v::AbstractVertex) = v.id;
balance_ids(v::AbstractVertex) = v.balance_ids;
get_balance(v::AbstractVertex,i::Symbol) = v.operation_expr[i];
get_balance(v::AbstractVertex,i::Symbol,t::Int64) = get_balance(v,i)[t];

time_interval(v::AbstractVertex) = v.timedata.time_interval;
subperiods(v::AbstractVertex) = v.timedata.subperiods;
subperiod_weight(v::AbstractVertex,w::StepRange{Int64, Int64}) = v.timedata.subperiod_weights[w];
current_subperiod(v::AbstractVertex,t::Int64) = subperiods(v)[findfirst(t .∈ subperiods(v))];
all_constraints(v::AbstractVertex) = v.constraints;