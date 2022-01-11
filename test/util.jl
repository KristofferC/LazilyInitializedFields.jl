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
