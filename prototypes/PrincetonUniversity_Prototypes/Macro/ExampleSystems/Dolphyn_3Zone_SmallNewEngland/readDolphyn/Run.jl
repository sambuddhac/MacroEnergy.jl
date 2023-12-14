using Dolphyn

settings_path = joinpath(@__DIR__, "Settings")

inputs_path = @__DIR__

setup = load_settings(settings_path)

global_logger = setup_logging(setup)

OPTIMIZER = configure_solver(setup["Solver"], settings_path)

inputs = load_inputs(setup, inputs_path)

# ### Load H2 inputs if modeling the hydrogen supply chain
if setup["ModelH2"] == 1
    inputs = load_h2_inputs(inputs, setup, inputs_path)
end

const H2_MWh = 33.33 # MWh per tonne of H2
const NG_MWh = 0.29307107 # MWh per MMBTU of NG

dfGen = inputs["dfGen"]
dfH2Gen = inputs["dfH2Gen"]
dfH2G2P = inputs["dfH2G2P"]

electrolyzer_st_coeff_E = 1;
electrolyzer_st_coeff_H2 = dfH2Gen[1, :etaP2G_MWh_p_tonne] / H2_MWh;

fuelcell_st_coeff_E = 1;
fuelcell_st_coeff_H2 = dfH2G2P[2, :etaG2P_MWh_p_tonne] / H2_MWh;

#dfGen[!,:Heat_Rate_MMBTU_per_MWh]

#EP = generate_model(setup, inputs, OPTIMIZER)

using Macro

macro_settings = Macro.configure_settings(joinpath(settings_path, "macro_settings.yml"))

macro_inputs = dolphyn_to_macro(inputs, macro_settings)
