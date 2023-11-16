using CSV, DataFrames

function loadresources(filepath::String, resources::Array{Resource,1}=Resource[])
    df = CSV.read(filepath, DataFrame)
    for row in eachrow(df)
        push!(resources, makeresource(row))
    end
    return resources
end