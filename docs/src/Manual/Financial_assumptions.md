# Investment costs

The investment cost is incurred as an annual payments (also referred to as an annuity) expressed in $/MW-yr. The annuity represents a payment made by a developer to debt and equity investors.

# Cost of capital

- \textbf{Cost of capital}: The cost of capital can be technology-specific. 
- The user can provide technology-specific assumptions for the Weighted Average Cost if Capital, denoted $WACC_y$ for technology $y$.
- The $WACC_y$ input is meant to represent the *real* weighted average cost of capital. The WACC can be used to represent market-based costs of capital (typically based on a combination of debt and equity financing).
- The choice of $WACC_y$ is up to the user and supplying the same cost of capital across technologies is also possible 

# Annualized investment cost 

Macro calculates the annualized investment cost internally using the following expressions.

$\textbf{Capital recovery factor}_y = \frac{WACC_y}{1-(1+\text{WACC}_y)^{-EL_y}}$
    
$\textbf{Annualized investment cost}_y = \text{CRF}_y \text{CAPEX}_{y,z}$

# Single-period modeling

The investment cost used in the objective function is based on the annuity paid in the modeled year.

# Multi-period modeling

**End of horizon effects** are treated such that annuities are paid in every year from the time of investment until the end of the technology's economic lifetime, or the remainder of the modeling horizon, whichever comes first. Thus the model does not include salvage values at the end of the modeling horizon. As this implies that the model ignores a technology's value after the modeling horizon, the model also ignores costs incurred after the modeling horizon. 
    
Each annuity is discounted using the general discount rate, which represents the time value of money from the system planner's perspective. Thus, Technologies with the same CAPEX but different costs of capital (i.e., $\text{WACC}_y$) will be treated differently by the model.
    