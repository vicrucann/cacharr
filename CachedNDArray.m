classdef CachedNDArray
    %CachedNDArray - data structure that allows to deal with large
    %N-dimensional arrays through caching method
    %   Allows to avoid Matlab out of memory error by caching large array
    %   into several files on hard disk and then reading the necessary
    %   chunks using memmapfile function
    %   The data structure is inhereted from handle abstract class which
    %   avoids parameter by value and supports parameter by reference
    %   2015 victoria.rudakova(at)yale.edu
    
    properties (GetAccess = 'public', SetAccess = 'private')
        %flush; 
        window; % class SlidingWindow
        dimension;
        type;
        ibroken;
        vname;
        cpath;
    end
    
    methods
        function cnda = CachedNDArray(dims, type, broken, var_name, path_cache, nchunks)
            assert(sum(dims <= 0) == 0, 'Dimensions must be positive integers');
            assert(broken <= size(dims,2), 'Index of broken dimension must be within dimension size');
            
            cnda.dimension = dims;
            cnda.ibroken = broken;
            cnda.type = type;
            cnda.vname = var_name;
            cnda.cpath = path_cache;
            
            vol = dims;
            vol(broken) = ceil(dims(broken) / nchunks);
            coord = ones(size(dims));
            cnda.window = SlidingWindow(coord, vol, broken, type);
        end
        
        function cnda = subsasgn(cnda, S, chunk)
            b = cnda.ibroken;
            assert(sum(size(chunk) > cnda.window.volume) == 0, 'Requested range is too large for the current CachedNDArray setup');
            assert(size(chunk,b) <= cnda.window.volume(b), 'Requested range`s broken dimension is wider than the sliding data window');
            if (strcmp(S(1).type, '()') ) 
                for i = 1 : size(S.subs,2)
                    if (strcmp(S.subs(i), ':'))
                        continue;
                    end
                    assert(S.subs{i}(end) <= cnda.dimension(i), 'Assignment operator: out of range NDArray');
                end
                % and caching == 1
                cnda.window.write(S(1).subs, chunk);
                
                %cnda = builtin('subsasgn', cnda.window.data, S, chunk); for
                %caching = 0;
            else
                cnda = builtin('subsasgn', cnda, S, chunk);
            end
        end
        
        function chunk = subsref(cnda, S)
            if (strcmp(S(1).type, '()') )
                
            else
                chunk = builtin('subsref', cnda, S);
            end
        end
        
        function success = flush(cnda)
            cnda.window.flush();
            success = 1;
        end
    end
    
end

