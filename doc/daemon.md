
# Daemon

## Description

In computing, a daemon is a program that runs as a background process, rather than being under the direct control of an interactive user. Here is play the role of the interference.
As their name suggests they are not fool-proof and they may break down the simulation or give unphysical results if they make senseless modifications to the models. Users are assumed to know what attack/disturbance/incident makes sense. Fool-proofing the code would required to add handling functions to allow the daemon to interact with the models in a limited and controlled way, which comes with the drawback that it make them less versatile and more cumbersome to use.

To prevent the daemon from breaking the model it will copy what it will change in the model to restore it at the end of  the simulation (The user must provide that piece of code if they define new daemons.)
  
```
function copy!(daemon::Daemon, sys::System)
function restore!(daemon::Daemon, sys::System)
```
Let's exemplify this

```
mutable struct FixedDurationGasFault <: Daemon
    duration::Float64
    timer::Float64
    stored_values::Dict{String,Any}
end

function copy!(daemon::FixedDurationGasFault, gas_sys::LinepackModel)
	daemon.stored_values["max_injection"] = gas_sys.max_injection
end

function restore!(daemon::FixedDurationGasFault, sys::System)
	gas_sys.max_injection = daemon.stored_values["max_injection"]
end
```
During the incident the daemon will (not shown here) change the ``gas_sys.max_injection`` to a lower value, probably 0. If nothing is done this would persist and the next simulation would start without gas injection. By default to prevent from runtime errors, ``copy!`` and ``restore!`` do nothing if there not explicitly defined. Be aware that if the stored values are complex structures: vector, dictionaries, etc. the must be explicitly copied woth ``copy`` or ``deepcopy``. If not, them will be copied by reference and stored values will also be changed, ruining the copy & restore scheme. 





