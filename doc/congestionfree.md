# Congestion-Free Model

## Description

```
mutable struct PowerSystem
    units::Vector{Unit}
    demand::Extrapolation
    reserve::Float64
    generation::Float64
    load_shedding::Float64
end
```
