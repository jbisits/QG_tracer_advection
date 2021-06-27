#=
    Diagnostics to measure mixing and functions for data extraction from a .jld2 file created by a tracer 
    advection diffusion simulation.
    The diagnostics are:
     - variance of concentration over the grid
     - evolution of the isopycnal second moment
    From the .jld2 file can create plots and extract relevant information.
=#
module MeasureMixing

export
    conc_mean,
    conc_var!,
    conc_var,
    Garrett_int,
    area_tracer_patch!,
    fit_normal!, 
    fit_hist!,
    hist_plot,
    concarea_plot,
    concarea_animate,
    tracer_plot,
    tracer_animate,
    time_vec

using Distributions, GeophysicalFlows, StatsBase, LinearAlgebra, JLD2, Plots
"""
    conc_mean(data::Dict{String, Any})
Calculate the mean at each timestep to see if it stays the same or if some concentration
leaves the simulation.
"""
function conc_mean(data::Dict{String, Any})

    nlayers = data["params/nlayers"]
    nsteps = data["clock/nsteps"]
    concentration_mean = Array{Float64}(undef, nsteps + 1, nlayers)
    for i ∈ 1:nsteps + 1
        concentration_mean[i, :] = [mean(data["snapshots/Concentration/"*string(i-1)][:, :, j]) for j ∈ 1:nlayers]
    end

    return concentration_mean
end
"""
    function conc_var!(concentration_variance, AD_prob)
Calculate the variance of the tracer concentration in each layer for advection-diffusion problem `prob` and store the
result at each timestep in the array concentration_variance. 
"""
function conc_var!(concentration_variance::Array, AD_prob::FourierFlows.Problem) 

    nlayers = AD_prob.params.nlayers
    step = AD_prob.clock.step + 1
    for i in 1:nlayers
        concentration_variance[step, i] = var(AD_prob.vars.c[:, :, i])
    end

end
"""
    function conc_var(data::Dict{String, Any})
Compute the same concentration variance from saved output for an advection-diffusion problem.
"""
function conc_var(data::Dict{String, Any})

    nlayers = data["params/nlayers"]
    nsteps = data["clock/nsteps"]
    concentration_variance = Array{Float64}(undef, nsteps + 1, nlayers)
    for i ∈ 1:nsteps + 1
        concentration_variance[i, :] = [var(data["snapshots/Concentration/"*string(i-1)][:, :, j]) for j ∈ 1:nlayers]
    end

    return concentration_variance
end
"""
    function Garrett_int(data::Dict{String, Any})
Compute the diagnostic for tracer concentration ∫C²dA at each timestep (Garrett 1983).
"""
function Garrett_int(data::Dict{String, Any})

    nlayers = data["params/nlayers"]
    nsteps = data["clock/nsteps"]
    conc_int = Array{Float64}(undef, nsteps + 1, nlayers)
    for i in 1:nsteps + 1
        conc_int[i, :] = [sum(data["snapshots/Concentration/"*string(i-1)][:, :, j].^2) for j ∈ 1:nlayers]
    end

    return conc_int
end
"""
    function fit_normal!(σ², AD_prob)
Fit a normal distribution to the concentration of tracer at each time step to look at how σ² changes.
"""
function fit_normal!(σ², AD_prob)

    nlayers = AD_prob.params.nlayers
    step = AD_prob.clock.step + 1
    for i in 1:nlayers
        conc_data = reshape(AD_prob.vars.c[:, :, i], :, 1) 
        fit_norm = fit_mle(Normal, conc_data)
        σ = params(fit_norm)[2]
        σ²[step, i] = σ^2
    end

end
"""
    function fit_hist!(filename, AD_prob, max_conc)
Fits a histogram to the concentration data at each time step. From the histogram the concentration data 
and area data can be extracted. This is for use in a simulation like in `QG_hist.jl`.
"""
function fit_hist!(filename, AD_prob; number_of_bins = 0)

    nlayers, C = AD_prob.params.nlayers, AD_prob.vars.c
    hist_layer = Array{Histogram}(undef, nlayers)
    conc_data = []

    for i in 1:nlayers
        if number_of_bins == 0
            temp_fit = fit(Histogram, reshape(C[:, :, i], :))
        else
            temp_fit = fit(Histogram, reshape(C[:, :, i], :), nbins = number_of_bins)
        end
        hist_layer[i] = normalize(temp_fit, mode = :probability)
        temp_conc_data = cumsum(reverse(hist_layer[i].weights))
        push!(conc_data, reverse!(vcat(0, temp_conc_data)))
    end
    jldopen(filename, "a+") do file
        file["Histograms/step"*string(AD_prob.clock.step)] = hist_layer
        file["ConcentrationData/step"*string(AD_prob.clock.step)] = conc_data
    end

end
"""
    function hist_plot(data)
Create plots of histograms at the same timesteps as the tracer plots from the saved data
in the output file. The input `data` is the loaded .jld2 file.
"""
function hist_plot(data::Dict{String, Any}; plot_freq = 1000)

    nlayers = data["params/nlayers"]
    nsteps = data["clock/nsteps"]
    plot_steps = 0:plot_freq:nsteps
    max_conc = [findmax(data["snapshots/Concentration/0"][:, :, i])[1] for i ∈ 1:nlayers]
    UpperConcentrationHistograms = Plots.Plot{Plots.GRBackend}[]
    LowerConcentrationHistograms = Plots.Plot{Plots.GRBackend}[]
    for i ∈ plot_steps
        upperdata = reshape(data["snapshots/Concentration/"*string(i)][:, :, 1], :)
        lowerdata = reshape(data["snapshots/Concentration/"*string(i)][:, :, 2], :)
        upperhist = fit(Histogram, upperdata)
        lowerhist = fit(Histogram, lowerdata)
        upperhist = normalize(upperhist, mode = :probability)
        lowerhist = normalize(lowerhist, mode = :probability)
        push!(UpperConcentrationHistograms, plot(upperhist,
                                                label = false, 
                                                xlabel = "Concentration", 
                                                ylabel = "Normalised area",
                                                xlims = (0, max_conc[1])
                                                )
            )
        push!(LowerConcentrationHistograms, plot(lowerhist,
                                                label = false, 
                                                xlabel = "Concentration", 
                                                ylabel = "Normalised area",
                                                xlims = (0, max_conc[2])
                                                )
            )
    end

    return [UpperConcentrationHistograms, LowerConcentrationHistograms]
end
"""
    function concarea_plot(data)
Create plots of Concetration ~ normalised area at the same time steps as the tracer plots from the 
saved data in the output file. The input `data` is the loaded .jld2 file.
"""
function concarea_plot(data::Dict{String, Any}; plot_freq = 1000)

    nlayers = data["params/nlayers"]
    nsteps = data["clock/nsteps"]
    plot_steps = 0:plot_freq:nsteps
    max_conc = [findmax(data["snapshots/Concentration/0"][:, :, i])[1] for i ∈ 1:nlayers]
    UpperConcentrationArea = Plots.Plot{Plots.GRBackend}[]
    LowerConcentrationArea = Plots.Plot{Plots.GRBackend}[]
    for i ∈ plot_steps
        upperdata = reshape(data["snapshots/Concentration/"*string(i)][:, :, 1], :)
        lowerdata = reshape(data["snapshots/Concentration/"*string(i)][:, :, 2], :)
        upperhist = fit(Histogram, upperdata)
        lowerhist = fit(Histogram, lowerdata)
        normalize!(upperhist, mode = :probability)
        normalize!(lowerhist, mode = :probability)
        upperconcdata = reverse(vcat(0, cumsum(reverse(upperhist.weights))))
        lowerconcdata = reverse(vcat(0, cumsum(reverse(lowerhist.weights))))
        push!(UpperConcentrationArea, plot(upperconcdata, upperhist.edges,
                                            label = false,
                                            xlabel = "Normalised area",
                                            ylabel = "Concentration",
                                            xlims = (0, max_conc[1])
                                            )
                )
        push!(LowerConcentrationArea, plot(lowerconcdata, lowerhist.edges,
                                            label = false,
                                            xlabel = "Normalised area",
                                            ylabel = "Concentration",
                                            xlims = (0, max_conc[2])
                                            )
            )
    end
    return [UpperConcentrationArea, LowerConcentrationArea]
end
"""
    function concarea_animate(data)
Create an animation of Concetration ~ normalised area from the saved data in the output file.
"""
function concarea_animate(data::Dict{String, Any}; plot_freq = 10)

    nlayers = data["params/nlayers"]
    nsteps = data["clock/nsteps"]
    max_conc = [findmax(data["snapshots/Concentration/0"][:, :, i])[1] for i ∈ 1:nlayers]
    ConcVsArea = @animate for i in 0:plot_freq:nsteps
        upperdata = reshape(data["snapshots/Concentration/"*string(i)][:, :, 1], :)
        lowerdata = reshape(data["snapshots/Concentration/"*string(i)][:, :, 2], :)
        upperhist = histogram(upperdata)
        lowerhist = histogram(lowerdata)
        normalize!(upperhist, mode = :probability)
        normalize!(lowerhist, mode = :probability)
        upperconcdata = reverse(vcat(0, cumsum(reverse(upperhist.weights))))
        lowerconcdata = reverse(vcat(0, cumsum(reverse(lowerhist.weights))))
        p1 = plot(upperconcdata , upperhist.edges,
                 label = false,
                xlabel = "Normalised area",
                ylabel = "Concentration",
                 ylims = (0, max_conc[1]),
                 title = "Top layer"
                )
        p2 = plot(lowerconcdata, lowerhist.edges,
                 label = false,
                xlabel = "Normalised area",
                ylabel = "Concentration",
                 ylims = (0, max_conc[2]),
                 title = "Bottom layer"
                )
    plot(p1, p2)
    end

    return ConcVsArea
end
"""
    function tracer_plot(data)
Plot a heatmap of the concentration field at specified time steps from a tracer advection
diffusion simulation. The input is a loaded .jld2 output file.
"""
function tracer_plot(data::Dict{String, Any}; plot_freq = 1000)

    nsteps = data["clock/nsteps"]
    Lx, Ly = data["grid/Lx"], data["grid/Ly"]
    if Lx >= 500e3
        #This just makes the domain a little easier to read if a really large domain is being used
        set_xticks = (-Lx/2:round(Int, Lx/6):Lx/2, string.(-Int(Lx/2e3):round(Int, Lx/6e3):Int(Lx/2e3)))
        set_yticks = (-Ly/2:round(Int, Ly/6):Ly/2, string.(-Int(Ly/2e3):round(Int, Ly/6e3):Int(Ly/2e3)))
        plotargs = (
                    aspectratio = 1,
                    color = :deep,
                    xlabel = "x",
                    ylabel = "y",
                    colorbar = true,
                    xlims = (-Lx/2, Lx/2),
                    ylims = (-Ly/2, Ly/2),
                    xticks = set_xticks,
                    yticks = set_yticks
                    )  
    else
        plotargs = (
                    aspectratio = 1,
                    color = :deep,
                    xlabel = "x",
                    ylabel = "y",
                    colorbar = true,
                    xlims = (-Lx/2, Lx/2),
                    ylims = (-Ly/2, Ly/2)
                    ) 
    end
    
    plot_steps = 0:plot_freq:nsteps
    x, y = data["grid/x"], data["grid/y"]
    UpperTracerPlots = Plots.Plot{Plots.GRBackend}[]
    LowerTracerPlots = Plots.Plot{Plots.GRBackend}[]
    for i ∈ plot_steps
        uppertracer = heatmap(x, y, data["snapshots/Concentration/"*string(i)][:, :, 1]',
                                title = "C(x,y,t) step = "*string(i); 
                                plotargs...
                            )
        push!(UpperTracerPlots, uppertracer)
        lowertracer = heatmap(x, y, data["snapshots/Concentration/"*string(i)][:, :, 2]',
                                title = "C(x,y,t) step = "*string(i); 
                                plotargs...
                            )
        push!(LowerTracerPlots, lowertracer)
    end

    return [UpperTracerPlots, LowerTracerPlots]                   
end
"""
    function tracer_animate(data)
Turn the saved concentration data into an animation.
"""
function tracer_animate(data::Dict{String, Any}; plot_freq = 10)

    nsteps = data["clock/nsteps"]
    Lx, Ly = data["grid/Lx"], data["grid/Ly"]
    x, y = data["grid/x"], data["grid/y"]
    if Lx >= 500e3
        #This just makes the domain a little easier to read if a really large domain is being used
        set_xticks = (-Lx/2:round(Int, Lx/6):Lx/2, string.(-Int(Lx/2e3):round(Int, Lx/6e3):Int(Lx/2e3)))
        set_yticks = (-Ly/2:round(Int, Ly/6):Ly/2, string.(-Int(Ly/2e3):round(Int, Ly/6e3):Int(Ly/2e3)))
        plotargs = (
                    aspectratio = 1,
                    color = :deep,
                    xlabel = "x",
                    ylabel = "y",
                    colorbar = true,
                    xlims = (-Lx/2, Lx/2),
                    ylims = (-Ly/2, Ly/2),
                    xticks = set_xticks,
                    yticks = set_yticks
                    )  
    else
        plotargs = (
                    aspectratio = 1,
                    color = :deep,
                    xlabel = "x",
                    ylabel = "y",
                    colorbar = true,
                    xlims = (-Lx/2, Lx/2),
                    ylims = (-Ly/2, Ly/2)
                    ) 
    end

    TracerAnimation = @animate for i ∈ 0:plot_freq:nsteps
        uppertracer = heatmap(x, y, data["snapshots/Concentration/"*string(i)][:, :, 1]',
                                title = "C(x,y,t) step = "*string(i); 
                                plotargs...
                            )
        lowertracer = heatmap(x, y, data["snapshots/Concentration/"*string(i)][:, :, 2]',
                                title = "C(x,y,t) step = "*string(i); 
                                plotargs...
                            )   

        plot(uppertracer, lowertracer)
    end

    return TracerAnimation
end
"""
    function time_vec(data::Dict{String, Any})
Create a time vector for plotting from the saved .jld2 output. The save_freq argument
ensures the vector is the correct length by passing how frequently data is saved during
the simulation.
"""
function  time_vec(data::Dict{String, Any}; save_freq = 1)

    Δt = data["clock/dt"] * save_freq
    maxtime = Δt*data["clock/nsteps"]
    t = 0:Δt:maxtime

    return t
end

end #module
