#=============================================
We want to be able to use multiple dispatch to create 
different versions of the same transformation type.
For example, an electrolyzer with or without a water node.
Right now, the commodity of each edge is given in the input.
However, there's no clear way to order the inputs to the 
correct positional argument automatically, and using 
kwargs will lead to several unintended methods being created
which will potentially overwrite methods we want.
Additionally, it's possible that we'll want different versions 
of the same technology with the same nodes, in which case
multiple dispatch won't work anyway. We'd need to use a Dict
of the different functions or something similar.

Therefore we'll leave the idea for now and use different 
transformation types for different versions of the same technology.
=============================================#

# function make_electrolyzer(id::Symbol, transform_data::Dict{Symbol,Any}, macro_data::Dict{Symbol,Any})
#     return make_electrolyzer(id, data, time_interval, data[:nodes][:h2_node], data[:nodes][:elec_node])
# end

function make_electrolyzer(data::Dict{Symbol, Any})::Transformation{Electrolyzer}
    electrolyzer = Transformation{Electrolyzer}(;
        id = data[:id],
        time_interval = data[:time_intervals][:transform],
        stoichiometry_balance_names = [:energy],
        constraints = [Macro.StoichiometryBalanceConstraint()]
    )

    electrolyzer.TEdges[:H2] = TEdge{Hydrogen}(;
        id = Symbol(String(id)*"_H2"),
        node = data[:nodes]["h2"],
        transformation = electrolyzer,
        direction = :output,
        has_planning_variables = true,
        can_expand = true,
        can_retire = false,
        capacity_size = data[:cap_size],
        time_interval = data[:time_intervals][:H2],
        subperiods = data[:subperiods][:H2],
        st_coeff = Dict(:energy=>1.0),
        existing_capacity = data[:existing_cap],
        investment_cost = data[:inv_cost],
        fixed_om_cost = data[:fom_cost],
        variable_om_cost = data[:vom_cost],
        constraints = [Macro.CapacityConstraint()]
    )

    electrolyzer.TEdges[:E] = TEdge{Electricity}(;
        id = Symbol(String(id)*"_E"),
        node = data[:nodes]["elec"],
        transformation = electrolyzer,
        direction = :input,
        has_planning_variables = false,
        time_interval = data[:time_intervals][:E],
        subperiods = data[:subperiods][:E],
        st_coeff = Dict(:energy=>data[:efficiency]),
    )

    return electrolyzer

end

# function make_electrolyzer(id::Symbol, data::Dict{Symbol,Any}, h2_node::Node{Hydrogen}, elec_node::Node{Electricity})
# function make_electrolyzer(id::Symbol, data::Dict{Symbol,Any}, time_interval::StepRange{Int64,Int64}; h2_node::Union{Node{Hydrogen},Nothing}=nothing, elec_node::Union{Node{Electricity},Nothing}=nothing)
#     if h2_node === nothing || elec_node === nothing
#         error("Failed to build $id electrolyzer.\nPlease provide nodes for hydrogen and electricity")
#     end

#     electrolyzer = Transformation{Electrolyzer}(;
#         id = id,
#         time_interval = data[:time_intervals][:transform],
#         stoichiometry_balance_names = [:energy],
#         constraints = [Macro.StoichiometryBalanceConstraint()]
#     )

#     electrolyzer.TEdges[:H2] = TEdge{Hydrogen}(;
#         id = Symbol(String(id)*"_H2"),
#         node = h2_node,
#         transformation = electrolyzer,
#         direction = :output,
#         has_planning_variables = true,
#         can_expand = true,
#         can_retire = false,
#         capacity_size = data[:cap_size],
#         time_interval = data[:time_intervals][:H2],
#         subperiods = data[:subperiods][:H2],
#         st_coeff = Dict(:energy=>1.0),
#         existing_capacity = data[:existing_cap],
#         investment_cost = data[:inv_cost],
#         fixed_om_cost = data[:fom_cost],
#         variable_om_cost = data[:vom_cost],
#         constraints = [Macro.CapacityConstraint()]
#     )

#     electrolyzer.TEdges[:E] = TEdge{Electricity}(;
#         id = Symbol(String(id)*"_E"),
#         node = elec_node,
#         transformation = electrolyzer,
#         direction = :input,
#         has_planning_variables = false,
#         time_interval = data[:time_intervals][:E],
#         subperiods = data[:subperiods][:E],
#         st_coeff = Dict(:energy=>data[:efficiency]),
#     )

#     return electrolyzer

# end

Transformation{Electrolyzer}(
    id::Symbol, 
    data::Dict{Symbol,Any}, 
    h2_node::Node{Hydrogen}, 
    elec_node::Node{Electricity}
) = make_electrolyzer(data)