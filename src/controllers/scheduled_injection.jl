struct ScheduledGasInjection <: Controller
    gas_injections::Dict{Int,Extrapolation}
end


function ScheduledGasInjection(;
        gas_folder = "../data/gas_data",
    )  
    df = DataFrame(CSV.File(joinpath(gas_folder, "gas_injections.csv")))
    gas_injection = Dict{Int, Extrapolation}()
    for l in setdiff(names(df),["time"])
        push!(gas_injection, parse(Int,l) => LinearInterpolation(df.time, df[:,l]))
    end 
    ScheduledGasInjection(gas_injection)
end

#DOTO: add functions actuating different types of gas systems
