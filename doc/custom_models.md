### Custom Models

You can easily create model that are bespoke to the particular . The only requirements features are:
```
step!(model::Model, t)
control!(model::Model, controller::Controller, t)
```
namely how to evolve it and how to actuate it.
