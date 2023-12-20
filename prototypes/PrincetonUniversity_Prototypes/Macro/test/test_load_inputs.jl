module TestLoadMethods

using Macro
using Test
import JLD2


include("test_networks.jl")
include("test_resources.jl")
using .TestResource
include("test_storage.jl")
include("test_transformations.jl")

function test_load_inputs()

    test_path = "test_inputs"
    input_data_true = joinpath(test_path, "inputs_true.jld2")

    # read settings parameters
    macro_settings = configure_settings(joinpath(test_path, "macro_settings.yml"))
    # read inputs
    inputs = load_inputs(macro_settings, test_path)

    # load inputs_true
    JLD2.@load input_data_true inputs_true

    # Test that the inputs are the same as the true inputs
    @test settings(inputs) == settings(inputs_true)
    @testset "Test nodes" test_compare_nodes(nodes(inputs), nodes(inputs_true))
    @testset "Test networks" test_compare_networks(networks(inputs), networks(inputs_true))
    @testset "Test resources" TestResource.test_compare_resources(
        resources(inputs),
        resources(inputs_true),
    )
    @testset "Test storages" test_compare_storage(storage(inputs), storage(inputs_true))
    @testset "Test transformations" test_compare_transformations(
        transformations(inputs),
        transformations(inputs_true),
    )
end

test_load_inputs()

end # module TestLoadMethods
