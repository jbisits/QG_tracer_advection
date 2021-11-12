cd(joinpath(SimPath, "Output/Simulation: Lx̂ = Lŷ = 128, nx = 256, save_freq = 50, IC = GaussianStrip, Ensemble = true"))

## New flow params for delay_time = Δt * 6000, 
# first 10 seed 1234, 10-20 seed 4321, 20-30 seed 2341, 30-40 seed 3142, 40-50 seed 3241
data = Array{Dict{String, Any}}(undef, 50)
for i ∈ 1:length(data)
    if i == 1
        file = joinpath(pwd(), "SimulationData.jld2")
        data[i] = load(file)
    else
        file = joinpath(pwd(), "SimulationData_"*string(i - 1)*".jld2")
        data[i] = load(file)
    end
end
##
t = time_vec(data[1])
sec_mom = second_moment(data)

upperplot = plot(t, sec_mom[:, 1, 1],
                title = "Upper layer second moment of area growth \n for Gaussian band initial condition",
                xlabel = "t",
                ylabel = "σ²ₐ",
                label = "Ensemble member",
                legend = :bottomright)
lowerplot = plot(t, sec_mom[:, 2, 1],
                title = "Lower layer second moment of area growth \n for Gaussian band initial condition",
                xlabel = "t",
                ylabel = "σ²ₐ",
                label = "Ensemble member",
                legend = :bottomright)
for i ∈ 2:length(data)
    plot!(upperplot, t, sec_mom[:, 1, i], label = false) 
    plot!(lowerplot, t, sec_mom[:, 2, i], label = false) 
end

ens_conc = ensemble_concentration(data)
ens_sec_mom = second_moment(ens_conc)

plot!(upperplot, t, ens_sec_mom[:, 1], label = "Ensemble", line = (:dash, :black, 2))
plot!(lowerplot, t, ens_sec_mom[:, 2], label = "Ensemble", line = (:dash, :black, 2))

fullplot = plot(upperplot, lowerplot, layout = (2, 1), size = (800, 800))
#savefig(fullplot, "Gaussianband_128dom_td6000.png")

## Diffusivity
ΔA² = ens_sec_mom[61, :] - ens_sec_mom[21, :]
Δt = t[61] - t[21]
Lₓ = data[1]["grid/Lx"]
K = ΔA² / (Lₓ^2 * 8 * Δt)

nondim2dim(data[1])
## Linear best fit
ens_fit = [ones(length(t)) t] \ ens_sec_mom

upperlinfit = plot(t, ens_fit[1, 1] .+ ens_fit[2, 1] .* t, 
                    title = "Upper layer linear best fit of the growth of \n the ensemble second moment of area",
                    label = "Best fit of ensemble data", 
                    xlabel = "t",
                    ylabel = "σ²ₐ",
                    legend = :bottomright, 
                    line = (:dash))
plot!(upperlinfit, t, ens_sec_mom[:, 1], 
    label = "Ensemble data")
#savefig(upperlinfit, "upperlinfitband.png")

lowerlinfit = plot(t, fit[1, 2] .+ fit[2, 2] .* t, 
                    title = "Lower layer linear best fit of the growth of \n the ensemble second moment of area",
                    label = "Best fit of ensemble data", 
                    xlabel = "t",
                    ylabel = "σ²ₐ",
                    legend = :bottomright, 
                    line = (:dash))
plot!(lowerlinfit, t, ens_sec_mom[:, 2], 
    label = "Ensemble data")
#savefig(lowerlinfit, "lowerlinfitband.png")

Lₓ = data[1]["grid/Lx"]
K_linfit = ens_fit[2, :] ./ (Lₓ^2 * 8)

dims = nondim2dim(data[1])
K_linfit_dim = @. K_linfit * dims["Ld"] * 0.02
## Plots of the tracer
tracer_plots = tracer_plot(data[1]; plot_freq = 500)
upperlayerband = plot(tracer_plots[:, 1]..., size = (1400, 1400))
savefig(upperlayerband, "upperlayerbandtracer.png")
lowerlayerband = plot(tracer_plots[:, 2]..., size = (1400, 1400))
savefig(lowerlayerband, "lowerlayerbandtracer.png")
upperlayerbandIC = plot(tracer_plots[1, 1], size = (800, 400))
#savefig(upperlayerbandIC, "upperlayerbandIC.png")

## Plots of ensemble Concentration
ens_plots = tracer_plot(ens_conc; plot_freq = 500)
upperbandense = plot(ens_plots[:, 1]..., size = (1400, 1400))
savefig(upperbandense,"upperbandense.png")
lowerbandense = plot(ens_plots[:, 2]..., size = (1400, 1400))
savefig(lowerbandense,"lowerbandense.png")

## Difusivity of each ensemble member 

j = 10
upperplot = plot(t, sec_mom[:, 1, j],
                title = "Upper layer second moment of area growth \n for Gaussian band initial condition",
                xlabel = "t",
                ylabel = "σ²ₐ",
                label = "Ensemble member",
                legend = :bottomright)
lowerplot = plot(t, sec_mom[:, 2, j],
                title = "Lower layer second moment of area growth \n for Gaussian band initial condition",
                xlabel = "t",
                ylabel = "σ²ₐ",
                label = "Ensemble member",
                legend = :bottomright)

#Looks like for upper layer after time = 5 in upper layer linear, lower layer after time = 10.
#Might be easiest to take t = 10 to end as that way only need one calculation.

Δt_mem = t[end] - t[round(Int64, 3*end / 4)]
ΔA_mem = sec_mom[end, :, :] - sec_mom[round(Int64, 3*end / 4), :, :]

K_ens = ΔA_mem ./ (Lₓ^2 * 8 * Δt_mem)

K_ens_dim = @. K_ens * dims["Ld"] * 0.02

upper_diff_hist_band = fit(Histogram, K_ens_dim[1, :])
upper_diff_hist_band_plot = plot(upper_diff_hist_band ,
                                xlabel = "Diffusivity m²s⁻¹ ", 
                                ylabel = "Number of members",
                                title = "Histogram of ensemble members \n binned by diffusivity (upper layer)", 
                                label = false, 
                                legend = :topright)
scatter!(upper_diff_hist_band_plot, [K_linfit_dim[1]], [0], label = "Ensemble average\n diffusivity")
scatter!(upper_diff_hist_band_plot, [findmin(K_ens_dim[1, :])[1]], [0], label = "Member with \n minimum diffisivity")
scatter!(upper_diff_hist_band_plot, [findmax(K_ens_dim[1, :])[1]], [0], label = "Member with \n maximum diffisivity")
savefig(upper_diff_hist_band_plot, "upper_diff_hist_band.png")

mean(K_ens_dim[1, :])
std(K_ens_dim[1, :])

lower_diff_hist_band =  fit(Histogram, K_ens_dim[2, :])
lower_diff_hist_band_plot = plot(lower_diff_hist_band,
                                xlabel = "Diffusivity m²s⁻¹ ", 
                                ylabel = "Number of members",
                                title = "Histogram of ensemble members \n binned by diffusivity (upper layer)",
                                label = false, 
                                legend = :topright)
scatter!(lower_diff_hist_band_plot, [K_linfit_dim[2]], [0], label = "Ensemble average\n diffusivity")
scatter!(lower_diff_hist_band_plot, [findmin(K_ens_dim[2, :])[1]], [0], label = "Member with \n minimum diffisivity")
scatter!(lower_diff_hist_band_plot, [findmax(K_ens_dim[2, :])[1]], [0], label = "Member with \n maximum diffisivity")
savefig(lower_diff_hist_band_plot, "lower_diff_hist_band.png")

mean(K_ens_dim[2, :])
std(K_ens_dim[2, :])

## Or could fit Gaussian's and plot where the ensembel average diffusivity is
#Upper layer
upperlayer_normfit = fit(Normal, K_ens_dim[1, :])
upper_vals = minimum(K_ens_dim[1, :]):maximum(K_ens_dim[1, :])
upperlayer_normpdf = [pdf(upperlayer_normfit, x) for x ∈ upper_vals]

plot(upper_vals, upperlayer_normpdf, label = "Fitted normal to \nupper layer diffusivity\nestiamtes", legend = :topright)
scatter!([K_linfit_dim[1]], [0], label = "Ensemble average\ndiffusivity")
scatter!([upperlayer_normfit.μ], [0], label = "Mean of diffusivity\nestimates")

#Lower layer
lowerlayer_normfit = fit(Normal, K_ens_dim[2, :])
lower_vals = minimum(K_ens_dim[2, :]):maximum(K_ens_dim[2, :])
lowerlayer_normpdf = [pdf(lowerlayer_normfit, x) for x ∈ lower_vals]

plot(lower_vals, lowerlayer_normpdf, label = "Fitted normal to \nlower layer diffusivity\nestiamtes", legend = :topright)
scatter!([K_linfit_dim[2]], [0], label = "Ensemble average\ndiffusivity")
scatter!([lowerlayer_normfit.μ], [0], label = "Mean of diffusivity\nestimates")

## Bootstrap the ensemble members to form error for ensemble average
using StatsBase

N = 1000 
sample = 30
sample_vec = Array{Int64}(undef, sample)
sample_vals = 1:length(data)
ens_diff = Array{Float64}(undef, N, 2)
#=
for n ∈ 1:N

    sample_vec = StatsBase.sample(sample_vals, sample, replace = false)
    data_sample = data[sample_vec]
    ens_conc_sample = ensemble_concentration(data_sample)
    ens_sec_mom_sample = second_moment(ens_conc_sample)
    ens_fit_sample = [ones(length(t)) t] \ ens_sec_mom_sample
    ens_diff[n, :] =  ens_fit_sample[2, :]   

end=# 

Lₓ = data[1]["grid/Lx"]
ens_diff_dim =  ens_diff ./ (Lₓ^2 * 8)   
ens_diff_dim = @. ens_diff_dim * dims["Ld"] * 0.02
histogram(ens_diff_dim[:, 1])
std(ens_diff_dim[:, 1])
histogram(ens_diff_dim[:, 2])
std(ens_diff_dim[:, 2])

#This is a big thing to run so have saved to .jld2
file = "bootstrap_band.jld2"
jldopen(file, "a+") do path
    path["bootstap"] = ens_diff_dim
end

## Count number of members
bootsrap = load("bootstrap_band.jld2")
ens_diff_dim = bootsrap["bootstap"]

σ_ensemble = std(ens_diff_dim, dims = 1)

err_val = σ_ensemble .* [1:10 1:10]
no_of_mems = similar(err_val)

for i in 1:length(err_val[:, 1])

    for j in 1:2
        lower_bound, upper_bound = K_linfit_dim[j] - err_val[i, j], K_linfit_dim[j] + err_val[i, j]
        no_of_mems[i, j] = length(findall(lower_bound .<=  K_ens_dim[j, :] .<= upper_bound))
    end
end

no_of_mems 