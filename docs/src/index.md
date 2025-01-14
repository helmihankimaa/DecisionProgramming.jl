# DecisionProgramming.jl
DecisionProgramming.jl is a Julia package for solving *multi-stage decision problems under uncertainty*, modeled using influence diagrams, and leveraging the power of mixed-integer linear programming. Solving multi-stage decision problems under uncertainty consists of the following three steps.

In the first step, we model the decision problem using an influence diagram with associated probabilities, consequences, and path utility function.

In the second step, we create a decision model with an objective for the influence diagram. We solve the model to obtain an optimal decision strategy. We can create and solve multiple models with different objectives for the same influence diagram to receive various optimal decision strategies.

In the third step, we analyze the resulting decision strategies for the influence diagram. In particular, we are interested in the utility distribution and its associated statistics and risk measures.

DecisionProgramming.jl provides the necessary functionality for expressing and solving decision problems but does not explain how to design influence diagrams. The rest of this documentation will describe the mathematical and programmatic details, touch on the computational challenges, and provide concrete examples of solving decision problems.

The examples start with a rather simple and easily approachable [Used Car Buyer](examples/used-car-buyer.md) problem that can be also solved using more conventional methods such as decision trees. The following two examples illustrate the capabilities of the framework in problems where the *no-forgetting assumption* does not hold and solving the influence diagram with well-established techniques is thus impossible. In the [Pig Breeding](examples/pig-breeding.md) problem, only the most recent information is available when making each decision, thus breaking the no-forgetting assumption, while in the [N-Monitoring](examples/n-monitoring.md) problem, the decisions are made in parallel with no communication between the decision makers, also leading to the assumption not working. The [Contingent Portfolio Programming](examples/contingent-portfolio-programming.md) example is a more advanced one, demonstrating the versatility of the framework in adding decision variables and constraints. The [CHD Preventative Care](examples/CHD_preventative_care.md) example showcases the use of probability scaling and forbidding specific decision strategies.

DecisionProgramming.jl is developed in the [Systems Analysis Laboratory](https://sal.aalto.fi/en/) at Aalto University by *Ahti Salo*,  *Fabricio Oliveira*, *Juho Andelmin*, *Olli Herrala*, *Jaan Tollander de Balsch* and *Helmi Hankimaa*.
