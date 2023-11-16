function prepare_inputs!(setup::Dict)

    PeriodLength = setup["PeriodLength"];

    hours_per_subperiod = setup["hours_per_subperiod"];

    hours_per_timestep = Dict(c=>setup[c]["hours_per_timestep"] for c in setup["commodities"]);

    time_interval_map = Dict(c=>1:hours_per_timestep[c]:PeriodLength for c in setup["commodities"])

    subperiod_map = Dict(c=>collect(Iterators.partition(time_interval_map[c],Int(hours_per_subperiod/hours_per_timestep[c]))) for c in setup["commodities"])

    setup["subperiod_map"] = subperiod_map;

    setup["time_interval_map"] = time_interval_map;
     
    return loadresources(setup);
end

function makeresource(c::DataType,row::DataFrameRow,time_interval::StepRange{Int64, Int64},subperiods::Vector{StepRange{Int64, Int64}})
    
    if row.storage==0
        return Resource{c}(node = row.node,r_id=row.r_id,time_interval=time_interval,subperiods=subperiods,investment_cost=row.investment_cost,fixed_om_cost = row.fixed_om_cost,capacity_factor=ones(length(time_interval)),price=zeros(length(time_interval)));
    elseif row.storage==1
        return SymmetricStorage{c}(node = row.node,r_id=row.r_id,time_interval=time_interval,subperiods=subperiods,investment_cost=row.investment_cost,fixed_om_cost = row.fixed_om_cost,capacity_factor=ones(length(time_interval)),price=zeros(length(time_interval)));
    elseif row.storage==2
        return AsymmetricStorage{c}(node = row.node,r_id=row.r_id,time_interval=time_interval,subperiods=subperiods,investment_cost=row.investment_cost,fixed_om_cost = row.fixed_om_cost,capacity_factor=ones(length(time_interval)),price=zeros(length(time_interval)));
    end

end

function loadresources(setup::Dict)
    resources = AbstractResource[]

    for c in setup["commodities"]
        filepath = setup[c]["filepath"];
        nt = length(setup["time_interval_map"][c])
        df = CSV.read(filepath, DataFrame)
        for row in eachrow(df)
            push!(resources, makeresource(c,row,setup["time_interval_map"][c],setup["subperiod_map"][c]))
        end
    end
    return resources
end

