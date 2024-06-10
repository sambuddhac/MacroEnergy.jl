function load_fuel_data(system_dir::AbstractString, commodities::Dict{Symbol,DataType})
    fuel_dir = joinpath(system_dir, "fuel_data")
    fuel_data = load_ts_all_commodities(fuel_dir, commodities, "prices")
    
    co2_emission = load_co2_emission(fuel_dir)
    return fuel_data, co2_emission
end

function load_co2_emission(fuel_dir::AbstractString)
    file = "co2_emission.json"

    co2_emission_data = Dict{Symbol, Dict}()
    data = JSON3.read(joinpath(fuel_dir, file))
    for (commodity,data_obj) in data
        co2_emission_data[Symbol(commodity)] = Dict(data_obj)
    end
    return co2_emission_data
end
