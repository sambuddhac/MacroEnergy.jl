function default_settings()
    (
        Commodities = "",
        PeriodLength = 24,
        NetworkExpansion = 0,
        MultiStage = 0,
    )
end

namedtuple(d::Dict) = (; (Symbol(k) => v for (k, v) in d)...)
function configure_settings(settings_path::String)
    model_settings = namedtuple(YAML.load_file(settings_path))

    validate_names(model_settings)
    settings = default_settings()

    settings = merge(settings, model_settings)

    validate_settings(settings)
    return settings
end

function validate_settings(settings::NamedTuple)
    nothing
    # # Check that input/output paths are valid
    # @assert isa(settings[:InputDataPath], String) && isdir(settings[:InputDataPath])
    # @assert isa(settings[:OutputDataPath], String)
    # @assert settings[:PrintModel] ∈ (0, 1)
    # @assert settings[:NetworkExpansion] ∈ (0, 1)
    # @assert settings[:TimeDomainReduction] ∈ (0, 1)
    # @assert isa(settings[:TimeDomainReductionFolder], String)
    # @assert settings[:MultiStage] ∈ (0, 1)
end

function validate_names(settings::NamedTuple)
    # Check that all the names in the settings file are valid
    valid_names = keys(default_settings())
    unknown_names = setdiff(keys(settings), valid_names)
    if !isempty(unknown_names)
        error("Unknown settings: $(unknown_names)")
    end
end
