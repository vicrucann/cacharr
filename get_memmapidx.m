function idx = get_memmapidx(point, dims)
assert(sum(point > dims) == 0, 'Requested indices are out of range');
ndim = length(point);
idx = point(1);
len = 1;
for i = 2:ndim
    len = len * dims(i-1);
    idx = idx + (point(i) - 1) * len;
end
end