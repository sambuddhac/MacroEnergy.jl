function get_optimal_capacity(system::System)
    getter::Function = capacity
    edges = get_edges(system)
    asset_capacity = get_optimal_vars(edges, getter, :MW)
    df = convert_to_dataframe(asset_capacity)
    df[!, (!isa).(eachcol(df), Vector{Missing})] # remove missing columns
end

function get_optimal_new_capacity(system::System)
    getter::Function = new_capacity
    edges = get_edges(system)
    asset_capacity = get_optimal_vars(edges, getter, :MW)
    df = convert_to_dataframe(asset_capacity)
    df[!, (!isa).(eachcol(df), Vector{Missing})] # remove missing columns
end

function get_optimal_ret_capacity(system::System)
    getter::Function = ret_capacity
    edges = get_edges(system)
    asset_capacity = get_optimal_vars(edges, getter, :MW)
    df = convert_to_dataframe(asset_capacity)
    df[!, (!isa).(eachcol(df), Vector{Missing})] # remove missing columns
end




