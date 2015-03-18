% Tester for caching function
% The caching data structure assumes user processes their data in chunks
% SEQUENTIALLY
% The user is responsible for chunk size determination and dimension
% breakage
% Victoria Rudakova 2015, victoria.rudakova(at)yale.edu

clear; clc;

dims = [1000, 1000, 100, 100]; % size of the allocated array
type = 'single'; % array type
path = 'cache'; % cached folder, the data will be saved as num2str(i).dat
num_chunks = 20; % number of total chunks
idx_broken = 2; % which dimension will be broken
caching = 1; % 0 for caching OFF, 1 for caching ON, -1 automatic caching
%carr = create_cached_array(dims, path, type, num_chunks, idx_broken, caching);
carr = Cacharr(dims, path, type, num_chunks, idx_broken, caching, 'carr');

for i = 1 : num_chunks
    chunk = rand([dims(1) dims(2)/num_chunks dims(3) dims(4)], type);
    carr.write_cached_array_chunk(chunk, i);
    
    % The loop does not need to be continious - read and write could be
    % used in different loops, unless the usage is sequential
    chunk_x = carr.read_cached_array([0, (i-1)*dims(2)/num_chunks+50, 0, 1]);
    cx = chunk(:,50,:,1);
    if (~isequal(chunk_x, cx))
        error('Matrix equality failed');
    end
    progress_bar(i, num_chunks);
end
fprintf('\n');