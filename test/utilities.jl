using Gurobi, Logging


macro log_with_level(log_level, block)
    quote
        result = redirect_stdout(devnull) do
            # Create a ConsoleLogger that prints any log messages with the specified log level to stderr
            logger = ConsoleLogger(stderr, $(esc(log_level)))
            with_logger(logger) do
                result = $(esc(block))
            end
        end
        result
    end
end

# Backward compatibility for previous version
macro warn_error_logger(block)
    quote
        @log_with_level($(esc(Logging.Warn)), $(esc(block)))
    end
end

macro error_logger(block)
    quote
        @log_with_level($(esc(Logging.Error)), $(esc(block)))
    end
end

function is_gurobi_available()
    try
        @warn_error_logger Gurobi.Env()
        return true
    catch e
        if isa(e, ErrorException) && occursin("Gurobi Error", string(e))
            return false
        else
            rethrow()
        end
    end
end

function check_if_package_installed(optimizer_name::AbstractString)
    return Base.find_package(optimizer_name) !== nothing
end

