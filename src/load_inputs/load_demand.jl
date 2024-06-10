# Load the demand data
function load_demand_data!(nodes::Dict{Symbol,Node}, system_dir::AbstractString, commodities::Dict{Symbol,DataType})
    demand_dir = joinpath(system_dir, "demand_data")
    demand_data = load_ts_all_commodities(demand_dir, commodities, "demand")
    add_demand_to_nodes!(nodes, demand_data)

    nsd_data = load_nsd_data_json(demand_dir)
    add_nsd_to_nodes!(nodes, nsd_data)

    return nothing
end

function load_ts_all_commodities(data_dir::AbstractString, commodities::Dict{Symbol,DataType}, postfix::AbstractString)
    data = Dict{Symbol,DataFrame}()
    for (commodity,_) in commodities
        filename = lowercase(string(commodity)) * "_" * postfix * ".csv"
        data_fullpath = joinpath(data_dir, filename)
        if isfile(data_fullpath)
            data[commodity] = CSV.read(data_fullpath, DataFrame)
        end
    end
    return data
end

function add_demand_to_nodes!(nodes::Dict{Symbol,Node}, demand_data::Dict{Symbol,DataFrame})
    for (_, demand_df) in demand_data
        # loop over columns skipping :Time_Index
        for node_id in propertynames(demand_df[!, 2:end])
            if node_id ∉ keys(nodes)
                msg = "$(node_id) not found in the list of available nodes even if a demand time series was found. \n" *
                "Please make sure to have the correct input data for network and nodes."
                @warn(msg)
                continue
            end
            nodes[node_id].demand = demand_df[:, node_id]
        end
    end
    return nothing
end

function load_nsd_data_json(demand_dir::AbstractString)
    file = "nsd_data.json"

    nsd_data = Dict{Symbol, Dict}()
    data = JSON3.read(joinpath(demand_dir, file))
    for (commodity,data_obj) in data
        nsd_data[Symbol(commodity)] = nsd_to_dict(data_obj)
    end
    return nsd_data
end

function nsd_to_dict(data_raw::JSON3.Object)
    nsd_data = Dict()
    nsd_data[:voll] = data_raw.voll
    nsd_data[:nsd_data] = [Dict(x) for x in data_raw.nsd_data]
    return nsd_data
end

function add_nsd_to_nodes!(nodes::Dict{Symbol,Node}, nsd_data::Dict{Symbol,Dict})
    macro_commodities = commodity_types()
    # loop over commodities in nsd_data
    for (commodity, data) in nsd_data
        commodity = macro_commodities[commodity] # get the correct commodity type
        # for each commodity, add the nsd data to the corresponding nodes
        nodes_commodity = get_all_nodes_type(nodes, commodity)
        for node in values(nodes_commodity)
            max_nsd = Float64.([x[:max_demand_curtailment] for x in data[:nsd_data]])
            node.max_nsd = max_nsd
            price_nsd = Float64.([x[:cost_of_demand_curtailment_per_mw] for x in data[:nsd_data]])
            node.price_nsd = price_nsd
        end
    end
    return nothing
end


            