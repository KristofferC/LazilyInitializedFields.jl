<!-- =============================
     ABOUT
    ============================== -->


\begin{:section, title="Lazily initialized fields", name="About"}

A lazily initialized field is a field in a struct that starts of uninitialized
(does not have a value) and at some later point gets initialized. This is useful
when the value of this field is computed on-demand (lazily).

Some goals we want to achieve when using lazy fields:

1. Accessing a lazily initialized field before it is initialized should error immediately.
2. Using a lazily initialized field does not interfere with the inferred return
   value of the field.
3. The struct should act as similar as possible to the equivalent normal struct when the struct is fully initialized.
4. Make it possible to uninitialize a field after it has been initializd if the value becomes invalidated for some reason.
5. Not force all fields to be considered mutable just because we want to lazily initialize one field.
6. Allow checking if a field is initialized.

\end{:section}

\begin{:section, title="Installation"}

```julia
using Pkg; Pkg.add(url="https://github.com/KristofferC/LazilyInitializedFields.jl")
```

\end{:section}


\begin{:section, title="Usage", name="Usage"}

Let's see a session with LazilyInitializedFields and how these goals are
fulfilled. We first define a struct with one lazily initialized field.
We then create it, using the exported `uninit` object for the field that
should be lazily initialized:

```julia-repl
julia> @lazy struct Foo
           a::Int
           @lazy b::Int
       end

julia> f = Foo(1, uninit)
Foo(1, uninit)
```

1. Accessing a lazily initialized field before it is initialized should error immediately.
  ```julia-repl
julia> f.b
ERROR: uninitialized field b
  ```

2. Using a lazily initialized field does not interfere with the inferred return value of the field.
  ```julia-repl
julia> @code_warntype (f -> f.b)(f)
Variables
#self#::Core.Compiler.Const(var"#1#2"(), false)
f::Foo

Body::Int64
1 ─ %1 = Base.getproperty(f, :b)::Int64
└──      return %1
  ```
3. The struct should act as similar as possible to the equivalent normal struct when the struct is fully initialized.
  ```julia-repl
julia> @init! f.b = 2
2

julia> f.b
2
  ```
4. Make it possible to uninitialize a field after it has been initializd if the value for example becomes invalidated.
  ```julia-repl
julia> @uninit! f.b
uninit

julia> f.b
ERROR: uninitialized field b
  ```
5. Not force all fields to be considered mutable just because we want to lazily initialize one field.

  ```julia-repl
julia> f.a = 2
ERROR: setproperty! for struct of type `Foo` has been disabled
  ```
6. Allow checking if a field is initialized.
  ```julia-repl
julia> @isinit f.b
false

julia> @init! f.b = 2
2

julia> @isinit f.b
true
  ```

Instead of the macros `@init! a.b = 1`, `@isinit a.b` and `@uninit! a.b` one can
use the function `init(a, :b, 1)`, `isinit(a, :b)` and `uninit!(a, :b)`.

\end{:section}

\begin{:section, title="Other methods of achieving lazily initialized fields", name="Other methods"}

Let's assume we want to make a struct `Foo` with two `Int` fields, and the
second field is lazily initialized. Here are some other more or less used
methods other than using LazilyInitializedFields.jl:

~~~<h4>Use a <code>::Ref{T}</code> field</h4>~~~

This does not work for `isbitstype` fields and we also need to use `[]` to
access the value, thus, failing points 1 and 3 above.

```julia-repl
julia> mutable struct Foo
           a::Int
           b::Ref{Int}
       end

julia> Foo(a) = Foo(a, Ref{Int}());

julia> f = Foo(1)
Foo(1, Base.RefValue{Int64}(4764233584))

julia> f.b
Base.RefValue{Int64}(4764233584)

julia> f.b[]
4764233584
```

~~~<h4>Make struct mutable together with <code>new</code> initialization</h4>~~~

This also does not work for `isbitstype` and for non-`isbitstype` we cannot
uninitialize the field, failing points 1, 4 and 5 above.

```julia-repl
julia> mutable struct Foo
           a::Int
           b::Int
           Foo(a) = new(a)
       end

julia> f = Foo(1)
Foo(1, 29548)

julia> f.b
29548
```

~~~<h4>Make struct mutable and use a <code>Union{T, Nothing}</code></h4>~~~

Accessing this field will not error when it is uninitialized and will infer as a
union when the field is accessed, failing points 1, 2 and 5 above.
```
julia> mutable struct Foo
           a::Int
           b::Union{Nothing, Int}
       end

julia> f = Foo(1, nothing)
Foo(1, nothing)

julia> f.b # no error

julia> @code_warntype (f -> f.b)(f)
Variables
  #self#::Core.Compiler.Const(var"#1#2"(), false)
  f::Foo

Body::Union{Nothing, Int64}
1 ─ %1 = Base.getproperty(f, :b)::Union{Nothing, Int64}
└──      return %1
```

\end{:section}

\begin{:section, title="Caveats"}

When applying `@lazy` to a non-mutable struct, the standard way of mutating it
via `setproperty!` (the `f.a = b` syntax)  is disabled. However, the struct is
still considered mutable to Julia and the `setproperty!` can be bypassed:

```julia-repl
julia> @lazy struct Foo
           a::Int
           @lazy b::Int
       end

julia> f = Foo(1, uninit)
Foo(1, uninit)

julia> f.a = 2
ERROR: setproperty! for struct of type `Foo` has been disabled
[...]

julia> setfield!(f, :a, 2)
2

julia> f.a
2
```

The fact that the struct is considered mutable by Julia also means that it will
no longer be stored inline in cases where the non `@lazy` version would:

```julia-repl
julia> isbitstype(Foo)
false
```

This has an effect if you would try to pass a `Vector{Foo}` to e.g. C via `ccall`.

\end{:section}

\begin{:section, title="Implementation"}

The expression 

```julia
@lazy struct Foo
   a::Int
   @lazy b::Int
end
```

expands to three or four parts (in the case where the struct is non-mutable). To
make the code below runnable, we define the type `Uninitialized` that in reality lives
inside `LazilyInitializedFields`:

```
struct Uninitialized end
const uninit = Uninitialized()
```

The first part of the expanded macro is the struct definition:

```julia
mutable struct Foo
    a::Int
    b::Union{Uninitialized, Int}
end
```

This allows us to store a custom sentinel singleton that always signals an
undefined value. The struct has also been made mutable since otherwise we cannot
change the uninitialized value. The second part is to extend a method in
LazilyInitializedFields that can be used to query what fields are lazy:

```julia
islazyfield(::Type{<:Foo}, s::Symbol) = s === :b
```

The third part is `getproperty` overloading:

```julia
function Base.getproperty(f::Foo, s::Symbol)
    if islazyfield(Foo, s)
        r = getfield(f, s)
        r isa Uninitialized && error("uninitialized field b")
        return r
    end
    return getfield(f, s)
end
```

This makes sure that accessing an uninitialized field errors *and* that type
inference knows that the return value is exactly an `Int`. Since the struct was
originally non-mutable, we also turn off `setproperty!` via:

```julia
function Base.setproperty!(x::Foo, s::Symbol, v)
    error("setproperty! for struct of type `Foo` has been disabled")
end
```

The convenience macros `@init!`, `@uninit!`, `@isinit` does very simple
transformations that checks that the field being manipulated is lazy (via
`islazyfield`) and converts `getproperty` and `setproperty!` to `getfield` and
`setfield!`.

\end{:section}
