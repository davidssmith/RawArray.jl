include("../src/compression.jl")

n = 1024
R = rand(Float32, n)

E = 8
F = 23
for j in 1:n, f in F:-1:1
    y = unsquash(squash(R[j], E, f), E, f)
    @test y < R[j]
end


squash(x::Array{Float32,N}, expbits, fracbits)

unsquash(x::Array{UInt32,N}, expbits, fracbits, scale)

for j in 1:n, f in F:-1:1
    Y, lo, hi = intpack(Int16, R; rescale=true)
    T = intunpack(Float32, Y, lo, hi)
    @test T .== R
end

intpack(t::Type, x::Array{Float32,N}; q=1, rescale=false, lo=0, hi=0)

intpack(t::Type, x::Array{Complex{Float32},N}; q=1, rescale=false, lo=0, hi=0)

intunpack(t::Type, z::Array{T,N}, xl, xh; q=1)
