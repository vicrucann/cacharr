classdef SlidingWindow < handle
    %SlidingWindow class to work with CachedNDArray, represents a moving
    %chunk of data along the CachedNDArray
    
    % The class is only accessible by CachedNDArray class and its
    % functions, and therefore is meant to be called only from
    % CachedNDArray functions.
    %   2015 victoria.rudakova(at)yale.edu
    
properties (GetAccess = ?CachedNDArray, SetAccess = ?CachedNDArray)
    volume; % size of the sliding chunk
    coordinate; % sliding chunk location in global coordinates
    data; % data container (of size volume)
    ibroken; % indices of broken dimensions, only 1 dimension is supported in this version
    type; % data type, in string format
    dimension; % overall dimension of CachedNDArray
    fsaved = 1; % flag inficating of data needs to be saved
    cpath = 'cache';
    vname = 'tmp';
end

methods
    % A window constructor, called by CachedNDArray constructor
    function sw = SlidingWindow(coord, vol, broken, type, dim, cpath, vname)
        assert(sum(size(vol) == size(coord)) ~= 0, 'Dimension number mismatch.');
        sw.volume = vol;
        sw.coordinate = coord;
        sw.data = zeros(vol, type);
        sw.ibroken = broken;
        sw.type = type;
        sw.dimension = dim;
        sw.cpath = cpath;
        sw.vname = vname;
    end
    
    % Called by CachedNDArray.subsasgn() to assign chunk variable to the
    % memory
    function write(sw, limits, chunk)
        b = sw.ibroken;
        lb = limits{b}; % limits of broken dimension
        vol = sw.volume(b);
        co = sw.coordinate(b);
        range = getrange(co, vol); % volume range
        if (lb(end) > range(end)) % chunk coordinates are within data range - do nothing, just assign; otherwise:
            sw.flush(); % move sliding window (save all the previous data, prepare data variable)
            sw.move(limits); % + re-assignment of coordinate variable
        end
        limits{b} = sw.glo2loc(lb); % global to local indexing
        sw.assign(limits, chunk); % assign chunk to corresponding data range
    end
    
    % Called by CachedNDArray.subsref() to read from the memory to a chunk
    % variable
    function chunk = read(sw, limits)
        % TO DO: make sure there is enough memory to create chunk of given limits
        b = sw.ibroken;
        lb = limits{b};
        vol = sw.volume(b);
        co = sw.coordinate(b);
        range = getrange(co, vol);
        if (lb(end) > range(end)) % chunk coordinates are within data range - do nothing, just read; otherwise:
            sw.flush(); % move sliding window (save all the previous data, prepare data variable)
            sw.move(limits); % + re-assignment of coordinate variable
        end
        limits{b} = sw.glo2loc(lb);
        chunk = sw.gather(limits);
    end
    
    % Called from write(): moves chunk -> sw.data
    function assign(sw, limits, chunk)
        expr = subs2str(limits);
        eval(['sw.data' expr '=chunk;']);
        sw.fsaved = 0;
    end
    
    % Called from read(): moves sw.data -> chunk
    function chunk = gather(sw, limits) % limits are in local scale
        sw.draw(); % transfer from file to sw.data
        expr = subs2str(limits);
        chunk = eval(['sw.data' expr]); % copy from sw.data to chunk
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
        sw.coordinate(b) = limits{b}(1);
    end
    
    % Called from gather(): transfer from file(-s) to sw.data
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
        assert(nfiles <= 2, 'Number of files to open: calculation failed');
        offset = getidxb(co, vol);
        fname = get_fname(sw.cpath, sw.vname, fidx);
        sw.rmemmap(fname, 1, vol-offset+1, offset, vol);
        if (nfiles == 2)
            fname = get_fname(sw.cpath, sw.vname, lidx);
            sw.rmemmap(fname, vol-offset+2, vol, 1, offset-1);
        end
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
            assert(nfiles <= 2, 'Number of files to open: calculation failed');
            offset = getidxb(co, vol);
            fname = get_fname(sw.cpath, sw.vname, fidx);
            sw.wmemmap(fname, offset, vol, 1, vol-offset+1);
            if (nfiles == 2)
                fname = get_fname(sw.cpath, sw.vname, lidx);
                sw.wmemmap(fname, 1, offset-1, vol-offset+2, vol);
            end
            % mark the properties flushed
            sw.coordinate = sw.coordinate * 0 + 1;
            sw.data = sw.data*0;
            sw.fsaved = 1;
        end
    end
    
    % Called from draw(): function to read from memmapfile to sw.data
    function rmemmap(sw, fname, lidx1, lidx2, ridx1, ridx2) % read from memmapfile to sw.data
        b = sw.ibroken;        
        sz = size(sw.volume,2);
        m = memmapfile(fname, 'Format', sw.type, 'Writable', true);
        chunk = reshape(m.Data, sw.volume); % read the data from file
        subs_r = gensubs(sz);
        subs_l = subs_r;
        subs_r{b} = (ridx1:ridx2);
        subs_l{b} = (lidx1:lidx2);
        rhs = subs2str(subs_r);
        lhs = subs2str(subs_l);        
        eval(['sw.data' lhs '=' 'chunk' rhs ';']);
    end
    
    % Called from flush(): function to write sw.data content to associated
    % memmapfile
    function wmemmap(sw, fname, lidx1, lidx2, ridx1, ridx2) % write sw.data to memmapfile
        b = sw.ibroken;        
        sz = size(sw.volume,2);
        m = memmapfile(fname, 'Format', sw.type, 'Writable', true);
        chunk = reshape(m.Data, sw.volume); % read the data which is already in file
        subs_r = gensubs(sz);
        subs_l = subs_r;
        subs_r{b} = (ridx1:ridx2);
        subs_l{b} = (lidx1:lidx2);
        rhs = subs2str(subs_r);
        lhs = subs2str(subs_l);        
        eval(['chunk' lhs '=' 'sw.data' rhs ';']);
        m.Data = chunk;
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