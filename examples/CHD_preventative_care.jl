using Logging
using JuMP, Gurobi
using DecisionProgramming
using CSV, DataFrames, PrettyTables



# Setting subproblem specific parameters
const chosen_risk_level = 13


# Reading tests' technical performance data (dummy data in this case)
data = CSV.read("CHD_preventative_care_data.csv", DataFrame)



# Bayes posterior risk probabilities calculation function
# prior = prior risk level for which the posterior risk distribution is calculated for,
# t = test done
# returns a 100x1 vector with the probabilities of getting CHD given the prior risk level and test result
# for no test done (i.e. t = 3) returns a zero vector
function update_risk_distribution(prior::Int64, t::Int64)
    if t == 1 # the test is TRS
        # P(TRS = result | sick) = P(TRS_if_sick = result) * P(sick) = P(TRS_if_sick = result) * P(prior_risk)
        numerators = data.TRS_if_sick .* data.risk_levels[prior]

        # P(TRS = result) = P(TRS_if_sick = result) * P(sick) + P(TRS_if_healthy = result) * P(healthy)
        denominators = data.TRS_if_sick .* data.risk_levels[prior]  + data.TRS_if_healthy .* (1 - data.risk_levels[prior])

        posterior_risks = numerators./denominators

        # if the denominator is zero, post_risk is NaN, changing those to 0
        for i = 1:101
            if isnan(posterior_risks[i])
                posterior_risks[i] = 0
            end
        end

        return posterior_risks


    elseif t == 2 #the test is GRS
        numerators = (data.GRS_if_sick .* data.risk_levels[prior])
        denominators = data.GRS_if_sick .* data.risk_levels[prior]  + data.GRS_if_healthy .* (1 .- data.risk_levels[prior])

        posterior_risks =  numerators./denominators

        # if the denominator is zero, post_risk is NaN, changing those to 0
        for i = 1:101
            if isnan(posterior_risks[i])
                posterior_risks[i] = 0
            end
        end

        return posterior_risks


    else # no test performed
        risks_unchanged = zeros(100,1)


        return risks_unchanged

    end
end

# State probabilites calculation function
# risk_p = the resulting array from update_risk_distribution
# t = test done
# h = CHD or no CHD
# returns the probability distribution in 101x1 vector for the states of the R node given the prior risk level (must be same as to function update_risk_distribution), test t and health h
function state_probabilities(risk_p::Array{Float64}, t::Int64, h::Int64, prior::Int64)

    #if no test is performed, then the probabilities of moving to states (other than the prior risk level) are 0 and to the prior risk element is 1
    if t == 3
        state_probabilites = zeros(101, 1)
        state_probabilites[prior] = 1.0
        return state_probabilites
    end

    # return vector
    state_probabilites = zeros(101,1)

    # copying the probabilities of the scores for ease of readability
    if h == 1 && t == 1    # CHD and TRS
        p_scores = data.TRS_if_sick
    elseif t ==1    # no CHD and TRS
        p_scores = data.TRS_if_healthy
    elseif h == 1 && t == 2 # CHD and GRS
        p_scores = data.GRS_if_sick
    else # no CHD and GRS
        p_scores = data.GRS_if_healthy
    end

    for i = 1:101 #iterating through all risk levels 0%, 1%, ..., 99%, 100% in data.risk_levels
        for j = 1:101 #iterates through all risk estimates in risk_p
            #finding all risk estimates risk_p[j] within risk level i
            # risk_level[i] <= risk_p < risk_level[i]
            if i < 101 && data.risk_levels[i] <= risk_p[j] && risk_p[j] < data.risk_levels[i+1]
                state_probabilites[i] += p_scores[j]
            elseif i == 101 && data.risk_levels[i] <= risk_p[j] #special case: the highest risk level[101] = 100%
                state_probabilites[i] += p_scores[j]
            end
        end
    end

    return state_probabilites
end


function analysing_results(Z::DecisionStrategy, sprobs::StateProbabilities)

    d = Z.D[1] #taking one of the decision nodes to retrieve the information_set_R
    information_set_R = vec(collect(paths(S[d.I_j])))
    results = DataFrame(Information_set = map( x -> string(x) * "%", [0:1:100;]))
    # T1
    Z_j = Z.Z_j[1]
    probs =  map(x -> x > 0 ? 1 : 0, get(sprobs.probs, 1,0)) #these are zeros and ones
    dec = [Z_j(s_I) for s_I in information_set_R]
    results[!, "T1"] = map(x -> x == 0 ? "" : "$x", probs.*dec)

    # T2
    Z_j = Z.Z_j[2]
    probs = map(x -> x > 0 ? 1 : 0, (get(sprobs.probs, 4,0))) #these are zeros and ones
    dec = [Z_j(s_I) for s_I in information_set_R]
    results[!, "T2"] = map(x -> x == 0 ? "" : "$x", probs.*dec)

    # TD
    Z_j = Z.Z_j[3]
    probs = map(x -> x > 0 ? 1 : 0, (get(sprobs.probs, 6,0))) #these are zeros and ones
    dec = [Z_j(s_I) for s_I in information_set_R]
    results[!, "TD"] = map(x -> x == 0 ? "" : "$x", probs.*dec)

    pretty_table(results)
end


const R0 = 1
const H = 2
const T1 = 3
const R1 = 4
const T2 = 5
const R2 = 6
const TD = 7
const TC = 8
const HB = 9


const H_states = ["CHD", "no CHD"]
const T_states = ["TRS", "GRS", "no test"]
const TD_states = ["treatment", "no treatment"]
const R_states = map( x -> string(x) * "%", [0:1:100;])
const TC_states = ["TRS", "GRS", "TRS & GRS", "no tests"]
const HB_states = ["CHD & treatment", "CHD & no treatment", "no CHD & treatment", "no CHD & no treatment"]

@info("Creating the influence diagram.")
S = States([
    (length(R_states), [R0, R1, R2]),
    (length(H_states), [H]),
    (length(T_states), [T1, T2]),
    (length(TD_states), [TD])
])

C = Vector{ChanceNode}()
D = Vector{DecisionNode}()
V = Vector{ValueNode}()
X = Vector{Probabilities}()
Y = Vector{Consequences}()


I_R0 = Vector{Node}()
X_R0 = zeros(S[R0])
X_R0[chosen_risk_level] = 1
push!(C, ChanceNode(R0, I_R0))
push!(X, Probabilities(R0, X_R0))


I_H = [R0]
X_H = zeros(S[R0], S[H])
X_H[:, 1] = data.risk_levels     # 1 = "CHD"
X_H[:, 2] = 1 .- X_H[:, 1]  # 2 = "no CHD"
push!(C, ChanceNode(H, I_H))
push!(X, Probabilities(H, X_H))


I_T1 = [R0]
push!(D, DecisionNode(T1, I_T1))


I_R1 = [R0, H, T1]
X_R1 = zeros(S[I_R1]..., S[R1])
for s_R0 = 1:101, s_H = 1:2, s_T1 = 1:3
    X_R1[s_R0, s_H, s_T1, :] =  state_probabilities(update_risk_distribution(s_R0, s_T1), s_T1, s_H, s_R0)
end
push!(C, ChanceNode(R1, I_R1))
push!(X, Probabilities(R1, X_R1))


I_T2 = [R1]
push!(D, DecisionNode(T2, I_T2))


I_R2 = [H, R1, T2]
X_R2 = zeros(S[I_R2]..., S[R2])
for s_R1 = 1:101, s_H = 1:2, s_T2 = 1:3
    X_R2[s_H, s_R1, s_T2, :] =  state_probabilities(update_risk_distribution(s_R1, s_T2), s_T2, s_H, s_R1)
end
push!(C, ChanceNode(R2, I_R2))
push!(X, Probabilities(R2, X_R2))


I_TD = [R2]
push!(D, DecisionNode(TD, I_TD))


I_TC = [T1, T2]
Y_TC = zeros(S[I_TC]...)
cost_TRS = -0.0034645
cost_GRS = -0.004
cost_forbidden = 0     #the cost of forbidden test combinations is negligible
Y_TC[1 , 1] = cost_forbidden
Y_TC[1 , 2] = cost_TRS + cost_GRS
Y_TC[1, 3] = cost_TRS
Y_TC[2, 1] =  cost_GRS + cost_TRS
Y_TC[2, 2] = cost_forbidden
Y_TC[2, 3] = cost_GRS
Y_TC[3, 1] = cost_TRS
Y_TC[3, 2] = cost_GRS
Y_TC[3, 3] = 0
push!(V, ValueNode(TC, I_TC))
push!(Y, Consequences(TC, Y_TC))


I_HB = [H, TD]
Y_HB = zeros(S[I_HB]...)
Y_HB[1 , 1] = 6.89713671259061  # sick & treat
Y_HB[1 , 2] = 6.65436854256236  # sick & don't treat
Y_HB[2, 1] = 7.64528451705134   # healthy & treat
Y_HB[2, 2] =  7.70088349200034  # healthy & don't treat
push!(V, ValueNode(HB, I_HB))
push!(Y, Consequences(HB, Y_HB))


@info("Validate influence diagram.")
validate_influence_diagram(S, C, D, V)
sort!.((C, D, V, X, Y), by = x -> x.j)

P = DefaultPathProbability(C, X)
U = DefaultPathUtility(V, Y)


@info("Creating the decision model.")
model = Model()
z = DecisionVariables(model, S, D)

# Defining forbidden paths to include all those where a test is repeated twice
forbidden_tests = ForbiddenPath[([T1,T2], Set([(1,1),(2,2),(3,1), (3,2)]))]
scale_factor = 10000.0
x_s = PathCompatibilityVariables(model, z, S, P; fixed = Dict(1 => chosen_risk_level), forbidden_paths = forbidden_tests, probability_cut=false)

EV = expected_value(model, x_s, U, P, probability_scale_factor = scale_factor)
@objective(model, Max, EV)

@info("Starting the optimization process.")
optimizer = optimizer_with_attributes(
    () -> Gurobi.Optimizer(Gurobi.Env()),
    "MIPFocus" => 3,
    "MIPGap" => 1e-6,
)
set_optimizer(model, optimizer)
optimize!(model)


@info("Extracting results.")
Z = DecisionStrategy(z)

@info("Printing decision strategy using tailor made function:")
sprobs = StateProbabilities(S, P, Z)
analysing_results(Z, sprobs)

@info("Printing state probabilities:")
# Here we can see that the probability of having a CHD event is exactly that of the chosen risk level
print_state_probabilities(sprobs, [R0, R1, R2])

@info("Computing utility distribution.")
udist = UtilityDistribution(S, P, U, Z)

@info("Printing utility distribution.")
print_utility_distribution(udist)

@info("Printing statistics")
print_statistics(udist)
