include("../src/stego.jl")

using Base.Test
n = 1024
R = rand(Float32, n)
U = rand(UInt8, n)
for j in 1:n
    r = setlast8(R[j], U[j])
    s = setlastbits(R[j], U[j], UInt8(8))
    u = setlast7(R[j], U[j])
    v = setlastbits(R[j], U[j], UInt8(7))
    @test r == s
    @test u == v
    @test getlast8(u) == getlastbits(u, UInt8(8))
    @test getlast7(u) == getlastbits(u, UInt8(7))
end
