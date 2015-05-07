% test CachedNDArray class

clear;
clc;

% small scale test
dims = [20 10 2];
broken = 1;
type = 'double';
nchunks = 2;

cnda = CachedNDArray(dims, type, broken, 'tmp', 'cache', nchunks);
for i = 1:dims(1)-1
    line1 = ones(2,dims(2),1)*i;
    line2 = -line1;
    cnda(i:i+1,:,1) = line1;
    cnda(i:i+1,:,2) = line2;
end

cnda.flush();
linex = cnda(19:end, :, end); % check 'end' method
cnda(19:end, :, :) = rand(2,10,2);
 
for j = 1:2:dims(1)-3
    line3 = cnda(j:j+2,:,:)
end
fprintf('\nPress any key to continue on large-scale example\n');
pause;

dims = [500, 1000, 500, 50];
broken = 2;
type = 'single';

tic;
fprintf('allocation:\n');
cnda = CachedNDArray(dims, type, broken, 'tmp-cnda', 'cache');
fprintf('done\n');
toc;

cdim = dims;
clen = cnda.nchunks;
cdim(broken) = floor(dims(broken) / clen);
% write
tic;
fprintf('create chunk memory...');
chunk = rand(cdim, type);
fprintf('done\n');
toc;

tic;
fprintf('assignment operator...');
cnda(:,1:floor(dims(broken) / clen),:,:) = chunk;
fprintf('done\n');
toc;

%flush
tic;
fprintf('flushing operator...')
cnda.flush();
fprintf('done\n');
toc;

% read
tic;
fprintf('reference operator...');
%chunk_x = cnda(:, 1:floor(dims(broken) / clen),:,:);
chunk_x = cnda(1,1,:,:);
fprintf('done\n');
toc;

%if (~isequal(chunk_x, chunk))
%    error('Matrix equality failed');
%end