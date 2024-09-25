struct OutputRow
    model::Union{Symbol,Missing}
    scenario::Union{Symbol,Missing}
    region::Symbol
    variable::Symbol
    unit::Symbol
    time::Union{Int,Missing}
    value::Float64
    OutputRow(region::Symbol, variable::Symbol, unit::Symbol, value::Float64) =
        new(missing, missing, region, variable, unit, missing, value)
    OutputRow(region::Symbol, variable::Symbol, unit::Symbol, time::Int, value::Float64) =
        new(missing, missing, region, variable, unit, time, value)
end
function write_csv(file_path::AbstractString, data::AbstractDataFrame)
    CSV.write(file_path, data)
end
