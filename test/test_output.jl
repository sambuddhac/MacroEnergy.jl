module TestOutput

using Test
using MacroEnergy
import MacroEnergy:
    OutputRow,
    TimeData,
    capacity,
    new_capacity,
    retired_capacity,
    flow,
    new_capacity,
    storage_level,
    non_served_demand,
    max_non_served_demand,
    edges_with_capacity_variables,
    get_commodity_name,
    get_commodity_subtype,
    get_edges,
    get_nodes,
    get_transformations,
    get_resource_id,
    get_component_id,
    get_zone_name,
    get_type,
    get_unit,
    get_optimal_vars,
    get_optimal_vars_timeseries,
    convert_to_dataframe, 
    empty_system, 
    create_output_path,
    find_available_path,
    add!


function test_writing_output()

    @testset "OutputRow Tests" begin
        # Test the first constructor (no time field)
        output1 = OutputRow(:commodity1, :commodity_subtype1, :zone1, :resource_id1, :component_id1, :type1, :variable1, 2025, 1, 1, 123.45)#, :unit1)
        @test output1.case_name === missing
        @test output1.commodity == :commodity1
        @test output1.commodity_subtype == :commodity_subtype1
        @test output1.zone == :zone1
        @test output1.resource_id == :resource_id1
        @test output1.component_id == :component_id1
        @test output1.type == :type1
        @test output1.variable == :variable1
        @test output1.year == 2025
        @test output1.segment == 1
        @test output1.time == 1
        @test output1.value == 123.45
        # @test output1.unit == :unit1

        # Test the second constructor (for time series data)
        output2 = OutputRow(:commodity2, :commodity_subtype2, :zone2, :resource_id2, :component_id2, :type2, :variable2, 2027, 2, 5, 678.90)#, :unit2)
        @test output2.case_name === missing
        @test output2.commodity == :commodity2
        @test output2.commodity_subtype == :commodity_subtype2
        @test output2.zone == :zone2
        @test output2.resource_id == :resource_id2
        @test output2.component_id == :component_id2
        @test output2.type == :type2
        @test output2.variable == :variable2
        @test output2.year == 2027
        @test output2.segment == 2
        @test output2.time == 5
        @test output2.value == 678.90
        # @test output2.unit == :unit2
    end

    # Mock objects to use in tests
    node1 = Node{Electricity}(;
        id=:node1,
        timedata=TimeData{Electricity}(;
            time_interval=1:3,
            hours_per_timestep=10,
            subperiods=[1:10, 11:20, 21:30],
            subperiod_indices=[1, 2, 3],
            subperiod_weights=Dict(1 => 0.3, 2 => 0.5, 3 => 0.2)
        ),
        max_nsd=[0.0, 1.0, 2.0]
    )
    node2 = Node{Electricity}(;
        id=:node2,
        timedata=TimeData{Electricity}(;
            time_interval=1:3,
            hours_per_timestep=10,
            subperiods=[1:10, 11:20, 21:30],
            subperiod_indices=[1, 2, 3],
            subperiod_weights=Dict(1 => 0.3, 2 => 0.5, 3 => 0.2)
        ),
        max_nsd=[3.0, 4.0, 5.0]
    )

    storage = Storage{Electricity}(;
        id=:storage1,
        timedata=TimeData{Electricity}(;
            time_interval=1:3,
            hours_per_timestep=10,
            subperiods=[1:10, 11:20, 21:30],
            subperiod_indices=[1, 2, 3],
            subperiod_weights=Dict(1 => 0.3, 2 => 0.5, 3 => 0.2)
        ),
        new_capacity=100.0,
        storage_level=[1.0, 2.0, 3.0]
    )

    transformation = Transformation(;
        id=:transformation1,
        timedata=TimeData{Electricity}(;
            time_interval=1:100,
            hours_per_timestep=10,
            subperiods=[1:10, 11:20, 21:30],
            subperiod_indices=[1, 2, 3],
            subperiod_weights=Dict(1 => 0.3, 2 => 0.5, 3 => 0.2)
        )
    )

    edge_between_nodes = Edge{Electricity}(;
        id=:edge1,
        start_vertex=node1,
        end_vertex=node2,
        timedata=TimeData{Electricity}(;
            time_interval=1:3,
            hours_per_timestep=10,
            subperiods=[1:10, 11:20, 21:30],
            subperiod_indices=[1, 2, 3],
            subperiod_weights=Dict(1 => 0.3, 2 => 0.5, 3 => 0.2)
        ),
        capacity=100.0,
        flow=[1.0, 2.0, 3.0]
    )

    edge_to_storage = Edge{Electricity}(;
        id=:edge2,
        start_vertex=node1,
        end_vertex=storage,
        timedata=TimeData{Electricity}(;
            time_interval=1:3,
            hours_per_timestep=10,
            subperiods=[1:10, 11:20, 21:30],
            subperiod_indices=[1, 2, 3],
            subperiod_weights=Dict(1 => 0.3, 2 => 0.5, 3 => 0.2)
        ),
        capacity=101.0,
        flow=[4.0, 5.0, 6.0]
    )

    edge_to_transformation = Edge{Electricity}(;
        id=:edge3,
        start_vertex=node1,
        end_vertex=transformation,
        has_capacity=true,
        timedata=TimeData{Electricity}(;
            time_interval=1:3,
            hours_per_timestep=10,
            subperiods=[1:10, 11:20, 21:30],
            subperiod_indices=[1, 2, 3],
            subperiod_weights=Dict(1 => 0.3, 2 => 0.5, 3 => 0.2)
        ),
        capacity=102.0,
        flow=[7.0, 8.0, 9.0]
    )

    edge_from_storage = Edge{Electricity}(;
        id=:edge4,
        start_vertex=storage,
        end_vertex=node2,
        timedata=TimeData{Electricity}(;
            time_interval=1:3,
            hours_per_timestep=10,
            subperiods=[1:10, 11:20, 21:30],
            subperiod_indices=[1, 2, 3],
            subperiod_weights=Dict(1 => 0.3, 2 => 0.5, 3 => 0.2)
        ),
        capacity=103.0,
        flow=[10.0, 11.0, 12.0]
    )

    edge_from_transformation = Edge{Electricity}(;
        id=:edge5,
        start_vertex=transformation,
        end_vertex=node2,
        timedata=TimeData{Electricity}(;
            time_interval=1:3,
            hours_per_timestep=10,
            subperiods=[1:10, 11:20, 21:30],
            subperiod_indices=[1, 2, 3],
            subperiod_weights=Dict(1 => 0.3, 2 => 0.5, 3 => 0.2)
        ),
        capacity=104.0,
        flow=[13.0, 14.0, 15.0]
    )

    edge_storage_transformation = Edge{Electricity}(;
        id=:edge6,
        start_vertex=storage,
        end_vertex=transformation,
        timedata=TimeData{Electricity}(;
            time_interval=1:3,
            hours_per_timestep=10,
            subperiods=[1:10, 11:20, 21:30],
            subperiod_indices=[1, 2, 3],
            subperiod_weights=Dict(1 => 0.3, 2 => 0.5, 3 => 0.2)
        ),
        capacity=105.0,
        flow=[16.0, 17.0, 18.0]
    )

    edge_from_transformation1 = Edge{NaturalGas}(;
        id=:edge3ng,
        start_vertex=transformation,
        end_vertex=node1,
        timedata=TimeData{NaturalGas}(;
            time_interval=1:3,
            hours_per_timestep=10,
            subperiods=[1:10, 11:20, 21:30],
            subperiod_indices=[1, 2, 3],
            subperiod_weights=Dict(1 => 0.3, 2 => 0.5, 3 => 0.2)
        ),
        capacity=102.0,
        flow=[7.0, 8.0, 9.0]
    )

    edge_from_transformation2 = Edge{CO2}(;
        id=:edge3co2,
        start_vertex=transformation,
        end_vertex=node1,
        timedata=TimeData{CO2}(;
            time_interval=1:3,
            hours_per_timestep=10,
            subperiods=[1:10, 11:20, 21:30],
            subperiod_indices=[1, 2, 3],
            subperiod_weights=Dict(1 => 0.3, 2 => 0.5, 3 => 0.2)
        ),
        capacity=102.0,
        flow=[7.0, 8.0, 9.0]
    )

    asset1 = ThermalPower(:asset1, transformation, edge_to_transformation, edge_from_transformation1, edge_from_transformation2)
    asset_ref = Ref(asset1)
    asset_map = Dict{Symbol, Base.RefValue{<: AbstractAsset}}(
        :edge3 => asset_ref,
        :edge3ng => asset_ref,
        :edge3co2 => asset_ref
    )

    asset2 = Battery(:asset2, storage, edge_to_storage, edge_from_storage)
    asset_ref2 = Ref(asset2)
    asset_map2 = Dict{Symbol, Base.RefValue{<: AbstractAsset}}(
        :edge2 => asset_ref2,
        :edge4 => asset_ref2,
        :storage1 => asset_ref2
    )

    system = empty_system(@__DIR__)
    add!(system, node1)
    add!(system, node2)
    add!(system, asset1)
    add!(system, asset2)

    @testset "Helper Functions Tests" begin
        # Test get_commodity_name for a vertex
        @test get_commodity_name(node1) == :Electricity
        @test get_commodity_name(node2) == :Electricity
        @test get_commodity_name(storage) == :Electricity

        # Test get_commodity_name for an edge
        @test get_commodity_name(edge_between_nodes) == :Electricity
        @test get_commodity_name(edge_to_storage) == :Electricity
        @test get_commodity_name(edge_to_transformation) == :Electricity
        @test get_commodity_name(edge_from_storage) == :Electricity
        @test get_commodity_name(edge_from_transformation) == :Electricity
        @test get_commodity_name(edge_storage_transformation) == :Electricity

        # Test get_commodity_subtype for a vertex
        @test get_commodity_subtype(capacity) == :capacity
        @test get_commodity_subtype(new_capacity) == :capacity
        @test get_commodity_subtype(retired_capacity) == :capacity
        @test get_commodity_subtype(flow) == :flow
        @test get_commodity_subtype(storage_level) == :storage_level
        @test get_commodity_subtype(non_served_demand) == :non_served_demand

        # Test get_resource_id for a vertex
        @test get_resource_id(node1) == :node1
        @test get_resource_id(node2) == :node2
        @test get_resource_id(storage, asset_map2) == :asset2
        @test get_resource_id(edge_from_storage, asset_map2) == :asset2
        @test get_resource_id(edge_to_storage, asset_map2) == :asset2
        @test get_resource_id(edge_to_transformation, asset_map) == :asset1
        @test get_resource_id(edge_from_transformation1, asset_map) == :asset1

        # Test get_component_id for a vertex
        @test get_component_id(node1) == :node1
        @test get_component_id(node2) == :node2
        @test get_component_id(storage) == :storage1

        # Test get_component_id for an edge
        @test get_component_id(edge_between_nodes) == :edge1
        @test get_component_id(edge_to_storage) == :edge2
        @test get_component_id(edge_to_transformation) == :edge3
        @test get_component_id(edge_from_storage) == :edge4
        @test get_component_id(edge_from_transformation) == :edge5
        @test get_component_id(edge_storage_transformation) == :edge6

        # Test get_zone_name for a vertex
        @test get_zone_name(node1) == :node1
        @test get_zone_name(node2) == :node2
        @test get_zone_name(storage) == :storage1
        @test get_zone_name(transformation) == :transformation1

        # Test get_zone_name for an edge
        @test get_zone_name(edge_between_nodes) == :node1_node2
        @test get_zone_name(edge_to_storage) == :node1
        @test get_zone_name(edge_to_transformation) == :node1
        @test get_zone_name(edge_from_storage) == :node2
        @test get_zone_name(edge_from_transformation) == :node2
        @test get_zone_name(edge_storage_transformation) == :internal

        # Test get_type
        @test get_type(asset_ref) == Symbol("ThermalPower{NaturalGas}")
        @test get_type(asset_ref2) == Symbol("Battery")

        # Test get_unit
        # @test get_unit(edge_between_nodes) == :MWh
        # @test get_unit(edge_to_storage) == :MWh
        # @test get_unit(node1) == :MWh
        # @test get_unit(storage) == :MWh
    end

    mock_edges = [edge_between_nodes,
        edge_to_storage,
        edge_to_transformation,
        edge_from_storage,
        edge_from_transformation,
        edge_storage_transformation
    ]

    obj_asset_map = Dict{Symbol, Base.RefValue{<: AbstractAsset}}(:edge1 => asset_ref,
        :edge2 => asset_ref,
        :edge3 => asset_ref,
        :edge4 => asset_ref,
        :edge5 => asset_ref,
        :edge6 => asset_ref
    )

    @testset "get_optimal_vars Tests" begin
        result = get_optimal_vars(mock_edges, capacity, 2.0, obj_asset_map)
        @test length(result) == 6
        @test result[1].commodity == :Electricity
        @test result[1].commodity_subtype == :capacity
        @test result[1].zone == :node1_node2
        @test result[1].resource_id == :asset1
        @test result[1].component_id == :edge1
        @test result[1].type == Symbol("ThermalPower{NaturalGas}")
        @test result[1].variable == :capacity
        @test result[1].year === missing
        @test result[1].segment === missing
        @test result[1].time === missing
        # @test result[1].unit == :MWh
        @test result[1].value == 200.0
        @test result[2].commodity == :Electricity
        @test result[2].commodity_subtype == :capacity
        @test result[2].zone == :node1
        @test result[2].resource_id == :asset1
        @test result[2].component_id == :edge2
        @test result[2].type == Symbol("ThermalPower{NaturalGas}")
        @test result[2].variable == :capacity
        @test result[2].year === missing
        @test result[2].segment === missing
        @test result[2].time === missing
        # @test result[2].unit == :MWh
        @test result[2].value == 202.0
        @test result[3].commodity == :Electricity
        @test result[3].commodity_subtype == :capacity
        @test result[3].zone == :node1
        @test result[3].resource_id == :asset1
        @test result[3].component_id == :edge3
        @test result[3].type == Symbol("ThermalPower{NaturalGas}")
        # @test result[3].unit == :MWh
        @test result[3].value == 204.0
        @test result[4].commodity == :Electricity
        @test result[4].commodity_subtype == :capacity
        @test result[4].zone == :node2
        @test result[4].resource_id == :asset1
        @test result[4].component_id == :edge4
        @test result[4].type == Symbol("ThermalPower{NaturalGas}")
        # @test result[4].unit == :MWh
        @test result[4].value == 206.0
        @test result[5].commodity == :Electricity
        @test result[5].commodity_subtype == :capacity
        @test result[5].zone == :node2
        @test result[5].resource_id == :asset1
        @test result[5].component_id == :edge5
        @test result[5].type == Symbol("ThermalPower{NaturalGas}")
        # @test result[5].unit == :MWh
        @test result[5].value == 208.0
        @test result[6].commodity == :Electricity
        @test result[6].commodity_subtype == :capacity
        @test result[6].zone == :internal
        @test result[6].resource_id == :asset1
        @test result[6].component_id == :edge6
        @test result[6].type == Symbol("ThermalPower{NaturalGas}")
        # @test result[6].unit == :MWh
        @test result[6].value == 210.0
        result = get_optimal_vars(Edge{Electricity}[edge_between_nodes], (new_capacity), 5.0)
        @test length(result) == 1
        @test result[1].commodity == :Electricity
        @test result[1].commodity_subtype == :capacity
        @test result[1].zone == :node1_node2
        @test result[1].resource_id == :edge1
        @test result[1].component_id == :edge1
        @test result[1].type == Symbol("Edge{Electricity}")
        # @test result[1].unit == :MWh
        @test result[1].value == 0.0
        result = get_optimal_vars(Storage[storage], new_capacity, 5.0, Dict{Symbol, Base.RefValue{<: AbstractAsset}}(:storage1 => asset_ref2))
        @test length(result) == 1
        @test result[1].commodity == :Electricity
        @test result[1].commodity_subtype == :capacity
        @test result[1].zone == :storage1
        @test result[1].resource_id == :asset2
        @test result[1].component_id == :storage1
        @test result[1].type == Symbol("Battery")
        # @test result[1].unit == :MWh
        @test result[1].value == 500.0
        result = get_optimal_vars(Storage[storage], (new_capacity), 5.0, Dict{Symbol, Base.RefValue{<: AbstractAsset}}(:storage1 => asset_ref2))
        @test length(result) == 1
        @test result[1].commodity == :Electricity
        @test result[1].commodity_subtype == :capacity
        @test result[1].zone == :storage1
        @test result[1].resource_id == :asset2
        @test result[1].component_id == :storage1
        @test result[1].type == Symbol("Battery")
        # @test result[1].unit == :MWh
        @test result[1].value == 500.0
    end

    function check_output_row(row, expected_commodity, expected_commodity_subtype, expected_zone, expected_resource_id, expected_component_id, expected_type, expected_variable, expected_year, expected_segment, expected_time, expected_value)
        @test row.commodity == expected_commodity
        @test row.commodity_subtype == expected_commodity_subtype
        @test row.zone == expected_zone
        @test row.resource_id == expected_resource_id
        @test row.component_id == expected_component_id
        @test row.type == expected_type
        @test row.variable == expected_variable
        @test row.year === expected_year
        @test row.segment == expected_segment
        @test row.time == expected_time
        @test row.value == expected_value
        # @test row.unit == expected_unit
    end

    @testset "get_optimal_vars_timeseries Tests" begin
        expected_values = [
            (:Electricity, :flow, :node1_node2, :asset1, :edge1, Symbol("ThermalPower{NaturalGas}"), :flow, missing, 1, [1, 2, 3], [1.0, 2.0, 3.0]) #, :MWh),
            (:Electricity, :flow, :node1, :asset1, :edge2, Symbol("ThermalPower{NaturalGas}"), :flow, missing, 1, [1, 2, 3], [4.0, 5.0, 6.0]) #, :MWh),
            (:Electricity, :flow, :node1, :asset1, :edge3, Symbol("ThermalPower{NaturalGas}"), :flow, missing, 1, [1, 2, 3], [7.0, 8.0, 9.0]) #, :MWh),
            (:Electricity, :flow, :node2, :asset1, :edge4, Symbol("ThermalPower{NaturalGas}"), :flow, missing, 1, [1, 2, 3], [10.0, 11.0, 12.0]) #, :MWh),
            (:Electricity, :flow, :node2, :asset1, :edge5, Symbol("ThermalPower{NaturalGas}"), :flow, missing, 1, [1, 2, 3], [13.0, 14.0, 15.0]) #, :MWh),
            (:Electricity, :flow, :internal, :asset1, :edge6, Symbol("ThermalPower{NaturalGas}"), :flow, missing, 1, [1, 2, 3], [16.0, 17.0, 18.0]) #, :MWh)
        ]
        result = get_optimal_vars_timeseries(mock_edges, flow, 1.0, obj_asset_map)
        @test length(result) == 18
        index = 1
        for (commodity, commodity_subtype, zone, resource_id, component_id, type, variable, year, segment, times, values) in expected_values
            for i in eachindex(times)
                check_output_row(result[index], commodity, commodity_subtype, zone, resource_id, component_id, type, variable, year, segment, times[i], values[i])
                index += 1
            end
        end
        result = get_optimal_vars_timeseries(storage, storage_level, 1.0, Dict{Symbol, Base.RefValue{<: AbstractAsset}}(:storage1 => asset_ref2))
        @test length(result) == 3
        for i = 1:3
            check_output_row(result[i], :Electricity, :storage_level, :storage1, :asset2, :storage1, :Battery, :storage_level, missing, 1, i, i)
        end
        result = get_optimal_vars_timeseries(storage, tuple(storage_level), 1.0, Dict{Symbol, Base.RefValue{<: AbstractAsset}}(:storage1 => asset_ref2))
        @test length(result) == 3
        for i = 1:3
            check_output_row(result[i], :Electricity, :storage_level, :storage1, :asset2, :storage1, :Battery, :storage_level, missing, 1, i, i)
        end
        result = get_optimal_vars_timeseries([node1, node2], max_non_served_demand, 1.0)
        @test length(result) == 6
        for i = 1:6
            check_output_row(result[i], :Electricity, :max_non_served_demand, i <= 3 ? :node1 : :node2, i <= 3 ? :node1 : :node2, i <= 3 ? :node1 : :node2, Symbol("Node{Electricity}"), :max_non_served_demand, missing, 1, (i-1) % 3 + 1, i-1)
        end
        result = get_optimal_vars_timeseries([node1, node2], tuple(max_non_served_demand), 1.0)
        @test length(result) == 6
        for i = 1:6
            check_output_row(result[i], :Electricity, :max_non_served_demand, i <= 3 ? :node1 : :node2, i <= 3 ? :node1 : :node2, i <= 3 ? :node1 : :node2, Symbol("Node{Electricity}"), :max_non_served_demand, missing, 1, (i-1) % 3 + 1, i-1)
        end
    end

    # Test get_macro_objs functions
    @testset "get_macro_objs Tests" begin
        edges = get_edges([asset1, asset2])
        @test length(edges) == 5
        @test edges[1] == edge_to_transformation
        @test edges[2] == edge_from_transformation1
        @test edges[3] == edge_from_transformation2
        @test edges[4] == edge_to_storage
        @test edges[5] == edge_from_storage
        sys_edges = get_edges(system)
        @test length(sys_edges) == 5
        @test sys_edges == edges
        nodes = get_nodes(system)
        @test length(nodes) == 2
        @test nodes[1] == node1
        @test nodes[2] == node2
        transformations = get_transformations(system)
        @test length(transformations) == 1
        @test transformations[1] == transformation
    end

    # Test edges_with_capacity_variables
    @testset "edges_with_capacity_variables Tests" begin
        edges_with_capacity = edges_with_capacity_variables([asset1, asset2])
        @test length(edges_with_capacity) == 1
        @test edges_with_capacity[1] == edge_to_transformation
        edges_with_capacity, edge_asset_map = edges_with_capacity_variables([asset1, asset2], return_ids_map=true)
        @test length(edges_with_capacity) == 1
        @test edges_with_capacity[1] == edge_to_transformation
        @test edge_asset_map[:edge3][] == asset1
        edges_with_capacity = edges_with_capacity_variables(asset1)
        @test length(edges_with_capacity) == 1
        @test edges_with_capacity[1] == edge_to_transformation
        edges_with_capacity = edges_with_capacity_variables(system)
        @test length(edges_with_capacity) == 1
        @test edges_with_capacity[1] == edge_to_transformation
    end
        
    @testset "convert_to_dataframe Tests" begin
        output_rows = [
            OutputRow(:case_name1, :commodity1, :commodity_subtype1, :zone1, :resource_id1, :component_id1, :type1, :variable1, 2025, 1, 1, 123.45) #, :unit1),
            OutputRow(:case_name2, :commodity2, :commodity_subtype2, :zone2, :resource_id2, :component_id2, :type2, :variable2, 2027, 2, 5, 678.90) #, :unit2)
        ]
        df1 = convert_to_dataframe(output_rows)

        output_rows_tuple = [
            (:case_name1, :commodity1, :commodity_subtype1, :zone1, :resource_id1, :component_id1, :type1, :variable1, 2025, 1, 1, 123.45) #, :unit1),
            (:case_name2, :commodity2, :commodity_subtype2, :zone2, :resource_id2, :component_id2, :type2, :variable2, 2027, 2, 5, 678.90) #, :unit2)
        ]
        header = [:case_name, :commodity, :commodity_subtype, :zone, :resource_id, :component_id, :type, :variable, :year, :segment, :time, :value] #, :unit]
        df2 = convert_to_dataframe(output_rows_tuple, header)

        for df in [df1, df2]
            @test size(df, 1) == 2  # Number of rows
            @test size(df, 2) == 12  # Number of columns
            @test df[1, :case_name] == :case_name1
            @test df[1, :commodity] == :commodity1
            @test df[1, :commodity_subtype] == :commodity_subtype1
            @test df[1, :zone] == :zone1
            @test df[1, :resource_id] == :resource_id1
            @test df[1, :component_id] == :component_id1
            @test df[1, :type] == :type1
            @test df[1, :variable] == :variable1
            @test df[1, :year] == 2025
            @test df[1, :segment] == 1
            @test df[1, :time] == 1
            @test df[1, :value] == 123.45
            # @test df[1, :unit] == :unit1
            @test df[2, :case_name] == :case_name2
            @test df[2, :commodity] == :commodity2
            @test df[2, :commodity_subtype] == :commodity_subtype2
            @test df[2, :zone] == :zone2
            @test df[2, :resource_id] == :resource_id2
            @test df[2, :component_id] == :component_id2
            @test df[2, :type] == :type2
            @test df[2, :variable] == :variable2
            @test df[2, :year] == 2027
            @test df[2, :segment] == 2
            @test df[2, :time] == 5
            @test df[2, :value] == 678.90
            # @test df[2, :unit] == :unit2
        end
    end

    @testset "get_output_dir Tests" begin
        # Create a temporary directory for testing
        test_dir = mktempdir()
        
        # Create a mock system with different settings
        system1 = empty_system(test_dir)
        system1.settings = (OutputDir = "results", OverwriteResults = true)
        
        # Test overwriting existing directory
        output_path1 = create_output_path(system1)
        @test isdir(output_path1)
        @test output_path1 == joinpath(test_dir, "results")
        
        # Create second path - should still use same directory
        output_path2 = create_output_path(system1)
        @test output_path2 == output_path1
        
        # Test with OverwriteResults = 0 (no overwrite)
        system2 = empty_system(test_dir)
        system2.settings = (OutputDir = "results", OverwriteResults = false)
        
        # This is the second call, so it should create "results_001"
        output_path3 = create_output_path(system2)
        @test isdir(output_path3)
        @test output_path3 == joinpath(test_dir, "results_001")
        
        # Third call should create "results_002"
        output_path4 = create_output_path(system2)
        @test isdir(output_path4)
        @test output_path4 == joinpath(test_dir, "results_002")

        # Test with path argument specified
        output_path6 = create_output_path(system2, joinpath(test_dir, "path", "to", "output"))
        @test isdir(output_path6)
        @test output_path6 == joinpath(test_dir, "path", "to", "output", "results_001")

        # Second call with path argument should create "path/to/output/results_002"
        output_path7 = create_output_path(system2, joinpath(test_dir, "path", "to", "output"))
        @test isdir(output_path7)
        @test output_path7 == joinpath(test_dir, "path", "to", "output", "results_002")
        
        # Cleanup
        rm(test_dir, recursive=true)

        @testset "choose_output_dir Tests" begin
            # Create a temporary directory for testing
            test_dir = mktempdir()
            
            # Test with non-existing directory
            result = find_available_path(test_dir)
            @test result == joinpath(test_dir, "results_001") # Should return original path if it doesn't exist
            
            
            # Create multiple directories and test incremental numbering
            mkpath(joinpath(test_dir, "newdir_002"))
            mkpath(joinpath(test_dir, "newdir_004"))
            result = find_available_path(test_dir, "newdir")
            @test result == joinpath(test_dir, "newdir_001")  # Should append _001

            mkpath(joinpath(test_dir, "newdir_001"))
            result = find_available_path(test_dir, "newdir")
            @test result == joinpath(test_dir, "newdir_003")

            # Test with path containing trailing slash
            path_with_slash = joinpath(test_dir, "dirwithslash/")
            mkpath(path_with_slash)
            result = find_available_path(path_with_slash)
            @test result == joinpath(test_dir, "dirwithslash/results_001")
            
            # Test with path containing spaces
            path_with_spaces = joinpath(test_dir, "my dir")
            mkpath(path_with_spaces)
            result = find_available_path(path_with_spaces)
            @test result == joinpath(test_dir, "my dir/results_001")
            
            # Cleanup
            rm(test_dir, recursive=true)
        end
    end
end

test_writing_output()

end # module TestOutput

