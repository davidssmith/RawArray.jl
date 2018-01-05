
include("../src/RawArray.jl")
using .RawArray

using Base.Test

function test_wr(t, dims; compress=false)
  testfile = "tmp.ra"
  n = length(dims)
  data = rand(t, dims...)
  RawArray.rawrite(data, testfile; compress=compress)
  data2 = RawArray.raread(testfile)
  rm(testfile)
  @test isequal(data, data2)
end

#
# Header query
#
@testset "raquery" begin
    s = RawArray.raquery("../examples/test.ra")
    @test s == "---\nname: ../examples/test.ra\nendian: little\ncompressed: 0\ntype: Complex{Float32}\nsize: 96\ndimension: 2\nshape:\n  - 3\n  - 4\n..."
end

#
# Reading and writing files
#
typelist = [Float16, Float32, Float64, Complex32, Complex64, Complex128, Int8, Int16, Int32, Int64, UInt8, UInt16, UInt32, UInt64]
maxdims = 4
@testset "read/write" begin
    @testset "$n-d $t $(c?"":"un")compressed" for t in typelist,
        n in 1:maxdims, c in [false, true]
        test_wr(t, collect(2:n+1); compress=c)
    end
end

#
# Compression
#
n = 1024

@testset "compression" begin
    R = rand(Float32, n)
    E = 8
    F = 23
    @testset "squash Float32 to $f bit significand" for f in F:-1:1
        y = unsquash.(squash.(R, E, f), E, f)
        @test all(y .< R)
    end
    @testset "compress Float32 as Int16 ... " begin
        Y, lo, hi = intpack(Int16, R; rescale=true)
        T = intunpack(Float32, Y, lo, hi)
        @test T ≈ R
    end

    R = rand(Float64, n)
    E = 11
    F = 52
    @testset "squash Float64 to $f bit significand" for f in F:-1:1
        y = unsquash.(squash.(R, E, f), E, f)
        @test all(y .< R)
    end
    @testset "compress Float64 as Int32" begin
        Y, lo, hi = intpack(Int32, R; rescale=true)
        T = intunpack(Float64, Y, lo, hi)
        @test T ≈ R
    end

    @testset "compress Float64 as Int32 ... " begin
        Y, lo, hi = intpack(Int16, R; rescale=true)
        T = intunpack(Float64, Y, lo, hi)
        @test T ≈ R atol=1e-2
    end

end

@testset "steganography" begin
    @testset "$S in $T" for S in [UInt8], T in [Float32, Float64]
        n = 1024
        R = rand(T, n)
        U = rand(S, n)
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
    end
end
