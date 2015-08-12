# CachedNDArray - MAtlab N-dimensional array with caching possiblity

## Short description  

CachedNDArray - data structure that allows to deal with large N-dimensional arrays through caching method: 
* Allows to avoid Matlab out of memory error by caching large array into several files on hard disk and then reading the necessary chunks using memmapfile function. 
* The data structure is inhereted from handle abstract class which avoids parameter-by-value and supports parameter-by-reference. 
* Supports two types of movements - continious (very slow) and discrete (fast); the former might have no more than two file to represent a chunk; while the latter means the data is processed chunk-after-chunk, and each chunk is represented strictly as a single file.  
* Caching flag can be set to either manual or automatic mode. If no caching is needed to perform, the CachedNDArray is treated like a normal Matlab array.
* Automatic or manual dimension breakage into number of chunks.

## Quick start

## Class description, specifics and usage

#### Main principle behind the caching through Matlab

#### Discreet vs. continious caching

#### Interface signatures  

To create a CachedNDArray variable, it is necessary to use the constructor, e.g:  
```
cnda = CachedNDArray(dimensions, type, broken, var_name, work_path, nchunks, fcaching, fdiscreet, ini_val);
```  
where  
* `dimensions` - is the vector of form `[dim_1 dim_2 ... dim_n]` that defines the size of each array dimension.  
* `type` - is a string variable, e.g. `type = 'double'` to define the data type of the array;  
* `broken` - is an integer which defines which dimension will be broken, e.g. for `broken = 2` the second dimension `dim_2` will be broken.  
* `var_name` - is a string to defined under which name the caching data will be saved, e.g. if `var_name = 'tmp'`, the caching data will be stored in variables `{tmp1.dat, tmp2.dat, ... tmpn.dat}`.  
* `work_path` is the directory path where the cached `*.dat` files will be stored, in string format.  
* `nchunks` - is an integer which defines the number of chunks the array will be broken into. This variable could be left uninitialized (given all the variable are uninitialed after it); in this case an automatic breakage will be performed: by default the array will be broken into chunks no bigger than 8Gb each. 
* `fcaching` - a caching flag. It is set to `-1` by default which triggers automatic decision whether to cache the data or not. It is possible to enforce the data to be cached always - use `fcaching = 1`, or to always suppress it by `fcaching = 0`; although it is advised to use the default value for most of the cases: `fcaching = -1`.  
* `fdiscreet` - a flag to define discreet (fast) or continious (slow) caching. If not initialized, the slow caching is used.  
* `ini_val` - is an initial value that array will be initialized with, e.g. `ini_val = 1.5`, `ini_val = inf`. If this parameter is not provided, by default it is set to `0`.

## Notes  

The class was originally created as a part of a software package [cryo3d](https://github.com/vicrucann/cryo3d) for fast 3d reconstruction of protein structure from microscopic images.

Contact: 2015 Victoria Rudakova vicrucann(at)gmail(dot)com
