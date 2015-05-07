classdef CachedNDArray
    %CachedNDArray - data structure that allows to deal with large
    %N-dimensional arrays through caching method
    %   Allows to avoid Matlab out of memory error by caching large array
    %   into several files on hard disk and then reading the necessary
    %   chunks using memmapfile function
    %   The data structure is inhereted from handle abstract class which
    %   avoids parameter by value and supports parameter by reference
    %   2015 victoria.rudakova(at)yale.edu
    
    % Calculating if caching is needed or not (then an array is treated like a normal matlab array)
    % Automatic breakage (if needed) in number of chunks
    % Asserts for errors (out of range etc)
    % Broken multi-dimension not supported
    
    properties (GetAccess = 'public', SetAccess = 'private')
        window; % class SlidingWindow
        cached; % flag for caching or not (normal array)
        nchunks = 0;
    end
    
    methods
        function cnda = CachedNDArray(dims, type, broken, var_name, path_cache, nchunks)
            if (nargin < 6) 
                nchunks = zeros(1, length(broken)); 
            else
                assert(length(nchunks) == length(broken),...
                    'Number of chunks in each dimension must correspond to number of broken dimensions');
                assert(nchunks > 0, 'Number of chunks is a positive integer parameter');
            end
            if (nargin < 5) 
                path_cache = 'cache'; 
            end
            if (nargin < 4) 
                var_name = 'tmp'; 
            end
            if (nargin < 3) % user must always specify which dimension they intend to use borken
                error('There must be at least 3 input parameters to create CachedNDArray variable.'); 
            end
            path_cache = correctpath(path_cache);
            
            assert(sum(dims <= 0) == 0, ...
                'Dimensions must be positive integers');
            assert(broken <= size(dims,2),... 
                'Index of broken dimension must be within dimension size');
            assert(sum(broken > length(dims)) == 0, ...
                'One (or more) index of broken dimensions is larger than total number of dimensions');
            
            reqmem = whos(dims, type);
            freemem = getmem();
            if (freemem > 1.3*1.2*reqmem) % assume it's 20%*30% more than required to allow for other side variables
                fprintf('No caching will be used, there is enough memory \n');
                cnda.cached = 0;
            else
                warning('Not enough memory: caching will be used. Processing time will be slower. ');
                cnda.cached = 1;
            end
            
            %cnda.cached = 1; % for testing, remove in release
            
            if (~cnda.cached)
                cnda.window = SlidingWindow(ones(size(dims)), dims, 0, type, dims, [], []);
                %cnda.window.data = zeros(dims, type);
            else
                if (sum(nchunks) == 0) % need to divide memory into number of chunks
                    gb = 8; % assume each chunk will be no more than 8 gb
                    nchunks = floor(reqmem/(gb*1024^3)); % assume we deal with only 1 broken dimension (subject to change)
                    if (nchunks == 0)
                        error('Not enough memory for a split, possible resolve: consider splitting along another dimension. Or, consider splitting along second dimension at the same time (must be performed manually.)');
                    end
                end
                
                fprintf('Cached N-d Array is being initialized: ');
                vol = dims;
                vol(broken) = ceil(dims(broken) / nchunks);
                coord = ones(size(dims));
                cnda.window = SlidingWindow(coord, vol, broken, type, dims, path_cache, var_name);
                
                for i = 1:nchunks % for each chunk
                    fname = get_fname(path_cache, var_name, i);
                    fid = fopen(fname, 'Wb');
                    if (i < nchunks)
                        fwrite(fid, cnda.window.data, type);
                    else % * last chunk could be smaller in size
                        vol(broken) = dims(broken) - (nchunks-1) * vol(broken);
                        fwrite(fid, zeros(vol, type), type);
                    end
                    fclose(fid);
                    progress_bar(i, nchunks);
                end
                fprintf('\n');
                cnda.nchunks = nchunks;
            end
        end
        
        function cnda = subsasgn(cnda, S, chunk)
            if (strcmp(S(1).type, '()') )
                if (cnda.cached)
                    limits = S(1).subs;
                    
                    for i = 1 : size(limits,2)
                        if (strcmp(limits(i), ':'))
                            continue;
                        end
                        assert(limits{i}(end) <= cnda.window.dimension(i) && limits{i}(1) >= 1, ...
                            'Assignment operator: out of range NDArray');
                    end
                    for i = 1 : length(size(chunk))
                        assert(size(chunk,i) <= cnda.window.volume(i), ...
                            'Requested range is too large for the current CachedNDArray setup');
                    end
                    b = cnda.window.ibroken;
                    assert(size(chunk,b) <= cnda.window.volume(b), ...
                        'Requested range`s broken dimension is wider than the sliding window');
                    lb = limits{b};
                    assert(strcmp(lb, ':') == 0 && sum(lb(end)-lb(1) > cnda.window.volume(b)) == 0, ...
                        'Assignment range is wider than the sliding data window');
                    
                    cnda.window.write(limits, chunk);
                else
                    cnda.window.data = builtin('subsasgn', cnda.window.data, S, chunk);
                end
            else
                cnda = builtin('subsasgn', cnda, S, chunk);
            end
        end
        
        function chunk = subsref(cnda, S)
            if (strcmp(S(1).type, '()') )
                if (cnda.cached)
                    limits = S(1).subs;
                    % make sure chunk limits are within global dimension
                    for i = 1:size(limits,2)
                        if (strcmp(limits(i), ':'))
                            continue;
                        end
                        assert(limits{i}(end) <= cnda.window.dimension(i) && limits{i}(1) >= 1, ...
                            'Reference operator: out of range NDArray');
                    end
                    chunk = cnda.window.read(S(1).subs);
                else
                    chunk = builtin('subsref', cnda.window.data, S);
                end
            else
                chunk = builtin('subsref', cnda, S);
            end
        end
        
        function r = end(cnda, ipos, nidx)
            assert(nidx == length(cnda.window.dimension), 'Number of indices is not given correctly');
            r = cnda.window.dimension(ipos);
        end
        
        function success = flush(cnda)
            cnda.window.flush();
            success = 1;
        end
    end
    
end

function os = getOS()
archstr = computer('arch');
if (isequal(archstr(1:3), 'win')) % Windows
    os = 1;
elseif (isequal(archstr(1:5),'glnxa')) % Linux
    os = 0;
else % other, not supported
    error('Unrecognized or unsupported architecture');
end
end

function path_platform = correctpath(path)
os = getOS();
if (strcmp(path(end), '\') || strcmp(path(end), '/'))
    path = path(1:end-1);
end
path_platform = path;
if os % Windows
    path_platform = [path_platform '\'];
else % Linux
    path_platform = [path_platform '/'];
end
end

function reqmem = whos(dims, type)
if isequal(type, 'int8')
    reqmem = 1;
elseif isequal(type, 'single') 
    reqmem = 4; % bytes for single
else
    reqmem = 8; % assume it's double otherwise
end 
for i = 1:length(dims)
    reqmem = reqmem*dims(i); % total size of variable in bytes
end
end

function freemem = getmem()
os = getOS();
if os
    user = memory;
    freemem = user.MaxPossibleArrayBytes;
else
    [~, w] = unix('free | grep Mem');
    stats = str2double(regexp(w, '[0-9]*', 'match'));
    freemem = (stats(3) + stats(end))*1024; % in bytes
end
end

