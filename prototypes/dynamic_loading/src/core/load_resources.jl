using CSV, DataFrames

function load_resource_data(filepath::String) :: DataFrame
    # Read CSV with strings as full strings
    df = CSV.read(filepath, DataFrame, stringtype=String)
    return df
end

macro datatype(str::AbstractString)
    s = uppercasefirst(str)
    return :($(Symbol(s)))
end

function check_datatype_present(datatype_name::AbstractString)
    try 
        @datatype datatype_name
        return true
    catch
        return false
    end
end

function load_if_not_present(resource_type::AbstractString)
    println(resource_type)
    if !check_datatype_present(resource_type)
        print("\nLoading resource type: ", resource_type, " ... ")
        resource_filepath = joinpath(dirname(@__DIR__), "resources", string(resource_type, ".jl"))
        if isdir(resource_filepath)
            include(joinpath(resource_filepath, "resource.jl"))
            return resource_type
        else
            println("Changing $resource_type to generic resource")
            return "Resource"
        end
        print("Done")
    end
end

function make_resources(resource_data::DataFrame, resources::Array{Resource,1}=Resource[])
    for row in eachrow(resource_data)
        # Check that we've loaded the resource before
        println(row.Type)
        row.Type = load_if_not_present(row.Type)
        push!(resources, makeresource(row))
    end
    return resources
end

function load_resources(filepath::String, resources::Array{Resource,1}=Resource[])
    resource_data = load_resource_data(filepath)
    resources = make_resources(resource_data, resources)
    return resources
end