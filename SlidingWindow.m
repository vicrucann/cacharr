classdef SlidingWindow < handle
    %SlidingWindow class to work with CachedNDArray, represents a moving
    %chunk chunk of data along the CachedNDArray
    
    % Class properties:
    % Volume = [v1 v2 ...]; // size of the sliding chunk
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
    
properties %(GetAccess = 'public', SetAccess = 'private')
    volume;
    coordinate;
    data; 
    ibroken;
    type;
    dimension;
    fsaved = 1;
    cpath = 'cache';
    vname = 'tmp';
end

methods
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
    
    function chunk = read(sw, limits)
        % make sure chunk limits are within global dimension
        for i = 1:size(limits,2)
            if (strcmp(limits(i), ':'))
                continue;
            end
            assert(limits{i}(end) <= sw.dimension(i) && limits{i}(1) >= 1, ...
                'Reference operator: out of range NDArray');
        end
        % make sure there is enough memory to create chunk of given limits
        b = sw.ibroken;
        lb = limits{b};
        vol = sw.volume(b);
        co = sw.coordinate(b);
        range = getrange(co, vol);
        if (lb(end) > range(end)) % chunk coordinates are within data range - do nothing, just read; otherwise:
            % move sliding window (save all the previous data, prepare data variable)
            sw.flush();
            sw.move(limits); % + re-assignment of coordinate variable
        end
        limits{b} = sw.glo2loc(lb);
        chunk = sw.gather(limits);
    end
    
    function assign(sw, limits, chunk) % from chunk to sw.data
        expr = subs2str(limits);
        eval(['sw.data' expr '=chunk;']);
        sw.fsaved = 0;
    end
    
    function chunk = gather(sw, limits) % from sw.data to chunk (opposite to assign), limits are in local scale
        sw.draw(); % transfer from file to sw.data
        expr = subs2str(limits);
        chunk = eval(['sw.data' expr]); % copy from sw.data to chunk
    end
    
    function loc = glo2loc(sw, glo) % global to local indexing
        b = sw.ibroken;
        vol = sw.volume(b);
        co = sw.coordinate(b);
        range = getrange(co, vol);
        assert(glo(1) >= range(1) && glo(end) <= range(end),...
            'Conversion is not possible: indices are out of sliding window range');
        loc = glo - co + 1;
    end
    
    function move(sw, limits) % change coords only for broken dimension
        b = sw.ibroken;
        sw.coordinate(b) = limits{b}(1);
    end
    
    function draw(sw) % from file(-s) to sw.data (opposite to flush)
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