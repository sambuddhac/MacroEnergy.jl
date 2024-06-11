struct SolarPV <: AbstractAsset
    solar_pv_transform::Transformation
    tedge::TEdge{Electricity}
end


function make_solarpv(data::Dict{Symbol,Any}, time_data::Dict{Symbol,TimeData}, node_out::Node)
    #=============================================
    This function makes a SolarPV from the data Dict.
    It is a helper function for load_transformations!.
    =============================================#
    _solar_pv_transform = Transformation(;
        id=:SolarPV,
        timedata=time_data[:Electricity],
        # Note that this transformation does not 
        # have a stoichiometry balance because the 
        # sunshine is exogenous
    )

    time_interval_length = length(time_data[:Electricity].time_interval)

    _tedge = TEdge{Electricity}(;
        id=:E,
        node=node_out,
        transformation=_solar_pv_transform,
        timedata=time_data[:Electricity],
        direction=:output,
        has_planning_variables=get(data, :has_planning_variables, false),
        can_expand=get(data, :can_expand, false),
        can_retire=get(data, :can_retire, false),
        existing_capacity=get(data, :existing_capacity, 0.0),
        capacity_factor=get(data, :capacity_factor, zeros(time_interval_length)),
        investment_cost=get(data, :investment_cost, 0.0),
        fixed_om_cost=get(data, :fixed_om_cost, 0.0),
        constraints=[Macro.CapacityConstraint()]    # By default, the capacity constraint is added
    )

    return SolarPV(_solar_pv_transform, _tedge)
end