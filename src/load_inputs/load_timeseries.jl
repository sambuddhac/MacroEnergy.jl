function load_timeseries(filepath::AbstractString, time_interval::StepRange{Int64,Int64})

    isfile(filepath) || return Dict()

    df_timeseries = load_dataframe(filepath)[first(time_interval):last(time_interval), :]

    time_index = popat_col!(df_timeseries, :Time_Index)

    validate_timeseries(time_index, time_interval)

    time_series = Dict{Symbol,Vector{Float64}}()
    for col in propertynames(df_timeseries)
        time_series[col] = df_timeseries[!, col]
    end
    return time_series
end


#TODO: implement a validation function for timeseries
function validate_timeseries(df::Vector, time_interval::StepRange{Int64,Int64})
    return nothing
end
