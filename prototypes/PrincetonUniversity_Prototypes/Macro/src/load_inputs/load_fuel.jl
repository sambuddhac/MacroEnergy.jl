function load_fuel_prices!(filepath::AbstractString, resources::Vector{Resource})

    df_fuel_prices = load_dataframe(filepath)

    validate_timeseries(df_fuel_prices)

    df.num = parse.(Int, replace.(df_fuel, r"[A-Z]*_z" => ""))

end

#TODO: do it
function validate_timeseries(df::DataFrame)
    return nothing
end
