
using RawArray
using Base.Test

function test_wr(t, dims; compress=false)
  testfile = "tmp.ra"
  n = length(dims)
  print("Testing $n-d $t $(compress ? "compressed" : "uncompressed") ... ")
  data = rand(t, dims...)
  rawrite(data, testfile; compress=compress)
  data2 = raread(testfile)
  @test isequal(data, data2)
  rm(testfile)
  println("PASS")
end

typelist = [Float16, Float32, Float64, Complex32, Complex64, Complex128, Int8, Int16, Int32, Int64, UInt8, UInt16, UInt32, UInt64]
maxdims = 4
for t in typelist, n in 1:maxdims
  test_wr(t, collect(2:n+1))
  if t <: Integer
    test_wr(t, collect(2:n+1); compress=true)
  end
end
