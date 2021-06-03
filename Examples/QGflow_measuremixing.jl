#Test MeasureMixing.jl using a the QGflow_example.jl

using .TracerAdvDiff_QG
using .MeasureMixing

using GeophysicalFlows.MultiLayerQG, Plots, Distributions

#Set up the MultiLayerQG.Problem to test with the modified module.

#Choose CPU or GPU
dev = CPU()

#Numerical and time-stepping parameters
nx = 64        # 2D resolution = nx^2
ny = nx

stepper = "FilteredRK4";  # timestepper
Δt = 0.01                 # timestep
nsubs  = 1                # number of time-steps for plotting (nsteps must be multiple of nsubs)
nsteps = 3000nsubs        # total number of time-steps


#Physical parameters for a two layer QG_problem
Lx = 2π        # domain size
μ = 5e-2       # bottom drag
β = 5          # the y-gradient of planetary PV

nlayers = 2     # number of layers
f0, g = 1, 1    # Coriolis parameter and gravitational constant
H = [0.2, 0.8]  # the rest depths of each layer
ρ = [4.0, 5.0]  # the density of each layer

U = zeros(nlayers) # the imposed mean zonal flow in each layer
U[1] = 1.0
U[2] = 0.0

#Setup QG_problem and make easier to access the parts of the struct
QG_prob = MultiLayerQG.Problem(nlayers, dev; nx=nx, Lx=Lx, f₀=f0, g=g, H=H, ρ=ρ, U=U, dt=Δt, stepper=stepper, μ=μ, β=β)

sol_QG, cl_QG, pr_QG, vs_QG = QG_prob.sol, QG_prob.clock, QG_prob.params, QG_prob.vars
x_QG, y_QG = QG_prob.grid.x, QG_prob.grid.y

#Set initial conditions.
ϵ = 0.3
x, y = gridpoints(QG_prob.grid)

q_1_i = @.  ϵ * cos(4π / Lx * x_QG) * exp(-(x^2 + y^2) / 8)
q_2_i = @. -ϵ * cos(4π / Lx * x_QG) * exp(-(x^2 + y^2) / 8)

q_i = zeros(nx,ny,2)

q_i[:, :, 1] = q_1_i
q_i[:, :, 2] = q_2_i
qh_i = QG_prob.timestepper.filter .* rfft(q_i, (1, 2))         # only apply rfft in dims=1, 2
q_i  = irfft(qh_i, QG_prob.grid.nx, (1, 2))                    # only apply irfft in dims=1, 2

MultiLayerQG.set_q!(QG_prob, q_i)

#Set diffusivity
κ = 0.01
#Set delay time (that is flow for t seconds, then drop tracer in)
delay_time = 0
#Set the tracer advection probelm by passing in the QG problem 
AD_prob = TracerAdvDiff_QG.Problem(;prob = QG_prob, delay_time = delay_time, nsubs = nsubs, κ = κ)
sol_AD, cl_AD, v_AD, p_AD, g_AD = AD_prob.sol, AD_prob.clock, AD_prob.vars, AD_prob.params, AD_prob.grid
x_AD, y_AD = gridpoints(g_AD)
x, y = g_AD.x, g_AD.y
#Set the (same) initial condition in both layers.

#A Gaussian blob centred at μIC 

μIC = [0, 0]
Σ = [1 0; 0 1]
blob = MvNormal(μIC, Σ)
blob_IC(x, y) = pdf(blob, [x, y])
C₀ = @. blob_IC(x_AD, y_AD)


#A Gaussian strip around centred at μIC.
#=
μIC = 0
σ² = 0.5
strip = Normal(μIC, σ²)
strip_IC(x) = pdf(strip, x)
C₀ = Array{Float64}(undef, g_AD.nx, g_AD.ny)
for i in 1:g_AD.nx
    C₀[i, :] = strip_IC(y_AD[i, :])
end
=#
#If using strip_IC use C₀' for a vertical strip
TracerAdvDiff_QG.QGset_c!(AD_prob, C₀)

## Choose which diagnostic to use

#Variance of concentration over the grid
#Define array to store values for the variance of tracer concentration.
#=
concentration_variance = Array{Float64}(undef, nsteps + 2, nlayers)
MeasureMixing.conc_var!(concentration_variance, AD_prob)
=#

#Second moment of area of tracer patch
#=
second_moment_con = Array{Float64}(undef, nsteps + 2, nlayers)
MeasureMixing.area_tracer_patch!(second_moment_con, AD_prob, QG_prob, κ)
=#

#Variance from a normal distribution fit at each time step
#=
σ² = Array{Float64}(undef, nsteps + 2, nlayers)
MeasureMixing.fit_normal!(σ², AD_prob)
=#

#Define blank arrays in which to store the plots of tracer diffusion in each layer.
lower_layer_tracer_plots_AD = Plots.Plot{Plots.GRBackend}[]
upper_layer_tracer_plots_AD = Plots.Plot{Plots.GRBackend}[]
#Define frequency at which to save a plot.
#plot_time_AD is when to get the first plot, plot_time_inc is at what interval subsequent plots are created.
#Setting them the same gives plots at equal time increments.
plot_time_AD, plot_time_inc = 0.2, 0.2
#Step the tracer advection problem forward and plot at the desired time step.
while cl_AD.step <= nsteps
    if cl_AD.step == 0
        tp_u = heatmap(x, y, v_AD.c[:, :, 1]',
                    aspectratio = 1,
                    c = :balance,
                    xlabel = "x",
                    ylabel = "y",
                    colorbar = true,
                    xlim = (-g_AD.Lx/2, g_AD.Lx/2),
                    ylim = (-g_AD.Ly/2, g_AD.Ly/2),
                    title = "C(x,y,t), t = "*string(round(cl_AD.t; digits = 2)));
        push!(upper_layer_tracer_plots_AD, tp_u)
        tp_l = heatmap(x, y, v_AD.c[:, :, 2]',
                    aspectratio = 1,
                    c = :balance,
                    xlabel = "x",
                    ylabel = "y",
                    colorbar = true,
                    xlim = (-g_AD.Lx/2, g_AD.Lx/2),
                    ylim = (-g_AD.Ly/2, g_AD.Ly/2),
                    title = "C(x,y,t), t = "*string(round(cl_AD.t; digits = 2)))
        push!(lower_layer_tracer_plots_AD, tp_l)
    elseif round(Int64, cl_AD.step) == round(Int64, plot_time_AD*nsteps)
        tp_u = heatmap(x, y, v_AD.c[:, :, 1]',
                    aspectratio = 1,
                    c = :balance,
                    xlabel = "x",
                    ylabel = "y",
                    colorbar = true,
                    xlim = (-g_AD.Lx/2, g_AD.Lx/2),
                    ylim = (-g_AD.Ly/2, g_AD.Ly/2),
                    title = "C(x,y,t), t = "*string(round(cl_AD.t; digits = 2)))
        push!(upper_layer_tracer_plots_AD, tp_u)
        tp_l = heatmap(x, y, v_AD.c[:, :, 2]',
                    aspectratio = 1,
                    c = :balance,
                    xlabel = "x",
                    ylabel = "y",
                    colorbar = true,
                    xlim = (-g_AD.Lx/2, g_AD.Lx/2),
                    ylim = (-g_AD.Ly/2, g_AD.Ly/2),
                    title = "C(x,y,t), t = "*string(round(cl_AD.t; digits = 2)))
        push!(lower_layer_tracer_plots_AD, tp_l)
        global plot_time_AD += plot_time_inc
    end
    stepforward!(AD_prob, nsubs)
    TracerAdvDiff_QG.QGupdatevars!(AD_prob)
    ##  Update the chosen diagnostic at each step
    #MeasureMixing.conc_var!(concentration_variance, AD_prob)
    #MeasureMixing.area_tracer_patch!(second_moment_con, AD_prob, QG_prob, κ)
    #MeasureMixing.fit_normal!(σ², AD_prob)

    #Updates the velocity field in advection problem to the velocity field in the MultiLayerQG.Problem at each timestep.
    TracerAdvDiff_QG.vel_field_update!(AD_prob, QG_prob, nsubs)
end
#Need to set this up so this does not need to be hardcoded.
#Display the tracer advection in the upper layer.
plot_top = plot(upper_layer_tracer_plots_AD[1], upper_layer_tracer_plots_AD[2], 
                upper_layer_tracer_plots_AD[3], upper_layer_tracer_plots_AD[4],
                upper_layer_tracer_plots_AD[5], upper_layer_tracer_plots_AD[6])
     
#Display the tracer advection in the lower layer.
plot_bottom = plot(lower_layer_tracer_plots_AD[1], lower_layer_tracer_plots_AD[2], 
                   lower_layer_tracer_plots_AD[3], lower_layer_tracer_plots_AD[4],
                   lower_layer_tracer_plots_AD[5], lower_layer_tracer_plots_AD[6])

plot(plot_top, plot_bottom, layout=(2, 1), size=(1200, 1200))

#Code to create a video from the array of plots in the top (or bottom) layer. Make plot_time_inc = Δt = plot_time_AD
#=
anim = @animate for i in 1:length(upper_layer_tracer_plots_AD)
    plot(upper_layer_tracer_plots_AD[i])
end
mp4(anim, "tracer_ad.mp4", fps = 18)
=#

#Time vector to plot diagnostics
t = range(0, (nsteps + 1)*Δt, step = Δt)

#=
concentration_variance_top = plot(t, concentration_variance[:, 1], xlabel = "t", title = "Top layer variance of concentration", label = false)
concentration_variance_bottom = plot(t, concentration_variance[:, 2], xlabel = "t", title = "Bottom layer variance of concentration", label = false)
plot(concentration_variance_top, concentration_variance_bottom, size=(900, 400))
=#

#=
second_moment_con_top = plot(t, second_moment_con[:, 1], xlabel = "t", title = "Second moment of tracer concentration", label = false)
second_moment_con_bottom = plot(t, second_moment_con[:, 2], xlabel = "t", title = "Second moment of tracer concentration", label = false)
plot(second_moment_con_top, second_moment_con_bottom, size=(900, 400))
=#

#=
σ²_top = plot(t, σ²[:, 1], xlabel = "t", title = "σ² from mle fit each time step in top layer", label = false)
σ²_bottom = plot(t, σ²[:, 2], xlabel = "t", title = "σ² from mle fit each time step in bottom layer", label = false)
plot(σ²_top, σ²_bottom, size=(900, 400))
=#