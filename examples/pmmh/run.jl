include("model.jl")


# particle marginal metropolis-hastings

@gen (static) function var_proposal(prev)
    var_x::Float64 = get_choices(prev)[:var_x]
    var_y::Float64 = get_choices(prev)[:var_y]
    #@trace(normal(var_x, sqrt(0.15)), :var_x)
    #@trace(normal(var_y, sqrt(0.08)), :var_y)
    @trace(normal(var_x, sqrt(0.5)), :var_x)
    @trace(normal(var_y, sqrt(0.5)), :var_y)
end

@gen function observer(ys)
    for (i, y) in enumerate(ys)
        @trace(dirac(y), :hmm => :y => i)
    end
end

load_generated_functions()



##########
function strip_lineinfo(expr::Expr)
    @assert !(expr.head == :line)
    new_args = []
    for arg in expr.args
        if (isa(arg, Expr) && arg.head == :line) || isa(arg, LineNumberNode)
        elseif isa(arg, Expr) && arg.head == :block
            stripped = strip_lineinfo(arg)
            append!(new_args, stripped.args)
        else
            push!(new_args, strip_lineinfo(arg))
        end
    end
    Expr(expr.head, new_args...)
end

function strip_lineinfo(expr)
    expr
end

println("\n######################################################################\n")
obs = get_choices(simulate(obs_sub, (1.2,)))
import InteractiveUtils
    InteractiveUtils.code_warntype(
        generate,
        (typeof(kernel), Tuple{Int,State,Params}, typeof(obs), Nothing))
println("\n######################################################################\n")





function initial_collapsed_trace(ys)
    T = length(ys)
    constraints = get_choices(simulate(observer, (ys,)))
    (trace, weight) = generate(model_collapsed, (T,), constraints)
    trace
end

import Random
Random.seed!(1)

# generate synthetic dataset
T = 100 # was 500
(xs_sim, ys_sim) = hmm(10., 1., T)

# do inference
function do_inference(n)
    trace = initial_collapsed_trace(ys_sim)
    for iter=1:n
        score = get_call_record(trace).score
        println("score: $score")
        (trace, _) = metropolis_hastings(trace, var_proposal, ())
        choices = get_choices(trace)
	    println("var_x: $(choices[:var_x]), var_y: $(choices[:var_y])")
    end
end

import Profile

@time do_inference(2)
@time do_inference(100)

#Profile.@profile do_inference(17)

#Profile.print(format=:flat, sortedby=:count)
#Profile.print(mincount=10)
