cd(joinpath(SimPath, "Output/Simulation: Lx̂ = 32, Lŷ = 64, save_freq = 50, IC = GaussianBlob, Ensemble = false"))
file = joinpath(pwd(), "SimulationData.jld2")

#Load in the data
data = load(file)

t = time_vec(data)
first_mom = first_moment(data)

plot(t, first_mom, label = false)