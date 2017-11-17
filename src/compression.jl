

"""
    bitmask32(idxs)

    Returns a 32-bit bitmask with bits in positions `idxs` set to 1.
"""
function bitmask32(idxs::UnitRange{Int64})
    mask = UInt32(0)
    for k in idxs
        mask |= (UInt32(1) << (k-1))
    end
    mask
end
bitmask32(k::Int64) = UInt32(1) << (k-1)


function bitmask64(idxs::UnitRange{Int64})
    mask = UInt64(0)
    for k in idxs
        mask |= (UInt64(1) << (k-1))
    end
    mask
end
bitmask64(k::Int64) = UInt64(1) << (k-1)


const F32_FRAC_MASK = bitmask32(1:23)
const F32_EXP_MASK = bitmask32(24:31)
const F32_SIGN_MASK = bitmask32(32)
@assert (F32_SIGN_MASK | F32_EXP_MASK | F32_FRAC_MASK) == 0xffffffff

const F64_FRAC_MASK = bitmask64(1:52)
const F64_EXP_MASK = bitmask64(53:63)
const F64_SIGN_MASK = bitmask64(64)
@assert (F64_SIGN_MASK | F64_EXP_MASK | F64_FRAC_MASK) == 0xffffffffffffffff

function ieeebits(x::Float32)
    b = bits(x)
    (b[1], b[2:9], b[10:end])
end
function ieeebits(x::Float64)
    b = bits(x)
    (b[1], b[2:12], b[13:end])
end
function ieeebits(x::Float16)
    b = bits(x)
    (b[1], b[2:6], b[7:end])
end

function ieeebits(x; offset::Int=0)
    b = Char[c for c in bits(x)]
    b = circshift(b, offset)
    b[1:offset] = '0'
    if sizeof(x) == 4
        "$(b[1]) | $(join(b[2:9])) | $(join(b[10:end]))"
    elseif sizeof(x) == 8
        "$(b[1]) | $(join(b[2:12])) | $(join(b[13:end]))"
    elseif sizeof(x) == 2
        "$(b[1]) | $(join(b[2:6])) | $(join(b[7:end]))"
    end
end

#
# Float32 functions
#

function squash(x::Float32, expbits::Int64, fracbits::Int64)
    u = reinterpret(UInt32, x)
    s = u & F32_SIGN_MASK
    q = u & F32_EXP_MASK
    f = u & F32_FRAC_MASK
    f = f >> (23 - fracbits)
    q = q >> 23
    #@assert q <= (1 << expbits)   # truncating an exponent is bad, mmkay
    q -= UInt32(127)  # debias so truncation works properly
    q = q & bitmask32(1:expbits)
    q = q << fracbits
    s = s >> ((23 - fracbits) + (8 - expbits))
    u = s | q | f
    u
end

function squash(x::Float64, expbits::Int64, fracbits::Int64)
    u = reinterpret(UInt64, x)
    s = u & F64_SIGN_MASK
    q = u & F64_EXP_MASK
    f = u & F64_FRAC_MASK
    f = f >> (52 - fracbits)
    q = q >> 52
    #@assert q <= (1 << expbits)   # truncating an exponent is bad, mmkay
    q -= UInt64(1023)  # debias so truncation works properly
    q = q & bitmask64(1:expbits)
    q = q << fracbits
    s = s >> ((52 - fracbits) + (11 - expbits))
    u = s | q | f
    u
end

# function squash(x::Complex64, expbits, fracbits)
#     r = squash(real(x), expbits, fracbits)  # each is UInt32
#     i = squash(imag(x), expbits, fracbits)
#     UInt64((UInt64(r) << (1+expbits+fracbits)) | i)
# end

function unsquash(x::UInt32, expbits::Int, fracbits::Int)
    s = x & bitmask32(expbits + fracbits + 1)
    q = x & bitmask32(fracbits + 1:fracbits + expbits)
    f = x & bitmask32(1:fracbits)
    q = q >> fracbits
    q = q + UInt32(127) #- Int32(1 << (expbits-1)) - 1
    q = q << fracbits
    try
        f = f << (23 - fracbits)
        q = q << (23 - fracbits)
        s = s << ((23 - fracbits) + (8 - expbits))
    catch InexactError
        println("InexactError> ")
        println("    x: $x ", bits(x))
        println("    s: $s ", bits(s))
        println("    q: $q ", bits(q))
        println("    f: $f ", bits(f))
        throw(InexactError)
    end
    reinterpret(Float32, s | q | f)
end

function unsquash(x::UInt64, expbits, fracbits)
    s = x & bitmask64(expbits + fracbits + 1)
    q = x & bitmask64(fracbits + 1:fracbits + expbits)
    f = x & bitmask64(1:fracbits)
    q = q >> fracbits
    q = q + UInt32(1023) #- Int32(1 << (expbits-1)) - 1
    q = q << fracbits
    try
        f = f << (52 - fracbits)
        q = q << (52 - fracbits)
        s = s << ((52 - fracbits) + (11 - expbits))
    catch InexactError
        println("InexactError> ")
        println("    x: $x ", bits(x))
        println("    s: $s ", bits(s))
        println("    q: $q ", bits(q))
        println("    f: $f ", bits(f))
        throw(InexactError)
    end
    reinterpret(Float64, s | q | f)
end

# function squash{N}(x::Array{Float32,N}, expbits, fracbits)
#     # find smallest non-zero abs
#     y = sort(abs.(x))
#     scale = y[findfirst(y)]
#     y = x / scale
#     (squash.(y, expbits, fracbits), scale)
# end
#
# function unsquash{N}(x::Array{UInt32,N}, expbits, fracbits, scale)
#     # find smallest non-zero abs
#     y = unsquash.(x, expbits, fracbits)
#     y * scale
# end


# """
#     intpack(t, x; p=0, q=1)
#
#     Pack floats into integers of type `t` using the
#     full range of the type: [0, typemax(t)]
#
#     Minimum precision can be specified as number of bits `p` to preserve in fraction of smallest representable value], although this is probably
#     not the most accurate setting.
#
#     An additional power-law rescaling can be applied through the exponent `q`.
#
#     A signed integer type is recommended for most applications.
# """
function intpack{T,N}(t::Type, x::Array{T,N}; q=1, rescale=false, lo=0, hi=0)
    z = zeros(t, size(x))
    if hi == 0
        A = rescale ? typemax(t) : 1
    else
        A = hi
    end
    y = abs.(x)
    if rescale
        xl = minimum(y)
        xh = maximum(y)
    else
        xl = 0
        xh = 1
    end
    for k in 1:length(x)
        s = sign(x[k])
        y[k] = (y[k] - xl) / (xh - xl) # normalize y to [0,1] float interval
        if q != 1
            y[k] = y[k]^q
        end
        z[k] = round(t, s*y[k]*A)
    end
    (z, xl, xh)
end


function intpack{N}(t::Type, x::Array{Complex64,N};
    q=1, rescale=false, lo=0, hi=0)

    z, lo, hi = intpack(t, reinterpret(Float32, x[:]); q=q, rescale=rescale, lo=lo, hi=hi)
    d = [j for j in size(x)]
    d[1] *= 2
    return (reshape(z, d...), lo, hi)
end

function intpack{N}(t::Type, x::Array{Complex128,N};
    q=1, rescale=false, lo=0, hi=0)

    z, lo, hi = intpack(t, reinterpret(Float64, x[:]); q=q, rescale=rescale, lo=lo, hi=hi)
    d = [j for j in size(x)]
    d[1] *= 2
    return (reshape(z, d...), lo, hi)
end

function intunpack{T,N}(t::Type, z::Array{T,N}, xl, xh; q=1)
    if t <: Complex && sizeof(t) == 8  # Complex64
        tt = Float32
    elseif t <: Complex && sizeof(t) == 16 # Complex128
        tt = Float64
    else
        tt = t
    end
    y = zeros(tt, size(z))
    if xl == 0 && xh == 1
        y = tt.(z)
    else
        for k in 1:length(z)
            s = z[k] == 0 ? 1 : sign(z[k])
            u = abs(z[k]) / typemax(T)
            if q != 1
                u = u^(1/q)
            end
            u = u*(xh - xl) + xl
            y[k] = u * s
        end
    end
    if t <: Complex
        x = reinterpret(t, y[:])
        d = [j for j in size(z)]
        d[1] /= 2
        return reshape(x, d...)
    end
    y
end
