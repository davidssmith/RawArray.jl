Welcome to the RawArray.jl package!
===========================

[![Build Status](https://travis-ci.org/davidssmith/RawArray.jl.png?branch=master)](https://travis-ci.org/davidssmith/RawArray.jl)
[![Build
status](https://ci.appveyor.com/api/projects/status/8d0t2jm2c6ak69gy?svg=true)](https://ci.appveyor.com/project/davidssmith/rawarray-jl)



Introduction
------------

RawArray (RA) is a simple file format for storing n-dimensional arrays. RA stands for **raw array**
and should be pronounced *arr-ay*, although it is not a coincidence that the
mispronunciation *rah* (as in "raw" in some dialects) also makes sense.

RA was designed to be portable, fast, and storage
efficient. For scientific applications in particular, it can allow the simple
storage of large arrays without a separate header file to store the
dimensions and type metadata. 

I believe the world doesn't need another hierarchical data container. We already have one of 
those---it's called a filesystem. What is needed is a simple one-to-one mapping of data structures to disk files that preserves metadata and is fast and simple to read and write.

In addition to int, uint, and float of arbitrary sizes, RA also supports

(1) **complex floats**: which other common formats, such as HDF5, don't have.

(2) **composite types**: RA handles reading and writing these, but the encoding and decoding of those is left to the user, since only they can know the structure of their `struct`. Decoding can be as simple as a typecast, however, for types of fixed size.

As an aside, the RA format is technically recursive (or fractal?!). You could store an array of RA files in a RA file if you want by defining the file as a composite type.

Format
-----------

The file format is a simple concatenation of a header array and a data array. The header is made up of at least seven 64-bit unsigned integers. The array data is whatever you want it to be. Optionally text or binary metadata can be appended to the end of the file with no harmful effects, but this data is not saved or written back out by the library. It is up to you to keep track of it.

### File Structure

| offset (bytes) | object | type           | meaning 
|----------------|--------|----------------|---------
|                |        |                | **HEADER**	
| 0              | magic  | UInt64         | magic number
| 8              | flags  | UInt64         | endianness, future options
| 16             | eltype | UInt64         | element type code
| 24             | elbyte | UInt64         | element size in bytes
| 32             | size   | UInt64         | data segment length in bytes
| 40             | ndims  | UInt64         | number of array dimensions
| 48             | dims   | Vector{UInt64} | array dimensions
| 48 + 8 x ndims | data   | Vector{UInt8}  | **ARRAY DATA**
| 48 + 8 x ndims + size | - | -             | **VOLATILE METADATA**

### Elemental Type Specification

| code | type
| ---- | ----
| 0    | user-defined
| 1    | signed integer
| 2    | unsigned integer
| 3    | floating point (IEEE-754 standard)
| 4    | complex float (pairs of IEEE floats)

The width of these types is defined separately in the `elbyte` field. For example, 

* a 32-bit unsigned integer would be `eltype = 2`, `elbyte = 4`;
* a single-precision complex float (pairs of 32-bit floats) would be `eltype = 4`, `elbyte = 8`;
* a string would be `eltype = 2`, `elbyte = 1`, and `size` would contain the length of the string.

The user-defined structure

```
struct foo {
   char info[12];
   uint32_t index;
   double v[8];
}
``` 

contains a 12-byte string, a 4-byte int, and 8 8-byte floats, so the total size is 80 bytes. It would be coded as `eltype = 0`, `elbyte = 80`.

The data is written and read as the binary representation of the hardware you are on. Right now **little endian is assumed**, but big endian support can be added if there is interest.

### Memory Order

The RA format is **column major**, so the first dimension will be the fastest varying one in memory. This decision was made because the majority of scientific languages are traditionally column major, and although C is technically row major it is actually agnostic in applications where multi-dimensional arrays are accessed through computed linear indices (e.g. CUDA).  Of the supplied examples, all are column major except Python. In the case of Python, instead of reading the array into Python and reordering to non-optimal stride, we simply transpose the dimensions before writing and after reading. This means the array looks transposed in Python, but the same dimensions have the same strides in all languages. In other words, the last dimension of the array in Python will be the first one in Julia and Matlab.



File Introspection
------------------
To get a better handle on the format of an RA file, let's look inside one. If you are on a Unix system or have Cygwin installed on Windows, you can examine the contents of an RA file using command line tools.  For this section, we will use the `test.ra` file provided in the `examples/` subdirectory. 

First, let's pretend you don't know the dimensionality of the array. Then


```
> od -t uL -N 48 test.ra
0000000              8746397786917265778              0
0000020              4                                8
0000040              96                               2
0000060

```

shows the dimension (2) as the second number on the third line. The command is extracting the first 48 bytes and formatting them as UInt64s. The ridiculous number listed first is the magic number indicating that this is an RA file. A slightly different command illuminates that:

```
> od -a -N 16 test.ra
0000000    r   a   w   a   r   r   a   y nul nul nul nul nul nul nul nul
0000020
```

Armed with the knowledge that the array is 2D, we know that the header is `48 + 2*8 = 64` bytes long. The command to skip the header and view only the data would be:

```
> od -j 64 -f test.ra
0000100     0.000000e+00            -inf    1.000000e+00   -1.000000e+00
0000120     2.000000e+00   -5.000000e-01    3.000000e+00   -3.333333e-01
0000140     4.000000e+00   -2.500000e-01    5.000000e+00   -2.000000e-01
0000160     6.000000e+00   -1.666667e-01    7.000000e+00   -1.428571e-01
0000200     8.000000e+00   -1.250000e-01    9.000000e+00   -1.111111e-01
0000220     1.000000e+01   -1.000000e-01    1.100000e+01   -9.090909e-02
0000240
```

Here we are using `-j` to skip the first 64 bytes and `-f` to format the byte data as single-precision floats. Note `od` doesn't understand complex numbers, but the complex data is stored as real and imaginary float pairs that are contiguous on disk. This means that each line of the output is showing two complex numbers with columns 1 and 3 the real parts and columns 2 and 4 the imaginary parts. Notice that it correctly renders the negative infinity.

Getting
-------

You can clone the git repository from inside Julia with

```
Pkg.add("RawArray")
```

Usage
-----

To use RawArray, simply add the following line to your file:

```
using RawArray
```

Now you can call `raread` and `rawrite` for Julia objects of type `Array{T,N}`.

A test file called `test/runtests.jl` has been included, as well as a demo RA file in `examples/test.ra`.  You can test the code on your machine at the command line by running `julia runtests.jl`. If the tests pass, you'll get a message saying so.

Notice the Julia version also contains a `raquery()` function that produces a YAML dump of the file header.

Getting Help
------------

For help, file an issue on the [bug tracker](http://github.com/davidssmith/RawArray.jl/issues) or email one of the authors.  Third party help is welcome and can be contributed through pull requests.

Authors
-------
David S. Smith [<david.smith@gmail.com>](mailto:david.smith@gmail.com)

Disclaimer
----------
This code comes with no warranty. Use at your own risk. If it breaks, let us know, and we'll try to help you fix it.

