% test CachedNDArray class

clear;
clc;

dims = [20 20];
broken = 1;
type = 'int8';
nchunks = 2;

cnda = CachedNDArray(dims, type, broken, 'tmp', 'cache', nchunks);
for i = 1:dims(1)-1
    line = ones(2,dims(2))*i;
    cnda(i:i+1,:) = line;
end
cnda.flush();

for j = 1:3:dims(1)-3
    line3 = cnda(j:j+3,:);
end