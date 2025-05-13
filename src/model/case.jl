struct Case
    periods::Vector{System}
    settings::Union{NamedTuple,Nothing}
end
solution_algorithm(case::Case) = solution_algorithm(case.settings[:SolutionAlgorithm])

function generate_case(
    path::AbstractString,
    periods_data::Dict{Symbol,Any},
)::Case

    case = periods_data[:case]
    num_periods = length(case)
    @info("Running system generation for $num_periods periods")
    
    start_time = time()
    periods::Vector{System} = map(1:num_periods) do period_idx
        system_data = case[period_idx]
        system_data[:time_data][:PeriodIndex] = period_idx
        period_system = empty_system(dirname(path))
        generate_system!(period_system, system_data)
        return period_system
    end

    settings = configure_case(periods_data[:settings], dirname(path))

    prepare_case!(periods, settings)

    @info("Done generating case. It took $(round(time() - start_time, digits=2)) seconds")
    return Case(periods, settings)
end


function prepare_case!(periods::Vector{System}, settings::NamedTuple)
    for (period_id, system) in enumerate(periods)
        compute_annualized_costs!(system) 
        if !isa(solution_algorithm(settings[:SolutionAlgorithm]), Myopic) && length(periods) > 1
            ### Note that myopic simulations do not use discount factors
            @info("Discounting fixed costs for period $(period_id)")
            discount_fixed_costs!(system, settings)
        end
        @info("Computing retirement case for period $(period_id)")
        compute_retirement_period!(system, settings[:PeriodLengths])
    end
end