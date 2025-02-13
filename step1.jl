using JuMP, GLPK

#%% Create the optimization model
Step1 = Model(GLPK.Optimizer)

# Define a dictionary where each generator has max power and cost
generator_data = Dict(
    "p_G1"  => (max_power = 152,  cost = 13.32),    #minP = 30.4
    "p_G2"  => (max_power = 152,  cost = 13.32),    #minP = 30.4
    "p_G3"  => (max_power = 350,  cost = 20.7),     #minP = 75
    "p_G4"  => (max_power = 591,  cost = 20.93),    #minP = 206.85
    "p_G5"  => (max_power = 60,   cost = 26.11),    #minP = 12
    "p_G6"  => (max_power = 155,  cost = 10.52),    #minP = 54.25
    "p_G7"  => (max_power = 155,  cost = 10.52),    #minP = 54.25
    "p_G8"  => (max_power = 400,  cost = 6.02),     #minP = 100
    "p_G9"  => (max_power = 400,  cost = 5.47),     #minP = 100
    "p_G10" => (max_power = 300,  cost = 0),        #minP = 300
    "p_G11" => (max_power = 310,  cost = 10.52),    #minP = 108.5
    "p_G12" => (max_power = 250,  cost = 10.89)     #minP = 140
)


wind_turbine_data = Dict(
    "p_W1"  => (max_power = 152,  cost = 0),    #minP = 
    "p_W2"  => (max_power = 152,  cost = 0),    #minP = 
    "p_W3"  => (max_power = 350,  cost = 0),     #minP = 
    "p_W4"  => (max_power = 591,  cost = 0),    #minP = 
    "p_W5"  => (max_power = 60,   cost = 0),    #minP =
    "p_W6"  => (max_power = 155,  cost = 0),    #minP = 
)

elastic_demand_data = Dict(
    "p_L1"  => (max_power = 152,  cost = 13.32),    #minP = 
    "p_L2"  => (max_power = 152,  cost = 13.32),    #minP = 
    "p_L3"  => (max_power = 350,  cost = 20.7),     #minP = 
    "p_L4"  => (max_power = 591,  cost = 20.93),    #minP = 
    "p_L5"  => (max_power = 60,   cost = 26.11),    #minP = 
    "p_L6"  => (max_power = 155,  cost = 10.52),    #minP = 
    "p_L7"  => (max_power = 155,  cost = 10.52),    #minP = 
    "p_L8"  => (max_power = 400,  cost = 6.02),     #minP = 
    "p_L9"  => (max_power = 400,  cost = 5.47),     #minP = 
    "p_L10" => (max_power = 300,  cost = 0),        #minP = 
    "p_L11" => (max_power = 310,  cost = 10.52),    #minP = 
    "p_L12" => (max_power = 250,  cost = 10.89)     #minP = 
)

generator_vars = Dict() 
for (gen, data) in generator_data
    generator_vars[gen] = @variable(Step1, base_name=gen, lower_bound=0, upper_bound=data.max_power)
end

wind_vars = Dict()
for (wind, data) in wind_turbine_data
    wind_vars[wind] = @variable(Step1, base_name=wind, lower_bound=0, upper_bound=data.max_power)
end

load_vars = Dict()
for (load, data) in elastic_demand_data
    load_vars[load] = @variable(Step1, base_name=load, lower_bound=0, upper_bound=data.max_power)
end

#%% Power balance equation
power_balance_equation = @constraint(Step1, sum(generator_vars[g] for g in keys(generator_vars)) + 
                    sum(wind_vars[w] for w in keys(wind_vars)) -
                    sum(load_vars[l] for l in keys(load_vars))==0
)


#%% Define the objective function (Maximize SW)
@objective(Step1, Max, 
    -sum(generator_vars[g] * generator_data[g].cost for g in keys(generator_vars)) 
    -sum(wind_vars[w] * wind_turbine_data[w].cost for w in keys(wind_vars)) 
    +sum(load_vars[l] * elastic_demand_data[l].cost for l in keys(load_vars))
)

# Solve the optimization problem
optimize!(Step1)

# Print results
println("Optimal Solution:")
for g in keys(generator_vars)
    println(g, " = ", value(generator_vars[g]))
end
for w in keys(wind_vars)
    println(w, " = ", value(wind_vars[w]))
end
for l in keys(load_vars)
    println(l, " = ", value(load_vars[l]))
end

println("Social Welfare = ", objective_value(Step1), " \$")
println("Dual Variable power balance equation/clearing price:", dual(power_balance_equation), " \$/MWh")


# Collect all power generators in the same list
all_generators = collect(values(generator_data)) ∪ collect(values(wind_turbine_data))

# Order in increasing cost
sorted_data = sort(all_generators, by = x -> x.cost)

# Create data for graph
x = [0]  # Starting from zero
y = Float64[]

for gen in sorted_data
    push!(x, x[end] + gen.max_power)  # Start always after the previous generator in x coord (put appendix)
    push!(y, gen.cost)  # Put in appendix the associated price
end

# Repeat last value to create the step
push!(y, y[end])

# Step plot of the Supply curve
plot(x, y, label="Supply Curve", seriestype=:steppost, lw=2)
xlabel!("Quantity of Energy (MWh)")
ylabel!("Price (\$/MWh)")
title!("Supply curve")
savefig("Step1_Supply_curve.png") 

# Collect all power generators in the same list
all_demand = collect(values(elastic_demand_data))

# Order in decreasing cost
sorted_demand_data = sort(all_demand, by = x -> x.cost, rev=true)

# Create data for graph
x1 = [0]  # Starting from zero
y1 = Float64[]

for load in sorted_demand_data
    push!(x1, x1[end] + load.max_power)  # Start always after the previous load in x coord (put appendix)
    push!(y1, load.cost)  # Put in appendix the associated price
end

# Last value zero to create the intersection
push!(y1, 0)

# Step plot of the Supply and Demand curve
plot(x, y, label="Supply Curve", seriestype=:steppost, lw=2, color="blue")
plot!(x1, y1, label="Demand Curve", seriestype=:steppost, lw=2, color="orange")
xlabel!("Quantity of Energy (MWh)")
ylabel!("Price (\$/MWh)")
title!("Supply and Demand curve")
savefig("Step1_Supply_and_Demand_curve.png") 