module TestLoadMethods

using Macro
using Test


inputfolder_path = "test_inputs"
inputfiles = InputFilesNames()

function test_load_resurces()
    resources = load_resources(inputfolder_path, inputfiles)
    return nothing
end

function test_load_variability()
    df_variability = load_dataframe(joinpath(inputfolder_path, inputfiles.variability))
    resources = load_resources(inputfolder_path, inputfiles)
    resources = load_variability!(inputfolder_path, inputfiles, resources)
    for resource in resources
        @test resource.capacity_factor == df_variability[!, Macro.resource_id(resource)]
    end
    return nothing
end


test_load_resurces()
test_load_variability()

end # module TestLoadMethods
