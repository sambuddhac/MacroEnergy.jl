
### NOTE : CO2 emission coefficients are loaded as part of the stoichiometry balance for the transform

function load_fuel_data!(assets::Vector{AbstractAsset}, system_dir::AbstractString)
    fuel_dir = joinpath(system_dir, "fuel_data")
    fuel_data = load_all_ts(fuel_dir)
    
    #co2_emission = load_co2_emission(fuel_dir)

    add_fuel_to_assets!(assets, fuel_data)#, co2_emission)

    return nothing
end

function load_fuel_data!(system_dir::AbstractString, assets::Dict{Symbol,AbstractAsset})
    fuel_dir = joinpath(system_dir, "fuel_data")
    fuel_data = load_all_ts(fuel_dir)
    
    ####co2_emission = load_co2_emission(fuel_dir)

    add_fuel_to_assets!(assets, fuel_data)#, co2_emission)

    return nothing
end

# function load_co2_emission(fuel_dir::AbstractString)
#     file = "co2_emission.json"
#     co2_emission_data = JSON3.read(joinpath(fuel_dir, file))
#     return co2_emission_data
# end

function add_fuel_to_assets!(assets::Vector{AbstractAsset}, fuel_data::Dict{Symbol,Vector{Float64}})#, co2_emission::AbstractDict{Symbol,Any})
    add_fuel_to_edges!(edges(assets), fuel_data)#, co2_emission)
    return nothing
end 

function add_fuel_to_edges!(edges::Vector{AbstractEdge}, fuel_data::Dict{Symbol,Vector{Float64}})#, co2_emission::AbstractDict{Symbol,Any})
    for e in edges
        if e.price_header ∈ keys(fuel_data)
            e.price = fuel_data[e.price_header] / NG_MWh
        end
        # if e.price_header ∈ keys(co2_emission)
        #     e.st_coeff[:emissions] = co2_emission[e.price_header] / NG_MWh
        # end
    end
    return nothing
end

