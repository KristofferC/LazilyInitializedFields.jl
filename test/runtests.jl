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

@testset "mutable typevar" begin
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
end

@lazy struct ImMut{T}
    a::T
    @lazy b::Int
end
m = ImMut(1, uninit)
@testset "immutable typevar" begin
    @test_throws ErrorException m.a = 2
    @test_throws ErrorException m.b = 2
end

@lazy struct Boxed
    a::Int
    @lazy b::Float64
end
box = Boxed(1, uninit)

@lazy struct Boxed
    a::Int
    @lazy b::Float64
end
box = Boxed(1, uninit)

@testset "Boxed" begin
    @test isimmutable(box)
    @test Boxed(1, 1).b === 1.0 # test conversion constructor
    @test !(@isinit box.b)
    @init! box.b = 2
    @test @isinit box.b
    @test box.b == 2
    @uninit! box.b
    @test !(@isinit box.b)
end

@lazy struct BoxedUnion
    a::Int
    @lazy b::Union{Missing, Nothing, Int}
end
boxed_union = BoxedUnion(1, uninit)

@testset "Boxed" begin
    @test isimmutable(box)
    @test !(@isinit box.b)
    if VERSION >= v"1.2"
        @test BoxedUnion(1, 2.0).b === 2
    else
        @test_broken BoxedUnion(1, 2.0).b === 2
    end
    @init! box.b = 2
    @test @isinit box.b
    @test box.b == 2
    @uninit! box.b
    @test !(@isinit box.b)
end

@testset "misc" begin
    @test_throws LoadError @macroexpand @lazy a::Int
    @test_throws LoadError @macroexpand @lazy struct Bar end
end

doctest(LazilyInitializedFields; manual=false)
