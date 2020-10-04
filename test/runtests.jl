using LazilyInitializedFields
const LI = LazilyInitializedFields
using Documenter

using Test
@lazy mutable struct Foo{T}
    a::T
    @lazy b::Int
    @lazy c::Union{Float64, Nothing}
    @lazy d::Union{Int, Nothing}
    e::Float64
end
f = Foo{Int}(1, uninit, 2.0, uninit, 3.0)

@lazy struct Mut{T}
    a::T
    @lazy b::Int
end
m = Mut(1, uninit)

@testset "LazilyInitializedFields" begin
    @test f.a == 1
    @test_throws UninitializedFieldException f.b
    @test f.c == 2.0
    @test_throws UninitializedFieldException f.d
    @test f.e == 3.0
    @test f.e == 3.0

    # @test map(i->@isinit(f.$i), (:a, :b, :c, :d, :e)) == (true, false, true, false, true)
    rt = Core.Compiler.return_type
    @test rt((f -> f.a), Tuple{Foo{Int}}) == Int
    @test rt((f -> f.b), Tuple{Foo}) == Int
    @test rt((f -> f.c), Tuple{Foo}) == Union{Float64, Nothing}
    @test rt((f -> f.d), Tuple{Foo}) == Union{Int, Nothing}
    @test rt((f -> f.e), Tuple{Foo}) == Float64

    @test LI.islazyfield.(Foo, (:a, :b, :c, :d, :e)) == (false, true, true, true, false)

    @test_throws NonLazyFieldException @init! f.a = 2
    @test_throws NonLazyFieldException @isinit f.a
    @test_throws NonLazyFieldException @uninit! f.a
    @init! f.c = 2.0
    @test f.c == 2.0
    @test @isinit(f.c)
    f.c = nothing
    @test f.c == nothing
    @uninit! f.c
    @test !@isinit(f.c)
    @test_throws UninitializedFieldException f.d

    @test_throws LoadError @macroexpand @lazy a::Int

    @test_throws ErrorException m.a = 2
    @test_throws ErrorException m.b = 2
end

doctest(LazilyInitializedFields; manual=false)
