@testset "Experimental" begin
    @static if isdefined(Base.Experimental, :register_error_hint)
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
