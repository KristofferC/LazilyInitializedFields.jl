using BenchmarkTools
using LazilyInitializedFields
import Random
import StableRNGs

const rng = StableRNGs.StableRNG(0)
randstring(args...) = Random.randstring(rng, args...)
rand(args...) = Random.rand(rng, args...)

const SUITE = BenchmarkGroup()
const N = 10^6

mutable struct NormalMutable
    x::Float64
    y::Float64
end
const normal_mutables = [NormalMutable(rand(Float64), rand(Float64)) for i in 1:N]

@lazy mutable struct Mutable
    x::Float64
    @lazy y::Float64
end
const mutables = [Mutable(rand(Float64), rand(Float64)) for i in 1:N]

struct NormalImmutable
    x::Float64
    y::Float64
end
const normal_immutables = [NormalImmutable(rand(Float64), rand(Float64)) for i in 1:N]

@lazy struct Immutable
    x::Float64
    @lazy y::Float64
end
const immutables = [Immutable(rand(Float64), rand(Float64)) for i in 1:N]

@lazy struct ImmutableType{T}
    x::T
    @lazy y::Float64
end
const immutables_type = [ImmutableType(rand(Float64), rand(Float64)) for i in 1:N]

function perf_sum_eager(X)
    s = 0
    @simd for v in X
        s += v.x
    end
    return s
end

function perf_sum_lazy(X)
    s = 0.0
    for v in X
        s += v.y
    end
    return s
end

SUITE["normal mutable - eager"]   = @benchmarkable perf_sum_eager($normal_mutables)
SUITE["mutable - eager"]          = @benchmarkable perf_sum_eager($mutables)
SUITE["normal immutable - eager"] = @benchmarkable perf_sum_eager($normal_immutables)
SUITE["immutable - eager"]        = @benchmarkable perf_sum_eager($immutables)
SUITE["immutable_type - eager"]   = @benchmarkable perf_sum_eager($immutables_type)

SUITE["normal mutable - lazy"]   = @benchmarkable perf_sum_lazy($normal_mutables)
SUITE["mutable - lazy"]          = @benchmarkable perf_sum_lazy($mutables)
SUITE["normal immutable - lazy"] = @benchmarkable perf_sum_lazy($normal_immutables)
SUITE["immutable - lazy"]        = @benchmarkable perf_sum_lazy($immutables)
SUITE["immutable_type - lazy"]   = @benchmarkable perf_sum_lazy($immutables_type)
