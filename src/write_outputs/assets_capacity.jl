function get_optimal_asset_capacity(system::System)
    capacity_results = Dict{Int64,Float64}();
    for i in eachindex(system.assets)
        a=system.assets[i];
        for f in fieldnames(typeof(a))
            y = getproperty(a,f);
            if isa(y,AbstractEdge) 
                if has_planning_variables(y)
                    vcap = value(capacity(y));
                    if vcap!=0
                        #### TODO - Here it should use the edge ID instead of the index, but we have some problems when loading the ids from the json file
                        capacity_results[i] = vcap;
                    end
                end
            end
        end
    end
    return capacity_results

end