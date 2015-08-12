# CachedNDArray - Matlab N-dimensional array with caching possiblity

## Content
* [Short description](https://github.com/vicrucann/cacharr#short-description)
* [Quick start](https://github.com/vicrucann/cacharr#quick-start)
* [Class description, specifics and usage](https://github.com/vicrucann/cacharr#class-description-specifics-and-usage)
  * [Main principle behind the caching through Matlab](https://github.com/vicrucann/cacharr#main-principle-behind-the-caching-through-matlab)
  * [Fast access procedures - an overview](https://github.com/vicrucann/cacharr#fast-access-procedures---an-overview)
  * [Discreet vs. continious caching](https://github.com/vicrucann/cacharr#discreet-vs-continious-caching)
  * [Interface signatures](https://github.com/vicrucann/cacharr#interface-signatures)
* [Notes and contact](https://github.com/vicrucann/cacharr#notes-and-contact)

## Short description  

CachedNDArray - data structure that allows to deal with large N-dimensional arrays through caching method: 
* Allows to avoid Matlab out of memory error by caching large array into several files on hard disk and then reading the necessary chunks using memmapfile function. 
* The data structure is inhereted from handle abstract class which avoids parameter-by-value and supports parameter-by-reference. 
* Supports two types of movements - continious (very slow) and discrete (fast); the former might have no more than two file to represent a chunk; while the latter means the data is processed chunk-after-chunk, and each chunk is represented strictly as a single file.  
* Caching flag can be set to either manual or automatic mode. If no caching is needed to perform, the CachedNDArray is treated like a normal Matlab array.
* Automatic or manual dimension breakage into number of chunks.

## Quick start

Use the provided test script `test_CachedNDArray.m` in order to run an example. The provided test includes small scale example (using small array) and a large-scale example when comparing discreet and continious caching.

## Class description, specifics and usage

#### Main principle behind the caching through Matlab

The necessity for this project was caused by a common Matlab error when trying to allocate a large N-dimensional array. This was especially relevant in the context of the [cryo3d](https://github.com/vicrucann/cryo3d) project - a pipeline for fast 3D protein reconstruction from cryo-EM images.  

The cryo3d pipeline, when run with very fine parameters, requires large computational resources and memory which are not always available. And it caused the mentioned **out-of-memory** error.  

The main idea of the caching data type is to keep that large N-dimensional array on the disk instead of Matlab memory, and only keep its smaller part that is referred to when needed. It can also be explained by using the figure:  

![Alt text](https://github.com/vicrucann/cacharr/blob/master/img/cached.png)  

When we try to allocate a variable which takes more space than what we have in Matlab's available memory, the Matlab throws out-of-memory error. With the caching variable, we save the data to the disk by breaking the data into smaller chunks and saving to different files as shown on the right of the figure. When we request an operator of assignment or reference of the certain range of the cached data, the part of the data is read directly into Matlab memory so that we could process it as if we deal with a normal Matlab array.

#### Fast access procedures - an overview

In order to perform the access procedures, we have to figure out the fastest way to do read/write with the range of files kept on disk. The well-known functions such as `load`, `save` or even `fwrite`, `fread` are not fast enough for that. Therefore, we use the Matlab's `memmapfile` in order to create a memory map to each of the file. 

The `memmapfile` is incorporated into the `subsasgn` and `subsref` functions (bracket operators for reading and writing) which are redefined in CachedNDArray class. 

#### Discreet vs. continious caching

Depending on the CachedNDArray usage, we can define the caching to be discreet (fast) or continious (slow). The figure below helps to differentiate the two: 

![Alt test](https://github.com/vicrucann/cacharr/blob/master/img/slow-fast.png)

Since the data is split into chunks and each chunk is saved into a separate file, the discreet access would mean only accessing the chunks as they are written within the files as shown on the right, i.e. it is not possible to access a chunk of data that is shared between two files (as shown on the left of the figure). A basic example when we use the discreet caching: given 2D RGB array (color image), filter it so that only blue color is left.  

As to the continious caching, the access chunk could be shared between the two consequitive files as shown on the left of the figure. However, it also comes with a price of much slower performance since there will be more copying/writing involved than if we access data dicretely. An example when we use the continious caching: given 2D RGB array (color image), smooth it out so that each output pixel equals to the average sum of its surrounding pixels.    

#### Interface signatures  

###### Constructor

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

###### Write operator - `subsasgn`

The assignment operator has the same signature as when dealing with a normal Matlab array:  
```
cnda(:,1:10,:,:) = chunk;
```
where  
`chunk` - is the data chunk which we want to write to the `cnda` array. 

###### Read operator - `subsref`
The reference operator has the same signature as when dealing with a normal Matlab array:  
```
chunk = cnda(:, 80:end, :, :);
```
where  
`chunk` is the return data chunk which is copied from `cnda` array

## Notes and contact 

The class was originally created as a part of a software package [cryo3d](https://github.com/vicrucann/cryo3d) for fast 3d reconstruction of protein structure from microscopic images.

Contact: 2015 Victoria Rudakova vicrucann(at)gmail(dot)com
