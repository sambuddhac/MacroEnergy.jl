function load_variability!(filepath::AbstractString, resources::Vector{Resource})

    df_variability = load_dataframe(filepath)

    for resource in resources
        id = resource_id(resource)
        if id ∈ propertynames(df_variability)
            resource.capacity_factor = df_variability[!, id]
        else
            @warn "Unknown variability for resource $id"
        end
    end

    return resources
end
