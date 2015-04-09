classdef SlidingWindow < handle
    %SlidingWindow class to work with CachedNDArray, represents a moving
    %chunk chunk of data along the CachedNDArray
    
    % Class properties:
    % Dimension = [d1 d2 ...]; // size of the sliding chunk
    % Coords = [c1 c2 ...]; // sliding chunk location in global coordinates
    % Flush = true / false; // date needs to be flushed or not
    % Data = [x11 x12 ...; x21 x22 ...]; // data container
    % IFile = [if1 coord11 coord12 ...; if2 coord21 coord22 ... ]^T; //
    % indices of datafiles and corresponding local coords of data elements
    % 
    
    % Initialization:
    % Given chunk size and global dimensions, fopen and fwrite the cached
    % files with zeros. It is necessary so that when re-writing, we could
    % use memmapfile functionality which is faster than fwrite.
    
    % Two main functions:
    % WRITE: X() = blob; - assignment
    % READ: blob = X(); - reference
    
    % WRITE algorithm
    % X() = blob;
    % 0. If there is anything to be flushed, flush it onto disk
    %    - If that's the case set flush=false afterwards
    % 1. Check size(blob) <= size(slidind_chunk.dimension)
    % 2. Find file indices for each element of blob in broken dimension
    % 3. If all indices are the same as current index (idx_chunk), OR if
    % sliding blob coordinates contain the requested blob:
    %    - Save blob to data variable
    %    - Mark flush as true (needed to be flushed)
    % 3. If previous statement is false:
    %    - If flush=true, flush data to disc, set flush=false
    %    - Move sliding chunk coordinates so that it contains the requested
    %    chunk
    %    - Save blob to data variable -| Same code as in true statement
    %    - Mark flush as true         -| (first part of point 3)
    
    % READ algorithm
    % blob = X();
    % 0. If there is anything to be flushed, flush it onto disk
    %    - If that's the case set flush=false afterwards
    % 1. Check size(blob) <= size(slidind_chunk.dimension)
    % 2. Find file indices for each element of blob in broken dimension
    % 3. If all indices are the same as current index (idx_chunk), OR if
    % sliding blob coordinates contain the requested blob:
    %    - Read to blob from data variable
    % 3. If previous statement is false:
    %    - If flush=true, flush data to disc, set flush=false
    %    - Move sliding chunk coordinates so that it contains the requested
    %    chunk
    %    - Read to blob from data variable -| Same code as in true statement
    
    % FLUSH function
    % flush = false -> no flush needed to be done
    % flush = true -> there is temporary data, needed to be flushed
    % files variable - contains the filenames with variables
    % 1. For each file in the sliding chunk:
    %    - Open file
    %    - Make sure it is initialized (otherwise, initialize it with zeros)
    %    - Assign the sliding chunk (or its part) to the designated memory 
    %    area of the current file
    % 2. Set flush = false
    
    %   2015 victoria.rudakova(at)yale.edu
    
properties (GetAccess = 'public', SetAccess = 'private')    
    data; % contains N-d matrix which is a part of CachedArray
    border; % pair of values that denote location of the window (first and last element)
    dimension; % window dimension, the broken dimension will be of size = (border.last-border.first)
end

methods
    function sw = SlidingWindow()
    end
    
    
    
end

end