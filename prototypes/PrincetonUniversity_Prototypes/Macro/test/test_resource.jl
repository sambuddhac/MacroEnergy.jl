module TestResource

    using Macro
    using Test

    function test_VRE_ctor()
        node = 1
        r_id = 1
        investment_cost = 85300.0
        fixed_om_cost = 18760.
        vre = VRE{Electricity}(node = node, r_id = r_id, investment_cost = investment_cost, fixed_om_cost = fixed_om_cost)
        
        # Test that the BaseResource fields are inherited correctly 
        @test Macro.commodity_type(vre) == Electricity
        @test Macro.time_interval(vre) == Macro.time_interval_map[Electricity]
        @test Macro.existing_capacity(vre) == 0.0
        @test Macro.can_expand(vre) == true
        @test Macro.can_retire(vre) == true
        @test Macro.node(vre) == node
        @test Macro.resource_id(vre) == r_id
        @test Macro.investment_cost(vre) == investment_cost
        @test Macro.fixed_om_cost(vre) == fixed_om_cost

        # Test that the VRE fields are set correctly
        return nothing
    end

    function test_VRE_setproperty()
        node = 1
        r_id = 1
        investment_cost = 85300.0
        fixed_om_cost = 18760.
        vre = VRE{Electricity}(node = node, r_id = r_id, investment_cost = investment_cost, fixed_om_cost = fixed_om_cost)
        
        # Test that the BaseResource fields are set correctly
        @test setproperty!(vre, :existing_capacity, 100.0) == 100.0
        @test setproperty!(vre, :can_expand, false) == false
        @test setproperty!(vre, :can_retire, false) == false
        @test setproperty!(vre, :investment_cost, 100.0) == 100.0
        @test setproperty!(vre, :fixed_om_cost, 100.0) == 100.0
        
        # Test that the VRE fields are set correctly
        return nothing
    end

    test_VRE_ctor()
    test_VRE_setproperty()

end # module TestResource