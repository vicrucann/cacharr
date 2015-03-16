% Tester for caching function
% The caching data structure assumes user processes their data in chunks
% The user is responsible for chunk size determination and dimension
% breakage
% Victoria Rudakova 2015, victoria.rudakova(at)yale.edu

dims = [1000, 1000, 100, 100]; % size of the allocated array
type = 'single'; % array type
path = 'cache/\'; % cached folder, the data will be saved as num2str(i).dat
num_chunks = 20; % number of total chunks
idx_broken = 2; % which dimension will be broken
caching = -1; % 0 for caching OFF, 1 for caching ON, -1 automatic caching
carr = create_cached_array(dims, path, type, num_chunks, idx_broken, caching);

for i = 1 : num_chunks
    chunk = rand([dims(1) dims(2)/num_chunks dims(3) dims(4)], type);
    carr = write_cached_array(carr, chunk, i);
    
    chunk_x = read_cached_array(carr, [0, 300, 0, 1]);
    if (~isequal(chunk_x, chunk(:,300,:,1)))
        error('Matrix equality failed');
    end
    progress_bar(i, num_chunks);
end