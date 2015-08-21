% test CachedNDArray class

clear;
clc;

% small scale test
dims = [20 10 2];
broken = 1;
nchunks = 2;
fcaching = 1;
fdiscreet = 0;
ini_val = 0;

cnda = CachedNDArray(dims, broken, ...
    'nchunks', nchunks, 'fcaching', fcaching, 'type', 'single', 'fdiscreet', fdiscreet);
for i = 1:dims(1)-1
    line1 = ones(2,dims(2),1)*i;
    line2 = -line1;
    cnda(i:i+1,:,1) = line1;
    cnda(i:i+1,:,2) = line2;
end

cnda.flush();
linex = cnda(19:end, :, end); % check 'end' method
cnda(19:end, :, :) = rand(2,10,2);

% display the result matrix to make sure the assignment/read operator works
for j = 1:2:dims(1)-3
    line3 = cnda(j:j+2,:,:)
end

% larger scale example for continious vs. discreet methods
%fprintf('\nPress any key to continue on large-scale example\n');
%pause;

t_cont = 0;
t_discr = 0;

dims = [100, 1000, 100, 500];
broken = 2;
type = 'single';

tic;
fprintf('\nAllocation (cont):\n');
cnda = CachedNDArray(dims, broken, 'type', type, 'var_name', 'tmp-cnda-cnt', 'nchunks', 4, 'fdiscreet', 0, ...
    'fcaching', fcaching);
fprintf('done\n');
t_cont = t_cont + toc;

tic;
fprintf('\nAllocation (discr):\n');
cnda_= CachedNDArray(dims, broken,'type', type, 'var_name', 'tmp-cnda-dsc', 'nchunks', 4, 'ini_val', 1, ...
    'fcaching', fcaching);
fprintf('done\n');
t_discr = t_discr + toc;

cdim = dims;
clen = cnda.nchunks;
cdim(broken) = floor(dims(broken) / clen);
% write
tic;
fprintf('\nCreate chunk memory...');
chunk = rand(cdim, type);
fprintf('done\n');
tmp = toc;
t_cont = t_cont + tmp;
t_discr = t_discr + tmp;

tic;
fprintf('\nAssignment operator (cont)...');
cnda(:,1+244:floor(dims(broken) / clen)+244,:,:) = chunk;
fprintf('done\n');
t_cont = t_cont + toc;

%flush
tic;
fprintf('\nFlushing (cont)...')
cnda.flush(); % write changes to the corresponding file
fprintf('done\n');
t_cont = t_cont + toc;

tic;
fprintf('\nAssignment operator (discr+flush)...');
cnda_(:,1:floor(dims(broken) / clen),:,:) = chunk;
fprintf('done\n');
t_discr = t_discr + toc;

% read
tic;
fprintf('\nReference operator (cont)...');
%chunk_x = cnda(:, 1:floor(dims(broken) / clen),:,:);
chunk_x = cnda(1,245:255,:,:);
fprintf('done\n');
t_cont = t_cont + toc;

% read
tic;
fprintf('\nReference operator (discr)...');
%chunk_x = cnda(:, 1:floor(dims(broken) / clen),:,:);
chunk_x = cnda_(1,1:10,:,:);
fprintf('done\n');
t_discr = t_discr + toc;

% performance compare
fprintf('\nContinious vs discreet total: \n');
fprintf('%.1f     %.1f \n', t_cont, t_discr);
