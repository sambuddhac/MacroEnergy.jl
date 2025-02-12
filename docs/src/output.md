# Macro Output

Macro provides functionality to access and export optimization results. Results can be accessed in memory as DataFrames or written directly to files for further analysis.

Currently, Macro supports the following types of outputs:

- **Capacity results**: final capacity, new capacity, retired capacity for each technology
- **Costs**: total, fixed, variable and total costs for the system
- **Flow results**: flow for each commodity through each edge
- **Combined results**: all results (capacity, costs, flows, non-served demand, storage level) in a single DataFrame

## Quick Start

To collect and save all results at once, users can use the [`collect_results`](@ref) and [`write_results`](@ref) functions:

```julia
# Collect all results in memory
results = collect_results(system, model)

# Or write directly to file
write_results("results.csv.gz", system, model)
```

!!! note "Output Format"
    Macro supports the following output formats:
    - **CSV**: comma-separated values
    - **CSV.GZ**: compressed CSV
    - **Parquet**: column-based data store

    The output format is determined by the file extension. For example, to write the results to a Parquet file instead of a CSV file, use the following line:

    ```julia
    write_results("results.parquet", system, model)
    ```


The function [`write_dataframe`](@ref) can be used to write a generic DataFrame to a file:

```julia
write_dataframe("results.csv", results) # Write the dataframe to a CSV file
write_dataframe("results.parquet", results) # Write the dataframe to a Parquet file
write_dataframe("results.csv", results, drop_cols=[:commodity, :commodity_subtype]) # Drop the commodity and commodity_subtype columns before writing to CSV
```

As can be seen in the example above, users have the option to drop columns from the DataFrame before writing the results to a file.

## Capacity Results

Results can be obtained either for the entire `system` or for specific `assets` using the [`get_optimal_capacity`](@ref), [`get_optimal_new_capacity`](@ref), and [`get_optimal_retired_capacity`](@ref) functions:

```julia
# System-level results
capacity_results = get_optimal_capacity(system)
new_capacity_results = get_optimal_new_capacity(system)
retired_capacity_results = get_optimal_retired_capacity(system)

# Asset-level results
capacity_results = get_optimal_capacity(asset)
new_capacity_results = get_optimal_new_capacity(asset)
retired_capacity_results = get_optimal_retired_capacity(asset)
```

To write system-level capacity results directly to a file, users can use the [`write_capacity`](@ref) function:

```julia
write_capacity("capacity.csv", system)
write_capacity("capacity.csv", system, drop_cols=[:commodity, :commodity_subtype, :zone])
```

By default, the results are written in wide format. Users can also write the results in long format by setting the `wide` argument to `false`:

```julia
write_capacity("capacity.csv", system, wide=false)
```

## Costs

System-wide cost results can be obtained as DataFrames using the [`get_optimal_costs`](@ref) function:

```julia
cost_results = get_optimal_costs(model)
```

To write the costs results directly to a file, users can use the [`write_costs`](@ref) function:

```julia
write_costs("costs.csv", model)
write_costs("costs.csv", model, drop_cols=[:commodity, :commodity_subtype, :zone])
```

## Flow Results

Flow results can be obtained either for the entire `system` or for specific `assets` using the [`get_optimal_flow`](@ref) function:

```julia
# System-level results
flow_results = get_optimal_flow(system)

# Asset-level results
flow_results = get_optimal_flow(asset)
```

To write system-level flow results directly to a file, users can use the [`write_flow`](@ref) function:

```julia
write_flow("flows.csv", system)
write_flow("flows.csv", system, drop_cols=[:commodity, :commodity_subtype, :zone])
```