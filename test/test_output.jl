module TestOutput

using Test
using Macro
import Macro:
    OutputRow,
    TimeData,
    capacity,
    flow,
    new_capacity_storage,
    storage_level,
    max_non_served_demand,
    get_region_name,
    get_header_variable_name,
    get_type,
    get_unit,
    get_optimal_vars,
    get_optimal_vars_timeseries,
    convert_to_dataframe


function test_writing_output()

    @testset "OutputRow Tests" begin
        # Test the first constructor (no time field)
        output1 = OutputRow(:Region1, :Variable1, :Type1, :Unit1, 123.45)
        @test output1.model === missing
        @test output1.scenario === missing
        @test output1.region == :Region1
        @test output1.variable == :Variable1
        @test output1.type == :Type1
        @test output1.unit == :Unit1
        @test output1.time === missing
        @test output1.value == 123.45

        # Test the second constructor (for time series data)
        output2 = OutputRow(:Region2, :Variable2, :Type2, :Unit2, 2023, 678.90)
        @test output2.model === missing
        @test output2.scenario === missing
        @test output2.region == :Region2
        @test output2.variable == :Variable2
        @test output2.type == :Type2
        @test output2.unit == :Unit2
        @test output2.time == 2023
        @test output2.value == 678.90
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
        new_capacity_storage=100.0,
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

    @testset "Helper Functions Tests" begin
        # Test get_region_name for a vertex
        @test get_region_name(node1) == :node1
        @test get_region_name(node2) == :node2
        @test get_region_name(storage) == :storage1
        @test get_region_name(transformation) == :transformation1

        # Test get_region_name for an edge
        @test get_region_name(edge_between_nodes) == :node1_node2
        @test get_region_name(edge_to_storage) == :node1
        @test get_region_name(edge_to_transformation) == :node1
        @test get_region_name(edge_from_storage) == :node2
        @test get_region_name(edge_from_transformation) == :node2
        @test get_region_name(edge_storage_transformation) == :internal

        # Test get_header_variable_name
        @test get_header_variable_name(edge_between_nodes, capacity) == Symbol("capacity|Electricity|edge1")
        @test get_header_variable_name(edge_to_storage, capacity) == Symbol("capacity|Electricity|edge2")
        @test get_header_variable_name(edge_to_transformation, capacity) == Symbol("capacity|Electricity|edge3")
        @test get_header_variable_name(edge_from_storage, capacity) == Symbol("capacity|Electricity|edge4")
        @test get_header_variable_name(edge_from_transformation, capacity) == Symbol("capacity|Electricity|edge5")
        @test get_header_variable_name(edge_storage_transformation, capacity) == Symbol("capacity|Electricity|edge6")
        @test get_header_variable_name(node1, capacity) == Symbol("capacity|Electricity|node1")
        @test get_header_variable_name(storage, capacity) == Symbol("capacity|Electricity|storage1")

        # Test get_type
        @test get_type(asset_ref) == Symbol("ThermalPower{NaturalGas}")

        # Test get_unit
        @test get_unit(edge_between_nodes) == :MWh
        @test get_unit(edge_to_storage) == :MWh
        @test get_unit(node1) == :MWh
        @test get_unit(storage) == :MWh
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
        result = get_optimal_vars(mock_edges, capacity, :MW, obj_asset_map)
        @test length(result) == 6
        @test result[1].region == :node1_node2
        @test result[1].variable == Symbol("capacity|Electricity|edge1")
        @test result[1].type == Symbol("ThermalPower{NaturalGas}")
        @test result[1].unit == :MW
        @test result[1].value == 100.0
        @test result[2].region == :node1
        @test result[2].variable == Symbol("capacity|Electricity|edge2")
        @test result[2].type == Symbol("ThermalPower{NaturalGas}")
        @test result[2].unit == :MW
        @test result[2].value == 101.0
        @test result[3].region == :node1
        @test result[3].variable == Symbol("capacity|Electricity|edge3")
        @test result[3].type == Symbol("ThermalPower{NaturalGas}")
        @test result[3].unit == :MW
        @test result[3].value == 102.0
        @test result[4].region == :node2
        @test result[4].variable == Symbol("capacity|Electricity|edge4")
        @test result[4].type == Symbol("ThermalPower{NaturalGas}")
        @test result[4].unit == :MW
        @test result[4].value == 103.0
        @test result[5].region == :node2
        @test result[5].variable == Symbol("capacity|Electricity|edge5")
        @test result[5].type == Symbol("ThermalPower{NaturalGas}")
        @test result[5].unit == :MW
        @test result[5].value == 104.0
        @test result[6].region == :internal
        @test result[6].variable == Symbol("capacity|Electricity|edge6")
        @test result[6].type == Symbol("ThermalPower{NaturalGas}")
        @test result[6].unit == :MW
        @test result[6].value == 105.0
        result = get_optimal_vars(Storage[storage], new_capacity_storage, :MW, Dict{Symbol, Base.RefValue{<: AbstractAsset}}(:storage1 => asset_ref))
        @test length(result) == 1
        @test result[1].region == :storage1
        @test result[1].variable == Symbol("new_capacity_storage|Electricity|storage1")
        @test result[1].type == Symbol("ThermalPower{NaturalGas}")
        @test result[1].unit == :MW
        @test result[1].value == 100.0
    end

    function check_output_row(row, expected_region, expected_variable, expected_type, expected_unit, expected_time, expected_value)
        @test row.region == expected_region
        @test row.variable == expected_variable
        @test row.type == expected_type
        @test row.unit == expected_unit
        @test row.time == expected_time
        @test row.value == expected_value
    end

    @testset "get_optimal_vars_timeseries Tests" begin
        expected_values = [
            (:node1_node2, Symbol("flow|Electricity|edge1"), Symbol("ThermalPower{NaturalGas}"), :MWh, [1, 2, 3], [1.0, 2.0, 3.0]),
            (:node1, Symbol("flow|Electricity|edge2"), Symbol("ThermalPower{NaturalGas}"), :MWh, [1, 2, 3], [4.0, 5.0, 6.0]),
            (:node1, Symbol("flow|Electricity|edge3"), Symbol("ThermalPower{NaturalGas}"), :MWh, [1, 2, 3], [7.0, 8.0, 9.0]),
            (:node2, Symbol("flow|Electricity|edge4"), Symbol("ThermalPower{NaturalGas}"), :MWh, [1, 2, 3], [10.0, 11.0, 12.0]),
            (:node2, Symbol("flow|Electricity|edge5"), Symbol("ThermalPower{NaturalGas}"), :MWh, [1, 2, 3], [13.0, 14.0, 15.0]),
            (:internal, Symbol("flow|Electricity|edge6"), Symbol("ThermalPower{NaturalGas}"), :MWh, [1, 2, 3], [16.0, 17.0, 18.0])
        ]
        result = get_optimal_vars_timeseries(mock_edges, flow, obj_asset_map)
        @test length(result) == 18
        index = 1
        for (region, variable, type, unit, times, values) in expected_values
            for (time, value) in zip(times, values)
                check_output_row(result[index], region, variable, type, unit, time, value)
                index += 1
            end
        end
        result = get_optimal_vars_timeseries(storage, storage_level, Dict{Symbol, Base.RefValue{<: AbstractAsset}}(:storage1 => asset_ref))
        @test length(result) == 3
        for i = 1:3
            check_output_row(result[i], :storage1, Symbol("storage_level|Electricity|storage1"), Symbol("ThermalPower{NaturalGas}"), :MWh, i, i)
        end
        result = get_optimal_vars_timeseries([node1, node2], max_non_served_demand)
        @test length(result) == 6
        for i = 1:6
            check_output_row(result[i], i <= 3 ? :node1 : :node2, Symbol("max_non_served_demand|Electricity|node$(i <= 3 ? 1 : 2)"), :Electricity, :MWh, (i-1) % 3 + 1 , i-1)
        end
    end

    @testset "convert_to_dataframe Tests" begin
        output_rows = [
            OutputRow(:Region1, :Variable1, :Type1, :Unit1, 123.45),
            OutputRow(:Region2, :Variable2, :Type2, :Unit2, 2023, 678.90)
        ]

        df = convert_to_dataframe(output_rows)
        @test size(df, 1) == 2  # Number of rows
        @test size(df, 2) == 8  # Number of columns
        @test df[1, :region] == :Region1
        @test df[2, :time] == 2023
        @test df[1, :value] == 123.45
        @test df[2, :value] == 678.90
        @test df[1, :variable] == :Variable1
        @test df[2, :variable] == :Variable2
        @test df[1, :type] == :Type1
        @test df[2, :type] == :Type2
        @test df[1, :unit] == :Unit1
        @test df[2, :unit] == :Unit2
    end
end

test_writing_output()

end # module TestOutput

