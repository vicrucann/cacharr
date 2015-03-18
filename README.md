# cacharr
Matlab class that allows to work with large N-d arrays through chunks of data; thus helps to avoid Matlab out of memory error.

The caching data structure assumes user processes their data in chunks SEQUENTIALLY.
The user is responsible for chunk size determination and dimension breakage.

Cacharr class - standalone data structure which allows caching of the large arrays.
    %   Allows to avoid Matlab out of memory error by caching large array into several files on hard disk and then reading the necessary chunks using memmapfile function
    %   The data structure is inhereted from handle abstract class which avoids parameter by value and supports parameter by reference
    %   Contains three main functions: constructor, write and read with option to automatically detect the need for caching (set caching to -1)
    %   The class was originally created as a part of a software package for fast 3d reconstruction of protein structure from microscopic images.
    %   2015 victoria.rudakova(at)yale.edu
