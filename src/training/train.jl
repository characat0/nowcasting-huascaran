using Flux
using Flux.Optimise
using ProgressMeter

const PROGRESS_BAR_LENGTH = 65

function train_single_epoch!(ps, loss, data, opt; cb=() -> ())
  cb = Optimise.runall(cb)
  itrsz = Base.IteratorSize(typeof(data))
  n = (itrsz == Base.HasLength()) || (itrsz == Base.HasShape{1}()) ? length(data) : 0
  p = Progress(n; showspeed=true, enabled=!iszero(n), barlen=PROGRESS_BAR_LENGTH)
  for (X, y) in data
    try
      gs = Flux.gradient(ps) do
        loss(X, y)
      end
      Flux.update!(opt, ps, gs)
      cb();
    catch ex
      rethrow()
    finally
      ProgressMeter.next!(p)
    end
  end
end

function loss_single_epoch(loss, data)
  losses = Float64[]
  itrsz = Base.IteratorSize(typeof(data))
  n = (itrsz == Base.HasLength()) || (itrsz == Base.HasShape{1}()) ? length(data) : 0
  sizehint!(losses, n)
  p = Progress(n; showspeed=true, enabled=!iszero(n), barlen=PROGRESS_BAR_LENGTH)
  for (X, y) in data
    push!(losses, loss(X, y))
    ProgressMeter.next!(p)
  end
  losses
end



function metrics_single_epoch(model, metrics, data)
  metrics_dict = Dict{Symbol, Vector{Float64}}()
  itrsz = Base.IteratorSize(typeof(data))
  n = (itrsz == Base.HasLength()) || (itrsz == Base.HasShape{1}()) ? length(data) : 0
  p = Progress(n; showspeed=true, enabled=!iszero(n), barlen=PROGRESS_BAR_LENGTH)
  for (X, y) in data
    Flux.reset!(model)
    y_pred = cpu(model(X))
    for metric in metrics
      m = metric(y_pred, y)
      if (m isa NamedTuple) || (m isa Dict)
        for (k, v) in pairs(m)
          key = Symbol(metric, k)
          push!(get!(metrics_dict, key, Float64[]), v)
        end
      else
        push!(get!(metrics_dict, Symbol(metric), Float64[]), m)
      end
    end
    ProgressMeter.next!(p)
  end
  Dict(k => mean(v) for (k,v) in metrics_dict)
end