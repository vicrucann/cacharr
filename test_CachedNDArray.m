% test CachedNDArray class

clear;
clc;

dims = [20 10 2];
broken = 1;
type = 'double';
nchunks = 2;

cnda = CachedNDArray(dims, type, broken, 'tmp', 'cache', nchunks);
for i = 1:dims(1)-1
    line1 = ones(2,dims(2),1)*i;
    line2 = -line1;
    if (i == 19)
        fprintf('test case\n');
    end
    cnda(i:i+1,:,1) = line1;
    cnda(i:i+1,:,2) = line2;
end
cnda.flush();

for j = 1:3:dims(1)-3
    line3 = cnda(j:j+3,:);
end