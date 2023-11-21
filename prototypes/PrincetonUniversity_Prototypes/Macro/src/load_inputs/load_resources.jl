function load_resources(filepath::AbstractString)

    df_resources = load_dataframe(filepath)

    adjust_cols_names!(df_resources)
    adjust_cols_types!(df_resources)

    commodities = popat_col!(df_resources, :commodity)
    # vector of structs
    resources = Vector{Resource}(undef, length(eachrow(df_resources)))
    # for row in Tables.namedtupleiterator(df_resources)
    for (i, row) in enumerate(eachrow(df_resources))
        commodity = commodity_type(commodities[i])
        resources[i] = Resource{commodity}(; row...)
    end

    return resources
end

function adjust_cols_names!(df::DataFrame)
    for col in names(df)
        rename!(df, col => Symbol(lowercase(col)))
    end
    rename!(df, :resource => :r_id)
end

# only r_id and node are Int64
function adjust_cols_types!(df::DataFrame)
    cols = [col for col in names(df, Int) if col != "node"]
    df[!, cols] = float.(df[!, cols])
end

function popat_col!(df::DataFrame, col::Symbol)
    @assert (col ∈ propertynames(df))
    col_values = df[!, col]
    select!(df, Not(col))
    return col_values
end

function commodity_type(c::AbstractString)
    T::DataType = eval(Symbol(c))
    @assert (T <: Commodity)
    return T
end
