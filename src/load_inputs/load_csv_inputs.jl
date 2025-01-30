###### ###### ###### ###### ###### ######
# CSV data handling
###### ###### ###### ###### ###### ######

@doc raw"""
    load_time_series_data(file_path::AbstractString, header::AbstractVector{Symbol})::Dict{Symbol,Any}

    Load time series data from one or more headers in a CSV file and return as a DataFrame.

"""
function load_csv(
    file_path::AbstractString;
    select::S = Symbol[],
    lazy_load::Bool = true,
) where {S<:Union{Symbol,Vector{Symbol}}}
    if isa(select, Symbol)
        select = [select]
    end
    csv_data = read_csv(file_path, select)
    return csv_data
    #TODO check how to use lazy_load with CSV files
end