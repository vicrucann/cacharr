classdef CachedArray < handle
    %CachedArray class - standalone data structure which allows caching of the
    %large arrays
    %   Allows to avoid Matlab out of memory error by caching large array
    %   into several files on hard disk and then reading the necessary
    %   chunks using memmapfile function
    %   The data structure is inhereted from handle abstract class which
    %   avoids parameter by value and supports parameter by reference
    %   Contains three main functions: create, write and read with option
    %   to automatically detect the need for caching (set caching to -1)
    %   2015 victoria.rudakova(at)yale.edu
    
    properties (GetAccess = 'public', SetAccess = 'private')
        dimension; % size of the array
        path; % path where variables are saved
        type; % data type, e.g. double, int
        nchunks; % total number of chunks
        broken; % index of a broken dimension
        caching = -1; % 1 caching ON, 0 caching OFF, -1 automatic mode
        data; % contains either first chunk or whole data if no brakage was performed
        currchunk = 1; % pointed on chunk index which is stored in data currently
        ichunk = 1; % pointer to next current chunk for write function
        vname = 'tmp';
    end
    
    methods
        % constructor
        % size - dimensions of the array - vector
        % type - data type, e.g. 'double', 'int', 'single' - string
        % idx_broken - indices of the dimension to break - value or vector
        % var_name - variable name to be saved - string (can be default)
        % path_cache - folder where cached files are stored - string (can be default)
        % num_chunks - number of chunks per each dimension - value or vector (can be default)
        function carr = CachedArray(size, type, idx_broken, var_name, path_cache, num_chunks)
            if (nargin < 6) 
                num_chunks = zeros(1, length(idx_broken)); 
            else
                assert(length(num_chunks) == length(idx_broken));
            end
            if (nargin < 5) 
                path_cache = 'cache'; 
            end
            if (nargin < 4) 
                var_name = 'tmp'; 
            end
            if (nargin < 3) 
                error('There must be at least 3 input parameters to create cached array variable.'); 
            end
            path_cache = path_corrected(path_cache);
            assert(sum(idx_broken > length(size)) == 0); % make sure all broken dimensions are within the number of dimensions
            carr.dimension = size;
            carr.type = type;
            carr.broken = idx_broken;
            carr.vname = var_name;
            carr.path = path_cache;
            
            reqmem = whos(size, type);
            
            archstr = computer('arch');
            if (isequal(archstr(1:3), 'win')) % if it's windows
                user = memory;
                freemem = user.MaxPossibleArrayBytes;
            elseif (isequal(archstr(1:5),'glnxa')) % if linux
                [r, w] = unix('free | grep Mem');
                stats = str2double(regexp(w, '[0-9]*', 'match'));
                %memsize = stats(1); % bytes
                freemem = (stats(3) + stats(end))*1000; % in bytes
            else % mac?
                error('Unrecognized or unsupported architecture');
            end
            
            if (freemem > 1.3*1.2*reqmem) % assume it's 20%*30% more than required to allow for other side variables
                fprintf('No caching will be used, there is enough memory \n');
                carr.caching = 0;
            else
                warning('Not enough memory: caching will be used. Processing time will be slower. ');
                carr.caching = 1;
            end
            
            if (carr.caching == 0)
                carr.data = zeros(size, type);
            else
                carr.data = 0;
                if (sum(num_chunks) == 0) % need to divide memory into number of chunks
                    gb = 8; % assume each chunk will be no more than 8 gb
                    num_chunks = floor(reqmem/(gb*1024^3));
                    if (num_chunks == 0)
                        error('Not enough memory for split, possible resolve: consider splitting along another dimension. Or, consider splitting along two dimensions (not supported in this version).');
                    end
                    
                end
            end
            
            carr.nchunks = num_chunks;
            
            if ~exist(path_cache)
                mkdir(path_cache);
            else
                if (carr.caching == 1)
                    delete([path_cache var_name '*.dat']);
                    warning('Cache folder has been cleared from previous cache data.');
                end
            end
        end
        
        % write
        function carr = write_cached_array_chunk(carr, chunk, idx_chunk) % carr.write_cached_array_chunk(chunk, idx_chunk)
            if (carr.caching == 1)
                fname = [carr.vname '_' num2str(idx_chunk) '.dat'];
                fid = fopen([carr.path fname], 'Wb');
                fwrite(fid, chunk, carr.type);
                fclose(fid);
                if (idx_chunk ==  1)
                    carr.data = chunk; % prepare data for the first use
                end
            else
                batchsize = ceil(carr.dimension(carr.broken) / carr.nchunks);
                indices = zeros(1, size(carr.dimension, 2)+1);
                indices(carr.broken) = batchsize*(idx_chunk-1)+1; % obtain vector of form [0 0 0 1 1 0] -> (:,:,:,1:1,:)
                if (idx_chunk < carr.nchunks)
                    indices(carr.broken+1) = batchsize*idx_chunk;
                else
                    indices(carr.broken+1) = size(carr.data, carr.broken);
                end
                expr_ind = ind2str_wr(indices);
                eval(['carr.data' expr_ind '=chunk;']);
                %if (idx_chunk < carr.nchunks)
                %    carr.data(:,batchsize*(idx_chunk-1)+1:batchsize*idx_chunk,:,:) = chunk;
                %else
                %    carr.data(:,batchsize*(idx_chunk-1)+1:end,:,:) = chunk;
                %end
            end
        end
        
        % read
        function chunk_x = read_cached_array(carr, indices)
            % example of indices = [0, 0, 1, 1]; % zero stands for ':'
            % so it would be the same as cacharr(:, :, 1, 1);
            
            % check indices have the right dimension
            if (size(indices, 2) ~= size(carr.dimension,2))
                fprintf('indices size: %i\n', size(indices, 2));
                error('Indices length is too large or too small, the read data might be not correct');
            end
            
            % check the indices are in the right dimension range
            if (sum(indices(:) > carr.dimension(:)) > 0)
                %if (indices(3) > cacharr.dimensions(3) || indices(4) > cacharr.dimensions(4))
                fprintf('Exceeding indices:');
                fprintf('%i ', indices(:));
                fprintf('\nOutof: ');
                fprintf('%i ', carr.dimension(:));
                fprintf('\n');
                fprintf('Other caching data: size(data) = ');
                fprintf('%i ', size(carr.data));
                error('Index exceeds matrix dimensions.');
            end
            
            if (carr.caching == 1)
                nc = carr.nchunks; % number of chunks
                ix = carr.broken; % idx of broken dimension
                nx = carr.dimension(ix); % total number of dimensions
                dx = ceil(nx/nc); % number of dimensions per chunk
                idx_chunk = ceil(indices(ix)/dx); % filename calculation
                idx_data = mod(indices(ix), dx); % current chunk data offset based on broken idx
                if (idx_data == 0)
                    idx_data = dx;
                end
                if (idx_chunk > carr.currchunk && idx_chunk > 1)
                    mm = memmapfile([carr.path carr.vname '_' num2str(idx_chunk) '.dat'], 'Format', carr.type);
                    carr.currchunk = idx_chunk;
                    if (idx_chunk == nc)
                        dx = nx-(nc-1)*dx; % the last chunk might have different size in broken dimension
                    end
                    %dims = [cacharr.dimensions(1), cacharr.dimensions(2), dx, cacharr.dimensions(4)];
                    dims = carr.dimension;
                    dims(ix) = dx; % broken dimension has different size than original array
                    carr.data = reshape(mm.Data, dims);
                end
                ind = indices;
                ind(ix) = idx_data;
                %expr_ind = ind2str_rd(ind);
                %chunk_x = eval(['cacharr.data' expr_ind  ';']); % general, N-dimensional array
                %chunk_x = cacharr.data(:,:,idx_data, indices(4)); % in order to create more general chunk reader, try to use eval function here
            else
                ind = indices;
                %expr_ind = ind2str_rd(indices);
                %chunk_x = eval(['cacharr.data' expr_ind ';']);
                %chunk_x = cacharr.data(:,:,indices(3), indices(4));
            end
             expr_ind = ind2str_rd(ind);
             chunk_x = eval(['carr.data' expr_ind  ';']); % general, N-dimensional array
        end
        
    end 
end

% Converts array of indices of form [0 1 5 0] into string '(:,1:5,:)' for
% further eval function usage (used in write function)
function expr = ind2str_wr(indices)
expr = '(';
f = 0;
for i = 1:size(indices,2)
    if (indices(i) == 0) % take all elements - ':'
        expr = strcat(expr, ':,');
    else % write down the index number
        if (~f)
            expr = strcat(expr, [num2str(indices(i)) ':']);
            f = 1;
        else
            expr = strcat(expr, [num2str(indices(i)) ',']);
        end
    end
end
expr(end) = ')'; % get rid of the comma at the end and close the braket
end

% Converts array of indices of form [0 0 2 0] into string '(:,:,2,:)' for
% further eval usage (used in read function)
function expr = ind2str_rd(indices)
expr = '(';
for i = 1:size(indices,2)
    if (indices(i) == 0) % take all elements - ':'
        expr = strcat(expr, ':,');
    else % write down the index number
        expr = strcat(expr, [num2str(indices(i)) ',']);
    end
end
expr(end) = ')'; % get rid of the comma at the end and close the braket
end

function path_platform = path_corrected(path)
archstr = computer('arch');
if (strcmp(path(end), '\') || strcmp(path(end), '/'))
    path = path(1:end-1);
end
path_platform = path;
if (isequal(archstr(1:3), 'win')) % Windows
    path_platform = [path_platform '\'];
elseif (isequal(archstr(1:5),'glnxa')) % Linux
    path_platform = [path_platform '/'];
else % other
    error('Unrecognized or unsupported architecture');
end
end

function reqmem = whos(size, type)
if isequal(type, 'single') 
    reqmem = 4; % bytes for single
else
    reqmem = 8; % assume it's double otherwise
end 
for i = 1:length(size)
    reqmem = reqmem*size(i); % total size of variable in bytes
end
end

