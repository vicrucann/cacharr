% Tester for caching function
% The caching data structure assumes user processes their data in chunks
% SEQUENTIALLY
% The user is responsible for chunk size determination and dimension
% breakage
% Victoria Rudakova 2015, victoria.rudakova(at)yale.edu

clear; clc;

% simple test
dims = [800, 800, 100];
type = 'single';
idx_broken = 1;
num_chunks = 2;

CA = CachedArray(dims, type, idx_broken, 'simple', 'cache', num_chunks);
size_chunk = CA.lenchunk;
for b = 1 : num_chunks
    CA(size_chunk*(b-1)+1:size_chunk*b,:,:) = rand(size_chunk,dims(2),dims(3));
end
for b = 399 : dims(idx_broken)-10
    chunk_x = CA(b:b+10, :, :);
end

% application test - large image processing

% dims = [800, 1000, 500, 100]; % size of the allocated array
% type = 'single'; % array type
% idx_broken = 2; % which dimension will be broken
% %carr = create_cached_array(dims, path, type, num_chunks, idx_broken, caching);
% %carr = Cacharr(dims, path, type, num_chunks, idx_broken, caching, 'carr');
% carr = CachedArray(dims, type, idx_broken); %, caching, path, 'carr', num_chunks);
% 
% for i = 1 : carr.nchunks
%     chunk_len = floor(dims(2)/carr.nchunks);
%     chunk = rand([dims(1) chunk_len], type); % last chunk may be different in size!
%     %carr(:, 1:chunk_len, 1, 2) = chunk;
%     %carr.write_cached_array_chunk(chunk, i);
%     
%     % The loop does not need to be continious - read and write could be
%     % used in different loops, unless the usage is sequential
%     chunk_x = carr(:, 1:chunk_len, 1, 2);
%     %chunk_x = carr.read_cached_array([0, (i-1)*dims(2)/num_chunks+50, 0, 1]);
%     cx = chunk(:,50,:,1);
%     if (~isequal(chunk_x, cx))
%         error('Matrix equality failed');
%     end
%     progress_bar(i, num_chunks);
% end
% fprintf('\n');