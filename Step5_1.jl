using JuMP, HiGHS, Plots, PrettyTables
T = 1
#%% Create the optimization model
Step5 = Model(HiGHS.Optimizer)

# Define a dictionary where each generator has max power and cost
G = 12
generator_data = Dict(
    "p_G1"  => (max_power = 152,  cost = 13.32, ),    #minP = 30.4
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
W = 6
wind_turbine_data = Dict(
    "p_W1"  => (max_power = 200,  cost = 0),    
    "p_W2"  => (max_power = 200,  cost = 0),    
    "p_W3"  => (max_power = 200,  cost = 0),     
    "p_W4"  => (max_power = 200,  cost = 0),    
    "p_W5"  => (max_power = 200,  cost = 0),    
    "p_W6"  => (max_power = 200,  cost = 0)    
)

Demanded_energy = [2650] #MWh  #changed
L = 17
elastic_demand_data = Dict(
    "p_L1"  =>  (load_fraction = 3.8/100,  cost = 15.32),    
    "p_L2"  =>  (load_fraction = 3.4/100,  cost = 13.32),   # changed 
    "p_L3"  =>  (load_fraction = 6.3/100,  cost = 20.7),     
    "p_L4"  =>  (load_fraction = 2.6/100,  cost = 20.93),    
    "p_L5"  =>  (load_fraction = 2.5/100,  cost = 20.11),     
    "p_L6"  =>  (load_fraction = 4.8/100,  cost = 11.52),    
    "p_L7"  =>  (load_fraction = 4.4/100,  cost = 17.52),    
    "p_L8"  =>  (load_fraction = 6/100,    cost = 16.02),    
    "p_L9"  =>  (load_fraction = 6.1/100,  cost = 15.47),    
    "p_L10" =>  (load_fraction = 6.8/100,  cost = 20.5),     
    "p_L11" =>  (load_fraction = 9.3/100,  cost = 19.52),    
    "p_L12" =>  (load_fraction = 6.8/100,  cost = 16.89),    
    "p_L13"  => (load_fraction = 11.1/100, cost = 6.7),     
    "p_L14"  => (load_fraction = 3.5/100,  cost = 20.93),    
    "p_L15"  => (load_fraction = 11.7/100, cost = 26.11),    
    "p_L16"  => (load_fraction = 6.4/100,  cost = 16.52),    
    "p_L17"  => (load_fraction = 4.5/100,  cost = 18.52),    
)

# Variables with constraints
@variable(Step5, 0 <= generator_var[g = 1:G] <= generator_data["p_G$g"].max_power)                        # Generation power of each generator
@variable(Step5, 0 <= load_var[l = 1:L] <= Demanded_energy[1] * elastic_demand_data["p_L$l"].load_fraction) # Load for each load
@variable(Step5, 0 <= wind_var[w = 1:W] <= 1*wind_turbine_data["p_W$w"].max_power)                          # Power from each wind turbine


#%% Power balance equation
power_balance_equation= @constraint(Step5, sum(generator_var[g] for g in 1:G) + sum(wind_var[w] for w in 1:W) == sum(load_var[l] for l in 1:L))

#%% Define the objective function (Maximize SW)
obj_value= @objective(Step5, Max, sum(elastic_demand_data["p_L$(l)"].cost *load_var[l] for l in 1:L) 
                                - sum(wind_turbine_data["p_W$(w)"].cost * wind_var[w] for w in 1:W)
                                - sum(generator_data["p_G$(g)"].cost * generator_var[g] for g in 1:G))

# Solve the optimization problem
optimize!(Step5)

# Print results
println("________________________________________________________________________________")
println("                               Optimal Solution:                                ")

# Prepare data for the table
header_gen = [["p_G$g"] for g in 1:G]
tab_gen_var = [round(value(generator_var[g]), digits=2) for g in 1:G]'
pretty_table(tab_gen_var; header=header_gen)

header_wind = [["p_W$w"] for w in 1:W]
tab_wind_var = [round(value(wind_var[w]), digits=2) for w in 1:W]'
pretty_table(tab_wind_var; header=header_wind)

header_load = [["p_L$l"] for l in 1:L]
tab_load_var = [round(value(load_var[l]), digits=2) for l in 1:L]'
pretty_table(tab_load_var; header=header_load)


# Print UTILITY and PROFIT
power_g_vec =[value(generator_var[g]) for g in 1:G]             #gen
cost_g_vec = [generator_data["p_G$g"].cost for g in 1:G]        #gen
power_w_vec = [value(wind_var[w]) for w in 1:W]                 #wind
cost_w_vec = [wind_turbine_data["p_W$w"].cost for w in 1:W]     #wind
power_l_vec = [value(load_var[l]) for l in 1:L]                 #load
cost_l_vec = [elastic_demand_data["p_L$l"].cost for l in 1:L]   #load

profit_g = power_g_vec .* (-cost_g_vec.+dual(power_balance_equation))
profit_w = power_w_vec .* (-cost_w_vec.+dual(power_balance_equation))
utility_l = power_l_vec .* (cost_l_vec.-dual(power_balance_equation))

# Print of profit of each generator
println("________________________________________________________________________________")
println("Profit of generators at time", 1, " = ")

# Prepare data for the table
generator_profits = reduce(vcat, [ ["Gen $g" profit_g[g]] for g in 1:G ])  # Convert Vector of Vectors → Matrix
header= ["Generator", "Profit"]  # Header of the table
# Print the table
pretty_table(generator_profits; header)


# Print of profit of each wind turbine
println("Profit of wind turbines at time", 1, " = ")

# Prepare data for the table
wind_profits = reduce(vcat, [ ["Wind $w" profit_w[w]] for w in 1:W ])  # Convert Vector of Vectors → Matrix
header = ["Wind farm", "Profit"]  # Header of the table
# Print the table
pretty_table(wind_profits; header)

# Print of utility of each demand
println("Utility of loads at time", 1, " =")

# Prepare data for the table
demands_utility = reduce(vcat, [ ["Demand $l" utility_l[l]] for l in 1:L ])  # Convert Vector of Vectors → Matrix
header = ["Demand", "Utility"]  # Header of the table
# Print the table
pretty_table(demands_utility; header)

# Print of Social Welfare, Market clearing price, and Market clearing quantity
Market_clearing_price = dual(power_balance_equation)
Market_clearing_quantity = sum(value(load_var[l]) for l in 1:L)
println("________________________________________________________________________________")
println("Social Welfare = ", round(objective_value(Step5), digits=2), " €")
println("Dual Variable power balance equation/Market clearing price:", Market_clearing_price, " €/MWh")
println("Market clearing quantity = ", Market_clearing_quantity, " MWh")
println("________________________________________________________________________________")
###############################################################################################################

#Plot figures
# Extract maximum power and cost for generators, wind turbines, and loads
power_g =[generator_data["p_G$g"].max_power for g in 1:G]
cost_g = [generator_data["p_G$g"].cost for g in 1:G]
power_w = [wind_turbine_data["p_W$w"].max_power for w in 1:W]
cost_w = [wind_turbine_data["p_W$w"].cost for w in 1:W]
power_l = [Demanded_energy[1] * elastic_demand_data["p_L$l"].load_fraction for l in 1:L]
cost_l = [elastic_demand_data["p_L$l"].cost for l in 1:L]

# Combine costs and powers for generators and wind turbines
all_costs = vcat(cost_g, cost_w)
all_powers = vcat(power_g, power_w)

# Sort supply offers by cost in ascending order
sorted_supp = sort(collect(zip(all_costs, all_powers)), by=x -> x[1])

# Sort demand bids by cost in descending order
sorted_dem = sort(collect(zip(cost_l, power_l)), by=x -> x[1], rev=true)

supp_x = [0;cumsum([q[2] for q in sorted_supp])]  # Cumulative quantities. Added 0 to start from zero
supp_y = [q[1] for q in sorted_supp]  # Prices
supp_y = [supp_y;supp_y[end]]  # Add the last price to the end

dem_x = [0;cumsum([q[2] for q in sorted_dem]) ] # Cumulative quantities. Added 0 to start from zero
dem_y = [q[1] for q in sorted_dem]  # Prices
dem_y = [dem_y;0]  # Add zero to the end

# Plot supply and demand curves
fig = plot(supp_x, supp_y, label="Supply", lw=2, marker=:circle, line=:step, color=:blue, legend=:bottomright, grid =:true,size=(800, 600))
plot!(dem_x, dem_y, label="Demand", lw=2, marker=:circle, line=:step, color=:orange)
hline!([Market_clearing_price], lw=1, linestyle=:dash, color=:grey, label=:none)
vline!([Market_clearing_quantity], lw=1, linestyle=:dash, color=:grey, label=:none)
scatter!([Market_clearing_quantity], [Market_clearing_price], label="Equilibrium point", markersize=5, color=:purple, marker=:diamond)
xlabel!("Power Supply/Demand (MW)")
ylabel!("Offer Price (€/MWh)")  
title!("Supply and Demand Curves")

# Add text annotations
annotate!([(Market_clearing_quantity -100, 2.5, text("$(Market_clearing_quantity) MW", :grey, 8, rotation=90))])
annotate!([(400, Market_clearing_price + 1, text("$(Market_clearing_price) €/MWh", :grey, 8))])

# Display the plot
display(fig)
# savefig(fig, "Supply_and_Demand_Curves_Step5_1.png")

#####################################################################################################
#####################################################################################################
#####################################################################################################

# BALANCING MARKET

generator_outage = [8] # select generator outage
generators_balancing_service_providers =[4,5,9,10,11,12]
upward_regulation_service = 1.1*[generator_data["p_G$g"].cost for g in 1:G] # 10% additional to day-ahead price for overproducing
downward_regulation_service = 0.85*[generator_data["p_G$g"].cost for g in 1:G]# -15%  to day-ahead price for underproducing
load_curtailment_cost = 50 # cost for load shedding
overproduction_wind = 0.15 # 15% of overproduction
underproduction_wind = -0.1 # 10% ofunderproduction
wind_overprod = [1, 2, 3] # select wind turbines overproducing
wind_underprod = setdiff(1:W, wind_overprod) # wind turbines underproducing (remaining)

##____________________Find generators participating in the DOWN and UP balancing____________________
generators_balancing_service_providers = setdiff(generators_balancing_service_providers, generator_outage) # Generators actually avaialble

gen_UP_reg = zeros(Int, G)  # Initialize with zeros
gen_DOWN_reg = zeros(Int, G)  # Initialize with zeros

for g in 1:G
    if value(generator_var[g]) == generator_data["p_G$g"].max_power
        gen_UP_reg[g] = 1
    end
    if value(generator_var[g]) == 0
        gen_DOWN_reg[g] = 1
    end
end
gen_UP_reg = findall(x -> x == 0, gen_UP_reg) # Find the positions of possible generators for UP regulation
gen_DOWN_reg = findall(x -> x == 0, gen_DOWN_reg) # Find the positions of possible generators for DOWN regulation
gen_UP_reg = intersect(generators_balancing_service_providers, gen_UP_reg) #Find gen for UP reg
gen_DOWN_reg = intersect(generators_balancing_service_providers, gen_DOWN_reg) #Find gen for DOWN reg

##____________________Find demand participating in the balancing market____________________
demand_NON_partecipating = zeros(Int, L)  # Initialize with zeros
for l in 1:L
    if value(load_var[l]) == 0
        demand_NON_partecipating[l] = 1
    end
end
demand_Participating_positions = findall(x -> x == 0, demand_NON_partecipating) # Find the positions of PARTICIPATING demands

# ___________________OPTIMIZATION PROBLEM_______________________________________

Step5_balancing = Model(HiGHS.Optimizer)

# Variables with constraints
@variable(Step5_balancing, 0 <= generator_upward_reg[g = generators_balancing_service_providers]   <= generator_data["p_G$g"].max_power - value(generator_var[g]))    # Generation upward
@variable(Step5_balancing, 0 <= generator_downward_reg[g = generators_balancing_service_providers] <= value(generator_var[g]) )    # Generation downward
@variable(Step5_balancing, 0 <= demand_curtailment[l = 1:L]<= value(load_var[l]))  # Load curtailment

#%% Power balance equation
Balancing_need = - sum(value(generator_var[g]) for g in generator_outage) +
                  sum(value(wind_var[w]) * overproduction_wind for w in wind_overprod)  +
                  sum(value(wind_var[w]) * underproduction_wind for w in wind_underprod) # Positive there is a surplus --> need DOWN reg

power_balance_equation_balancing= @constraint(Step5_balancing, sum(generator_upward_reg[g] for g in generators_balancing_service_providers) 
                                                            - sum(generator_downward_reg[g] for g in generators_balancing_service_providers) 
                                                            + sum(demand_curtailment[l] for l in 1:L) == -Balancing_need)

#%% Define the objective function (Minimize)
obj_value_balancing = @objective(Step5_balancing, Min, sum(upward_regulation_service[g] * generator_upward_reg[g] for g in generators_balancing_service_providers)
                                            + sum(load_curtailment_cost * demand_curtailment[l] for l in 1:L)
                                            - sum(downward_regulation_service[g] * generator_downward_reg[g] for g in generators_balancing_service_providers))
                                
# Solve the optimization problem
optimize!(Step5_balancing)

#________________________________Print results________________________________________________
println("________________________________________________________________________________")
println("________________________________________________________________________________")

println("                               Optimal Solution of Balancing Market:")

# Prepare data for the table
header_gen_UP = [["↑p_G$g"] for g in generators_balancing_service_providers]
tab_gen_var = [round(value(generator_upward_reg[g]), digits=2) for g in generators_balancing_service_providers]'
pretty_table(tab_gen_var; header=header_gen_UP, crop=:none)

header_gen_DOWN = [["↓_p_G$g"] for g in generators_balancing_service_providers]
tab_gen_var = [round(value(generator_downward_reg[g]), digits=2) for g in generators_balancing_service_providers]'
pretty_table(tab_gen_var; header=header_gen_DOWN, crop=:none)


header_demand_CURT = [["✂️ L$l"] for l in 1:L]
tab_demand_var = [round(value(demand_curtailment[l]), digits=2) for l in 1:L]'
pretty_table(tab_demand_var; header=header_demand_CURT, crop=:none)

println("________________________________________________________________________________")
println("________________________________________________________________________________")


#___________________________________Plot figures________________________________________________

# Extract maximum power and cost for generators, demands ONLY THOSE WHICH PARTICIPATE
power_UP_g =[generator_data["p_G$g"].max_power - value(generator_var[g]) for g in gen_UP_reg]
cost_UP_g = [upward_regulation_service[g] for g in gen_UP_reg]
power_DOWN_g =[-value(generator_var[g]) for g in gen_DOWN_reg]
cost_DOWN_g = [downward_regulation_service[g] for g in gen_DOWN_reg]
power_CURT_l = [value(load_var[l]) for l in demand_Participating_positions]
cost_CURT_l = [load_curtailment_cost for l in demand_Participating_positions]

# Combine costs and powers for generators and wind turbines
all_costs_UP_CURT = vcat(cost_UP_g, cost_CURT_l)
all_powers_UP_CURT = vcat(power_UP_g, power_CURT_l)

# Sort supply offers by cost in ascending order
sorted_UP = sort(collect(zip(all_costs_UP_CURT, all_powers_UP_CURT)), by=x -> x[1])
sorted_UP = sort(filter(x -> x[2] ≠ 0, collect(zip(all_costs_UP_CURT, all_powers_UP_CURT))),by = x -> x[1])

# Sort demand bids by cost in descending order
sorted_DOWN = sort(collect(zip(cost_DOWN_g, power_DOWN_g)), by=x -> x[1], rev=true) 

UP_x = [0;cumsum([q[2] for q in sorted_UP])]  # Cumulative quantities. Added 0 to start from zero
UP_y = [q[1] for q in sorted_UP]  # Prices
UP_y = [UP_y;UP_y[end]]  # Add the last price to the end

DOWN_x = [0;cumsum([q[2] for q in sorted_DOWN]) ] # Cumulative quantities. Added 0 to start from zero
DOWN_y = [q[1] for q in sorted_DOWN]  # Prices
DOWN_y = [DOWN_y;DOWN_y[end]]  # Add zero to the end


Market_clearing_price_balancing = dual(power_balance_equation_balancing)
sum(value(generator_downward_reg[g]) for g in generators_balancing_service_providers)
Market_clearing_quantity_balancing =  sum(value(generator_upward_reg[g]) for g in generators_balancing_service_providers) -
                                     sum(value(generator_downward_reg[g]) for g in generators_balancing_service_providers) +
                                     sum(value(demand_curtailment[l]) for l in 1:L)
# Plot supply and demand curves
fig1 = hline([0], lw=1, linestyle=:solid, color=:black, label=:none, size=(800, 600))
vline!([0], lw=1, linestyle=:solid, color=:black, label=:none)
plot!(UP_x, UP_y, label="UP reg", lw=2, marker=:circle, line=:step, color=:blue, legend=:bottomright, grid =:true)
plot!(DOWN_x, DOWN_y, label="DOWN reg", lw=2, marker=:circle, line=:step, color=:orange, grid=:true)
hline!([Market_clearing_price], lw=1, linestyle=:solid, color=:purple, label=:none)

hline!([Market_clearing_price_balancing], lw=1, linestyle=:dash, color=:grey, label=:none)
vline!([Market_clearing_quantity_balancing], lw=1, linestyle=:dash, color=:grey, label=:none)
scatter!([Market_clearing_quantity_balancing], [Market_clearing_price_balancing], label="Equilibrium point", markersize=5, color=:purple, marker=:diamond)
xlabel!("Power Supply/Demand to balance (MW)")
ylabel!("Offer Price (€/MWh)")  
title!("Balancing market clearing")

# Add text annotations
annotate!([(Market_clearing_quantity_balancing -100, 30, text("$(round(Market_clearing_quantity_balancing)) MW", :grey, 8, rotation=90))])
annotate!([(2000, Market_clearing_price_balancing +0.5 , text("$(round(Market_clearing_price_balancing, digits=2)) €/MWh", :grey, 8))])
annotate!([(Market_clearing_quantity/2, Market_clearing_price +0.5 , text("$(round(Market_clearing_price, digits=2)) €/MWh: DAY-ahead Price", :purple, 8))])

# Display the plot
savefig(fig1, "Balancing_market_clearing.png")
display(fig1)

println("________________________________________________________________________________")
println("Power to balance = ", round(Balancing_need, digits=2), " MW")
println("Total cost of upward regulation = ", round(objective_value(Step5_balancing), digits=2), " €")
println("Dual Variable power balance equation/Market clearing price:", Market_clearing_price_balancing, " €/MWh")
println("Market clearing quantity = ", round(Market_clearing_quantity_balancing, digits=2), " MWh")
println("________________________________________________________________________________")

# Calculation of total profit single_price
revenue_g_balancing = zeros(G) # init
profit_g_balancing = zeros(G) # init
for g in generators_balancing_service_providers
    revenue_g_balancing[g] = Market_clearing_price_balancing * value(generator_upward_reg[g]) # Revenue from upward regulation
                        - Market_clearing_price_balancing * value(generator_downward_reg[g])  # Revenue from downward regulation
    profit_g_balancing[g] = value(generator_upward_reg[g]) * (-cost_g_vec[g] + Market_clearing_price_balancing) # Profit from upward regulation
                        - value(generator_downward_reg[g]) * (-cost_g_vec[g] + Market_clearing_price_balancing) # Profit from downward regulation
end
revenue_g_balancing[generator_outage] = -Market_clearing_price_balancing * value.(generator_var[generator_outage]) # Revenue from generator outage
profit_g_balancing[generator_outage] = -value.(generator_var[generator_outage]) .* (-cost_g_vec[generator_outage] .+ Market_clearing_price_balancing) # Profit from generator outage

revenue_w_balancing = zeros(W) # init
profit_w_balancing = zeros(W) # init
for w in wind_overprod
    revenue_w_balancing[w] = Market_clearing_price_balancing *value(wind_var[w]) * overproduction_wind # Revenue from overproduction
    profit_w_balancing[w] = value(wind_var[w])* overproduction_wind .* (-cost_w_vec[w] .+ Market_clearing_price_balancing ) # Profit from overproduction
end
for w in wind_underprod
    revenue_w_balancing[w] = Market_clearing_price_balancing *value(wind_var[w]) * underproduction_wind # Revenue from underproduction
    profit_w_balancing[w] = value(wind_var[w])* underproduction_wind .* (-cost_w_vec[w] .+ Market_clearing_price_balancing ) # Profit from underproduction
end

println(round(sum(revenue_g_balancing)+ sum(revenue_w_balancing), digits=2), " €  -->  Balancing price split between market actors")

# Print of profit of each generator and wind turbine with two-price scheme

header_gen = ["Generator", "Profit Day-Ahead [€]", "Profit Balancing [€]", "Profit [€]"]  # Define the header
tab_gen_var = hcat(["p_G$g" for g in 1:G], profit_g, profit_g_balancing, profit_g + profit_g_balancing)  # Combine labels and data into a matrix
printstyled("Profit for generators single-price and dual-price\n"; bold=true, color=:yellow)
pretty_table(tab_gen_var; header=header_gen, crop=:none)  # Display the table

header_wind = ["Wind Turbine", "Profit Day-Ahead [€]", "Profit Balancing [€]", "Profit [€]"]  # Define the header
tab_wind_var = hcat(["p_W$w" for w in 1:W], profit_w, profit_w_balancing, profit_w + profit_w_balancing)  # Combine labels and data into a matrix
printstyled("Profit single-price for wind turbines\n"; bold=true, color=:blue)
pretty_table(tab_wind_var; header=header_wind, crop=:none)  # Display the table

println("________________________________________________________________________________")

if Balancing_need > 0
    println("The system needs DOWN regulation -> intervention on underproducing wind turbines")
    revenue_w_balancing = zeros(W) # init
    profit_w_balancing = zeros(W) # init
    for w in wind_overprod
        revenue_w_balancing[w] = Market_clearing_price_balancing *value(wind_var[w]) * overproduction_wind # Revenue from overproduction
        profit_w_balancing[w] = value(wind_var[w])* overproduction_wind .* (-cost_w_vec[w] .+ Market_clearing_price_balancing ) # Profit from overproduction
    end
    for w in wind_underprod
        revenue_w_balancing[w] = Market_clearing_price_balancing *value(wind_var[w]) * underproduction_wind # Revenue from underproduction
        profit_w_balancing[w] = value(wind_var[w])* underproduction_wind .* (-cost_w_vec[w] .+ Market_clearing_price_balancing ) # Profit from underproduction
    end

else
    println("The system needs UP regulation -> intervention on overproducing wind turbines")
    revenue_w_balancing = zeros(W) # init
    profit_w_balancing = zeros(W) # init
    for w in wind_overprod
        revenue_w_balancing[w] = Market_clearing_price *value(wind_var[w]) * overproduction_wind # Revenue from overproduction
        profit_w_balancing[w] = value(wind_var[w])* overproduction_wind .* (-cost_w_vec[w] .+ Market_clearing_price ) # Profit from overproduction
    end
    for w in wind_underprod
        revenue_w_balancing[w] = Market_clearing_price_balancing *value(wind_var[w]) * underproduction_wind # Revenue from underproduction
        profit_w_balancing[w] = value(wind_var[w])* underproduction_wind .* (-cost_w_vec[w] .+ Market_clearing_price_balancing ) # Profit from underproduction
    end
end


header_wind = ["Wind Turbine", "Profit Day-Ahead [€]", "Profit Balancing [€]", "Profit [€]"]  # Define the header
tab_wind_var = hcat(["p_W$w" for w in 1:W], profit_w, profit_w_balancing, profit_w + profit_w_balancing)  # Combine labels and data into a matrix
printstyled("Profit dual-price for wind turbines\n"; bold=true, color=:green)
pretty_table(tab_wind_var; header=header_wind, crop=:none)  # Display the table