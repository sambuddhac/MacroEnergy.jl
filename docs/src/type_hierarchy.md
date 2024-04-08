# Macro type hierarchy

```@meta
CurrentModule = Macro
using Macro
using AbstractTrees
AbstractTrees.children(d::DataType) = subtypes(d)
```

```@example

