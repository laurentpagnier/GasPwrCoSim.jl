
### Controllers
If no controller is defined the default control is *do nothing*. If a controller has no specific rules of a model type it will *do nothing*. The abstract control reads
```
function control!(pwr_sys::PowerSystem, gas_sys::GasSystem, controller::Union{Controller,Nothing}, t)
    control!(pwr_sys, controller, model.t)
    control!(gas_sys, controller, model.t)
    nothing
end
```
and it therefore assumed that the two systems can be actuated separately. Interactions must be stored locally during ``step!``.



