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
    
properties (GetAccess = 'public', SetAccess = 'private')
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
        for i = 1 : size(limits,2)
            if (strcmp(limits(i), ':'))
                continue;
            end
            assert(limits{i}(end) <= sw.dimension(i), 'Assignment operator: out of range NDArray');
        end
        b = sw.ibroken;
        assert(sum(size(chunk) > sw.volume) == 0,...
            'Requested range is too large for the current CachedNDArray setup');
        assert(size(chunk,b) <= sw.volume(b), ...
            'Requested range`s broken dimension is wider than the sliding window');
        lb = limits{b}; % limits of broken dimension
        vol = sw.volume(b);
        assert(strcmp(lb, ':') == 0 && sum(lb(end)-lb(1) > vol) == 0, ...
            'Assignment range is wider than the sliding data window');
        co = sw.coordinate(b);
        range = getrange(co, vol); % volume range
        if (lb(end) > range(end)) % chunk coordinates are within data range - do nothing, just assign; otherwise:
            % move sliding window (save all the previous data, prepare data variable)
            sw.flush();
            sw.move(limits); % + re-assignment of coordinate variable
        end
        limits{b} = sw.glo2loc(lb); % global to local indexing
        sw.assign(limits, chunk); % assign chunk to corresponding data range
    end
    
    function [ifile, nfid ] = get_ifile(sw, range)
        vol = sw.volume(sw.ibroken);
        fid1 = ceil(range(1) ./ vol);
        c0 = 1+vol*(fid1-1);
        offset = range(1)-c0;
        cusion = vol - (range(end)-range(1));
        nfid = (offset-cusion > 0) + 1;
        assert(nfid <= 2 && offset < vol); % debugging
        ifile = fid1; 
    end
    
    function assign(sw, limits, chunk)
        expr = subs2str(limits);
        eval(['sw.data' expr '=chunk;']);
        sw.fsaved = 0;
        lim_glo = sw.loc2glo(limits{sw.ibroken}(end)); % back from local to global
        if (lim_glo == sw.dimension(sw.ibroken)) % automatically flush if it's the very last chunk
            sw.flush();
        end
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
    
    function glo = loc2glo(sw, loc)
        b = sw.ibroken;
        vol = sw.volume(b);
        co = sw.coordinate(b);
        assert(loc(1) >= 1 && loc(end) <= vol,...
            'Conversion is not possible: indices are out of sliding window range');
        glo = loc + co - 1;
    end
    
    function move(sw, limits) % change coords only for broken dimension
        b = sw.ibroken;
        sw.coordinate(b) = limits{b}(1);
    end
    
    function flush(sw)
        if (~sw.fsaved)
            % extract the indices to assign the data to memory file
            % assign to the memory
            % the end chunk could contain data that is not needed to be saved!
            b = sw.ibroken;
            vol = sw.volume(b);
            co = sw.coordinate(b);
            sz = size(sw.volume,2);
            fidx = getidxchunk(co, vol);
            lidx = getidxchunk(co+vol-1, vol);
            assert(fidx <= lidx, 'Indexing calculation failed');
            nfiles = (fidx ~= lidx) + 1;
            assert(nfiles <= 2, 'Number of files to open: calculation failed');
            
            offset = getidxb(co, vol);
            fname = get_fname(sw.cpath, sw.vname, fidx);
            m = memmapfile(fname, 'Format', sw.type, 'Writable', true);
            subs11 = gensubs(sz);
            subs11{b} = [num2str(offset) ':' num2str(vol)];
            expr11 = subs2str(subs11);
            subs12 = gensubs(sz);
            subs12{b} = ['1:' num2str(vol-offset+1)];
            expr12 = subs2str(subs12);
            eval(['m.Data' expr11 '=sw.data' expr12 ';']);
                        
            %subs21 = gensubs(size(vol,2));
            %subs22 = gensubs(size(vol,2));
            
            if (nfiles == 1) % if it's only 1 file to open
            else % if there are two files to open
                fname = get_fname(sw.cpath, sw.vname, lidx);
                m = memmapfile(fname, 'Format', sw.type, 'Writable', true);
            end
            
            for i = fidx:lidx
                offset = getidxb(co, vol);
                
                m.Data(offset:end, :) = sw.data(1:vol-offset, :); % 1st file
                m.Data(1:offset, :) = sw.data(vol-offset+1:end, :); % 2nd file
            end
            % mark the properties flushed
            sw.coordinate = sw.coordinate * 0 + 1;
            sw.data = sw.data*0;
            sw.fsaved = 1;
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
        str = sscanf(subs{i}, '%f:%f');
        if length(str) > 1
            I = strcat(I, [num2str(str(1)) ':' num2str(str(2)) ',']);
        else
            I = strcat(I, [num2str(str(1)) ',']);
        end
    end
end
I(end) = ')';
end