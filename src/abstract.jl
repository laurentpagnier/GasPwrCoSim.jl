abstract type PowerSystem end 
abstract type GasSystem end 
abstract type Controller end 
abstract type Logger end 
abstract type Daemon end 

display(model::PowerSystem) = nothing
display(model::GasSystem) = nothing
