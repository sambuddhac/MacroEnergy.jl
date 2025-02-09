const COMMODITY_TYPES = Dict{Symbol,DataType}()

function register_commodity_types!(m::Module = Macro)
    empty!(COMMODITY_TYPES)
    for (commodity_name, commodity_type) in all_subtypes(m, :Commodity)
        COMMODITY_TYPES[commodity_name] = commodity_type
    end
end

function commodity_types(m::Module = Macro)
    isempty(COMMODITY_TYPES) && register_commodity_types!(m)
    return COMMODITY_TYPES
end

function make_commodity(new_commodity::Union{String,Symbol})::String
    s = "abstract type $new_commodity <: Commodity end"
    eval(Meta.parse(s))
    return s
end

function make_commodity(new_commodity::Union{String,Symbol}, parent_type::Union{String,Symbol})::String
    s = "abstract type $new_commodity <: $parent_type end"
    eval(Meta.parse(s))
    return s
end

function make_commodity(new_commodity::Union{String,Symbol}, parent_type::DataType)::String
    return make_commodity(new_commodity, typesymbol(parent_type))
end

function load_commodities(path::AbstractString, rel_path::AbstractString)
    path = rel_or_abs_path(path, rel_path)
    if isdir(path)
        path = joinpath(path, "commodities.json")
    end
    # read in the list of commodities from the data directory
    isfile(path) || error("Commodity data not found at $(abspath(path))")
    return load_commodities(JSON3.read(path))
end

function load_commodities(data::AbstractDict{Symbol,Any}, rel_path::AbstractString)
    if haskey(data, :path)
        path = rel_or_abs_path(data[:path], rel_path)
        return load_commodities(path, rel_path)
    else
        return load_commodities(data)
    end
end

function load_commodities(data::AbstractVector{Dict{Symbol,Any}}, rel_path::AbstractString)
    for item in data
        if isa(item, AbstractDict{Symbol,Any}) && haskey(item, :commodities)
            return load_commodities(item, rel_path)
        end
    end
    error("Commodity data not found or incorrectly formatted in system_data")
end

function load_commodities(data::AbstractVector{<:AbstractString}, rel_path::AbstractString)
    # Probably means we have a vector of commdity types
    return load_commodities(Symbol.(data))
end

function load_commodities(data::AbstractDict{Symbol,Any})
    # make sure the commodities are valid
    if haskey(data, :commodities)
        return load_commodities(data[:commodities])
    end
    return load_commodities(data[:commodities])
end

function load_commodities(commodities::AbstractVector{<:Any}, rel_path::AbstractString="", write_subcommodities::Bool=false)
    subcommodities_path = joinpath(rel_path, "tmp", "subcommodities.jl")
    if isfile(subcommodities_path)
        include(subcommodities_path)
    end
    register_commodity_types!()

    macro_commodities = commodity_types()
    sub_commodities = Vector{Dict{Symbol,Any}}()
    for commodity in commodities
        if commodity isa Dict
        end
        if commodity isa AbstractString
            if Symbol(commodity) ∉ keys(macro_commodities)
                error("Unknown commodity: $commodity")
            end
        elseif commodity isa Dict && haskey(commodity, :name) && commodity[:name] ∉ keys(commodity_types()) && haskey(commodity, :acts_like)
            push!(sub_commodities, commodity)
        else
            error("Invalid commodity format: $commodity")
        end
    end

    subcommodities_lines = String[]

    for commodity in sub_commodities
        new_name = Symbol(commodity[:name])
        if new_name in keys(commodity_types())
            @info("Commodity $new_name already exists")
            continue
        end
        parent_name = Symbol(commodity[:acts_like])
        commodity_keys = keys(commodity_types())
        if parent_name ∈ commodity_keys
            subcommodity_string = make_commodity(new_name, parent_name)
            COMMODITY_TYPES[new_name] = getfield(Macro, new_name)
            if write_subcommodities
                push!(subcommodities_lines, subcommodity_string)
            end
        else
            error("Unknown parent commodity: $parent_name")
        end
    end
    if write_subcommodities && !isempty(subcommodities_lines)
        mkpath(dirname(subcommodities_path))
        io = open(subcommodities_path, "w")
            for line in subcommodities_lines
                println(io, line)
            end
        close(io)
    end
    return commodity_types()
end

load_commodities(commodities::AbstractVector{<:AbstractString}) =
    load_commodities(Symbol.(commodities))

function load_commodities(commodities::Vector{Symbol})
    # get the list of all commodities available
    macro_commodities = commodity_types()

    validate_commodities(commodities)

    # return a dictionary of commodities Dict{Symbol, DataType}
    filter!(((key, _),) -> key in commodities, macro_commodities)
    return macro_commodities
end

function validate_commodities(
    commodities,
    macro_commodities::Dict{Symbol,DataType} = commodity_types(Macro),
)
    if any(commodity -> commodity ∉ keys(macro_commodities), commodities)
        error("Unknown commodities: $(setdiff(commodities, keys(macro_commodities)))")
    end
    return nothing
end
