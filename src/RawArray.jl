# This file is part of the RawArray package (http://github.com/davidssmith/RawArray.jl).
#
# The MIT License (MIT)
#
# Copyright (c) 2016 David Smith
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

__precompile__()

module RawArray

using LittleEndianBase128

export raquery, raread, rawrite

const version = v"0.0.2"

FLAG_BIG_ENDIAN = UInt64(1<<0)
FLAG_COMPRESSED = UInt64(1<<1)

ALL_KNOWN_FLAGS = FLAG_BIG_ENDIAN | FLAG_COMPRESSED

MAX_BYTES = UInt64(1<<31)
MAGIC_NUMBER = UInt64(0x7961727261776172)

TYPE_NUM_TO_NAME = Dict(
  0 => "user",
  1 => "Int",
  2 => "UInt",
  3 => "Float",
  4 => "Complex"
)
TYPE_NAME_TO_NUM = Dict(
  "user" => 0,
  Int8 => 1,
  Int16 => 1,
  Int32 => 1,
  Int64 => 1,
  Int128 => 1,
  UInt8 => 2,
  UInt16 => 2,
  UInt32 => 2,
  UInt64 => 2,
  UInt128 => 2,
  Float16 => 3,
  Float32 => 3,
  Float64 => 3,
  Complex32 => 4,
  Complex64 => 4,
  Complex128 => 4,
  Complex{Float32} => 4,
  Complex{Float64} => 4
  )

#  header is 40 + 8*ndims bytes long
type RAHeader
  flags::UInt64  # file properties, such as endianness and future capabilities
  eltype::UInt64   # enum representing the element type in the array
  elbyte::UInt64    # enum representing the element type in the array
  size::UInt64   # size of data in bytes (may be compressed: check 'flags')
  ndims::UInt64  # number of dimensions in array
  dims::Vector{UInt64}
end

import Base.size
size(h::RAHeader) = sizeof(UInt64)*(5 + h.ndims)

function getheader(io::IOStream)
  magic, flags, eltype, elbits, size, ndims = read(io, UInt64, 6)
  dims = read(io, UInt64, ndims)
  return RAHeader(flags,eltype,elbits,size,ndims,dims)
end

# print the file header as YAML
function raquery(path::AbstractString)
  q = AbstractString[]
  push!(q, "---\nname: $path")
  fd = open(path,"r")
  h = getheader(fd)
  close(fd)
  juliatype = eval(parse(TYPE_NUM_TO_NAME[h.eltype]*"$(h.elbyte*8)"))
  endian = (h.flags & FLAG_BIG_ENDIAN) != 0 ? "big" : "little"
  assert(endian == "little") # big not implemented yet
  push!(q, "endian: $endian")
  push!(q, "compressed: $(h.flags & FLAG_COMPRESSED)")
  push!(q, "type: $juliatype")
  push!(q, "size: $(h.size)")
  push!(q, "dimension: $(h.ndims)")
  push!(q, "shape:")
  for j = 1:h.ndims
    push!(q, "  - $(h.dims[j])")
  end
  push!(q, "...")
  join(q, "\n")
end

function raread(path::AbstractString)
  fd = open(path, "r")
  h = getheader(fd)
  dtype = eval(parse("$(TYPE_NUM_TO_NAME[h.eltype])$(h.elbyte*8)"))
  if (h.flags & ~ALL_KNOWN_FLAGS) != 0
    warn("This RA file must have been written by a newer version of this code.")
    warn("Correctness of input is not guaranteed. Update your version of the")
    warn("RawArray package to stop this warning.")
  end
  if h.flags & FLAG_COMPRESSED != 0
    dataenc = Array{UInt8}(stat(path).size - size(h))
    nb = readbytes!(fd, dataenc; all=true)
    dataenc = dataenc[1:nb]
    data = reshape(decode(dataenc, dtype, prod(h.dims)), map(signed, h.dims)...)
  else
    data = read(fd, dtype, round(Int,h.size/sizeof(dtype)))
    data = reshape(data, [Int64(d) for d in h.dims]...)
  end
  close(fd)
  return data
end

function rawrite{T,N}(a::Array{T,N}, path::AbstractString; compress=false)
  flags = UInt64(0)
  if ENDIAN_BOM == 0x01020304
    flags |=  FLAG_BIG_ENDIAN
  end
  fd = open(path, "w")
  if compress && issubtype(T, Integer)
    flags |= FLAG_COMPRESSED
  elseif compress
    error("Can only compress Integer data. Continuing uncompressed.")
  end
  write(fd, MAGIC_NUMBER, flags,
    UInt64(TYPE_NAME_TO_NUM[T]),
    UInt64(sizeof(T)),
    UInt64(length(a)*sizeof(eltype(a))),
    UInt64(ndims(a)),
    UInt64[d for d in size(a)])
  if flags & FLAG_COMPRESSED != 0
    write(fd, encode(a))
  else
    write(fd, a)
  end

  close(fd)
end

end
