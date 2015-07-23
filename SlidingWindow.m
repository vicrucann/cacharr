classdef SlidingWindow < handle
    %SlidingWindow class to work with CachedNDArray, represents a moving
    %chunk of data along the CachedNDArray
    
    % The class is only accessible by CachedNDArray class and its
    % functions, and therefore is meant to be called only from
    % CachedNDArray functions.
    %   2015 Victoria Rudakova vicrucann(at)gmail.com
    
properties (GetAccess = ?CachedNDArray, SetAccess = ?CachedNDArray)
    volume; % size of the sliding chunk
    coordinate; % sliding chunk location in global coordinates
    data; % data container (of size volume)
    ibroken; % indices of broken dimensions, only 1 dimension is supported in this version
    type; % data type, in string format, e.g., 'double', 'single' etc
    dimension; % overall dimension of CachedNDArray
    fsaved = 1; % flag indicating if data needs to be flushed (saved)
    fdrawn = 0; % flag indicating if data needs to be drawn from file(-s)
    cpath = 'cache'; % folder location where cache variables are saved
    vname = 'tmp'; % under what name the variables will be saved
    fast = 1; % fast(blockwise, discrete) or slow (sliding, continious) window type
    nopen = 1; % number of possible files to open at the same time (<=1 if fast reading, <=2 otherwise)
    mmap = 0;
    ini_val = 0;
end

methods
    % A window constructor, called by CachedNDArray constructor
    function sw = SlidingWindow(coord, vol, broken, type, dim, cpath, vname, fdiscrete, ini_val)
        assert(sum(size(vol) == size(coord)) ~= 0, 'Dimension number mismatch.');
        sw.volume = vol;
        sw.coordinate = coord;
        if (ini_val == 0)
            sw.data = zeros(vol, type);
        elseif (ini_val == 1)
            sw.data = ones(vol, type);
        elseif (ini_val == inf)
            sw.data = inf(vol, type);
        else
            assert(ini_val > 1, 'Initial value must be positive integer\n');
            sw.data = ones(vol, type) * ini_val;
        end
        sw.ibroken = broken;
        sw.type = type;
        sw.dimension = dim;
        sw.cpath = cpath;
        sw.vname = vname;
        sw.fast = fdiscrete;
        sw.nopen = -1*sw.fast+2;
    end
    
    % Called by CachedNDArray.subsasgn() to assign chunk variable to the
    % memory
    function write(sw, limits, chunk)
        b = sw.ibroken;
        lb = limits{b}; % limits of broken dimension
        vol = sw.volume(b);
        co = sw.coordinate(b);
        range = getrange(co, vol); % volume range
        if (lb(1) < range(1) || lb(end) > range(end)) % chunk coordinates are within data range - do nothing, just assign; otherwise:
            sw.flush(); % move sliding window (save all the previous data, prepare data variable)
            sw.move(limits); % + re-assignment of coordinate variable
        end
        limits{b} = sw.glo2loc(lb); % global to local indexing
        sw.assign(limits, chunk); % assign chunk to corresponding data range
    end
    
    % Called by CachedNDArray.subsref() to read from the memory to a chunk
    % variable
    function S = read(sw, S)
        limits = S(1).subs;
        % TO DO: make sure there is enough memory to create chunk of given limits
        b = sw.ibroken;
        lb = limits{b};
        vol = sw.volume(b);
        co = sw.coordinate(b);
        range = getrange(co, vol);
        sw.flush();
        if (lb(1) < range(1) || lb(end) > range(end)) % chunk coordinates are within data range - do nothing, just read; otherwise:
            % move sliding window (save all the previous data, prepare data variable)
            sw.move(limits); % + re-assignment of coordinate variable
        end
        if (~sw.fdrawn)
            sw.draw(); % transfer from file to sw.data
        end
        limits{b} = sw.glo2loc(lb);
        S(1).subs = limits;
        %chunk = builtin('subsref', sw.data, S);
        %expr = subs2str(limits);
        %chunk = eval(['sw.data' expr]); % copy from sw.data to chunk
    end
     
    % Called from write(): moves chunk -> sw.data
    function assign(sw, limits, chunk)
        expr = subs2str(limits);
        eval(['sw.data' expr '=chunk;']);
        sw.fsaved = 0;
        if (sw.fast)
            sw.flush();
        end
    end
        
    % Transformation of broken dimension from global [dimension] to local [volume] indexing
    function loc = glo2loc(sw, glo)
        b = sw.ibroken;
        vol = sw.volume(b);
        co = sw.coordinate(b);
        range = getrange(co, vol);
        assert(glo(1) >= range(1) && glo(end) <= range(end),...
            'Conversion is not possible: indices are out of sliding window range');
        loc = glo - co + 1;
    end
    
    % Called from write() and read(): move the sliding box within the broken dimension
    % to a new coordinate
    function move(sw, limits)
        b = sw.ibroken;
        if (sw.fast)
            vol = sw.volume(b);
            sw.coordinate(b) = (getidxchunk(limits{b}(1), vol) - 1) * vol + 1;
        else
            sw.coordinate(b) = limits{b}(1);
        end
        sw.fdrawn = 0;
    end
    
    % Called from read(),gather(): transfer from file(-s) to sw.data only
    % if the window coordinate changed (logic in read function)
    function draw(sw)
        b = sw.ibroken;
        vol = sw.volume(b);
        co = sw.coordinate(b);
        fidx = getidxchunk(co, vol);
        lidx = getidxchunk(co+vol-1, vol);
        nchunks = get_nchunks(vol, sw.dimension(b));
        if (lidx > nchunks) % the end chunk could contain data that is not needed to be saved!
            lidx = nchunks; % so we trim it
        end
        assert(fidx <= lidx, 'Indexing calculation failed');
        nfiles = (fidx ~= lidx) + 1;
        assert(nfiles <= sw.nopen, 'Number of files to open: calculation failed');
        offset = getidxb(co, vol);
        fname = get_fname(sw.cpath, sw.vname, fidx);
        sw.rmemmap(fname, 1, vol-offset+1, offset, vol);
        if (nfiles == 2)
            fname = get_fname(sw.cpath, sw.vname, lidx);
            sw.rmemmap(fname, vol-offset+2, vol, 1, offset-1);
        end
        sw.fdrawn = 1;
    end
    
    % Called from write(), read(), CachedNDArray.flush(): flushes sw.data
    % to corresponding file(-s)
    function flush(sw) % from sw.data to files
        if (~sw.fsaved)
            b = sw.ibroken;
            vol = sw.volume(b);
            co = sw.coordinate(b);
            fidx = getidxchunk(co, vol);
            lidx = getidxchunk(co+vol-1, vol);
            nchunks = get_nchunks(vol, sw.dimension(b));
            if (lidx > nchunks) % the end chunk could contain data that is not needed to be saved!
                lidx = nchunks; % so we trim it
            end
            assert(fidx <= lidx, 'Indexing calculation failed');
            nfiles = (fidx ~= lidx) + 1;
            assert(nfiles <= sw.nopen, 'Number of files to open: calculation failed');
            offset = getidxb(co, vol);
            fname = get_fname(sw.cpath, sw.vname, fidx);
            sw.wmemmap(fname, offset, vol, 1, vol-offset+1);
            if (nfiles == 2)
                fname = get_fname(sw.cpath, sw.vname, lidx);
                sw.wmemmap(fname, 1, offset-1, vol-offset+2, vol);
            end
            % mark the properties flushed
            sw.coordinate = sw.coordinate * 0 + 1;
            sw.data = sw.data * 0 + sw.ini_val;
            sw.fsaved = 1;
        end
    end
    
    % Called from draw(): function to read from memmapfile to sw.data
    function rmemmap(sw, fname, lidx1, lidx2, ridx1, ridx2) % read from memmapfile to sw.data
        sw.mmap = memmapfile(fname, 'Format', sw.type);
        if (sw.fast)
            sw.data = reshape(sw.mmap.Data, sw.volume); % this is where the speed up is for the fast method
            % we read the whole file into the window buffer without any
            % temporal variable copying (like for continious method)
        else
            b = sw.ibroken;
            sz = size(sw.volume,2);
            subs_r = gensubs(sz);
            subs_l = subs_r;
            subs_r{b} = (ridx1:ridx2);
            subs_l{b} = (lidx1:lidx2);
            rhs = subs2str(subs_r);
            lhs = subs2str(subs_l);
            chunk = reshape(sw.mmap.Data, sw.volume); % read the data from file
            eval(['sw.data' lhs '=' 'chunk' rhs ';']); % slowest operation since 
            % re-assignment of potentially large array (matlab has to recopy the whole array,
            % even if only a small part was changed)            
        end
    end
    
    % Called from flush(): function to write sw.data content to associated
    % memmapfile
    function wmemmap(sw, fname, lidx1, lidx2, ridx1, ridx2) % write sw.data to memmapfile
        b = sw.ibroken;        
        sz = size(sw.volume,2);
        sw.mmap = memmapfile(fname, 'Format', sw.type, 'Writable', true);
        if (sw.fast)
            sw.mmap.Data = sw.data;
        else
            chunk = reshape(sw.mmap.Data, sw.volume); % read the data which is already in file
            subs_r = gensubs(sz);
            subs_l = subs_r;
            subs_r{b} = (ridx1:ridx2);
            subs_l{b} = (lidx1:lidx2);
            rhs = subs2str(subs_r);
            lhs = subs2str(subs_l);
            eval(['chunk' lhs '=' 'sw.data' rhs ';']);
            sw.mmap.Data = chunk;
        end
    end
end

end

function r = getrange(coord, vol)
r = [coord, coord + vol - 1];
end

function idxc = getidxchunk(co, vol)
idxc = ceil(co / vol);
end

function idxb = getidxb(co, vol)
idxb = mod(co, vol);
if (idxb == 0)
    idxb = vol;
end
end

function subs = gensubs(sz)
subs = cell(1,sz);
for i = 1 : sz
    subs{i} = ':';
end
end

function I = subs2str(subs)
I = '(';
for i = 1:length(subs)
    if strcmp(subs{1,i},':')
        I = strcat(I, ':,');
    else
        if length(subs{i}) > 1
            first = subs{i}(1);
            last = subs{i}( length(subs{i}) );
            I = strcat(I, [num2str(first) ':' num2str(last) ',']);
        else
            I = strcat(I, [num2str(subs{i}) ',']);
        end
    end
end
I(end) = ')';
end