function load_variability!(filepath::AbstractString, resources::Vector{Resource})

    df_variability = load_dataframe(filepath)

    for resource in resources
        r_id = resource_id(resource)
        if r_id ∈ names(df_variability)
            resource.capacity_factor = df_variability[!, r_id]
        else
            @warn "Unknown variability for resource $r_id."
        end
    end

    return resources
end
