using LazilyInitializedFields
const LI = LazilyInitializedFields
using Documenter

@show typeof(stdout)
@show typeof(stderr)

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

# A utility function that takes in a closure, and returns the exception that is thrown when
# that closure is run.
function get_thrown_exception(f::Function)
    threw = false
    ex = try
        f()
    catch ex
        threw = true
        ex
    end
    threw || throw(ErrorException("no exception was thrown"))
    return ex
end

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
    @init! f.b = 2
    @test_throws AlreadyInitializedException @init! f.b = 2.0

    @test_throws AlreadyInitializedException @init! f.c = 2.0
    @test @isinit(f.c)
    f.c = nothing
    @test f.c == nothing
    @uninit! f.c
    @test !@isinit(f.c)
    @test_throws UninitializedFieldException f.d

    @static if Base.VERSION >= v"1.7-"
        # On Julia 1.7+, `@macroexpand` will throw the actual exception type.
        @test_throws ErrorException @macroexpand @lazy a::Int
    else
        # On Julia 1.6 and earlier, `@macroexpand` will always throw `LoadError`,
        # regardless of the actual exception type.
        @test_throws LoadError @macroexpand @lazy a::Int
    end

    @test_throws ErrorException m.a = 2
    @test_throws ErrorException m.b = 2

    @testset "Experimental" begin
        @static if isdefined(Base, :Experimental) && isdefined(Base.Experimental, :register_error_hint)
            @lazy struct FooExperimental
                @lazy a::Int
                @lazy b::Int
                @lazy c::Int
            end
            FooExperimental() = FooExperimental(uninit, uninit, uninit)

            Base.Experimental.register_error_hint(UninitializedFieldException) do io, exc
                if exc.T === FooExperimental
                    if exc.s === :b
                        print(io, "\nThis is a custom hint for the `:b` field of the `Foo` struct")
                    elseif exc.s === :c
                        print(io, "\nHere's my `Foo.c` custom hint")
                    end
                end
            end

            test_cases = [
                (:a, "field `a` in struct of type `FooExperimental` is not initialized",),
                (:b, "field `b` in struct of type `FooExperimental` is not initialized\nThis is a custom hint for the `:b` field of the `Foo` struct",),
                (:c, "field `c` in struct of type `FooExperimental` is not initialized\nHere's my `Foo.c` custom hint",),
            ]
            for (s, msg) in test_cases
                my_closure = () -> getproperty(FooExperimental(), s)
                @test_throws UninitializedFieldException my_closure()
                ex = get_thrown_exception(my_closure)
                @test sprint(io -> Base.showerror(io, ex)) == msg
            end
        else
            @warn "Skipping the experimental tests"
            @test_skip false
        end
    end
end

DocMeta.setdocmeta!(LazilyInitializedFields, :DocTestSetup, :(using LazilyInitializedFields))
doctest(LazilyInitializedFields; manual=false)
