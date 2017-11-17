# steganography of single precision float arrays

function setlast8{T}(x::T, n::UInt8)
    i = reinterpret(Unsigned, x)
    i = (i >> 8) << 8
    i = i | n
    reinterpret(T, i)
end

function setlast7{T}(x::T, n::UInt8)
    i = reinterpret(Unsigned, x)
    i = (i >> 7) << 7
    i = i | (n & 0x7f)
    reinterpret(T, i)
end

function setlastbits{T}(x::T, n::UInt8, nbits::UInt8)
    i = reinterpret(Unsigned, x)
    S = typeof(i)
    i = (i >> nbits) << nbits
    i = i | (n & ((S(1) << nbits) - S(1)))
    reinterpret(T, i)
end

getlast8{T}(x::T) = UInt8(reinterpret(Unsigned, x) & 0xff)
getlast7{T}(x::T) = UInt8(reinterpret(Unsigned, x) & 0x7f)

function getlastbits{T}(x::T, nbits::UInt8)
    i = reinterpret(Unsigned, x)
    S = typeof(i)
    return UInt8(i & ((S(1) << nbits) - S(1)))
end

function embed{N}(data::Array{Float32,N}, text::Array{UInt8,1}; ignorenonascii::Bool=true)
    @assert length(text) <= length(data)
    y = copy(data)   # make sure we have enough space
    for j in 1:length(text)
        @assert text[j] != 0x04
        if !ignorenonascii
            @assert text[j] <= 0x7f
        end
        if text[j] > 0x7f
            println(text[j], " ", Char(text[j]), " ", hex(text[j]))
            y[j] = setlast7(data[j], UInt8(0))
        else
            y[j] = setlast7(data[j], text[j])
        end
    end
    if length(text) < length(data)
        y[length(text)+1] = setlast7(data[length(text)+1], 0x04) # ASCII 0x04 means 'end of transmission'
    end
    y
end

function embed{N}(data::Array{Complex64,N}, text::Array{UInt8,1}; ina::Bool=true)
    d = size(data)
    y = reinterpret(Float32, data[:])
    y = embed(y, text; ignorenonascii=ina)
    y = reinterpret(Complex64, y[:])
    reshape(y, d)
end

function extract{N}(data::Array{Float32,N})
    s = reinterpret(UInt32, data)
    s = UInt8.(s .& 0x7f)
    n = findfirst(x -> x == 0x04, s)
    t[1:n-1]
end

function extract{N}(data::Array{Complex64,N})
    d = size(data)
    s = reinterpret(Float32, data[:])
    s = reinterpret(UInt32, s)
    s = UInt8.(s .& 0x7f)
    n = findfirst(x -> x == 0x04, s)
    println("found 0x04 at $n")
    s[1:n-1]
end
