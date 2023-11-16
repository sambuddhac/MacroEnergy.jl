# Flexible framework prototype 1

With this prototype, we'll explore how we can set up a structure that allows the user to easily swap out:

* Resource definitions
* Policy definitions
* Network / sector structures

The core of the prototype loops over each resource and policy, gradually adding them to the model.

For now, we'll keep the model outputs in the model, not the various resources, to keep the structs simpler and avoid duplication.

We also have to investigate model performance when 

