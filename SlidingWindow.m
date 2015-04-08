classdef SlidingWindow < handle
    
    % Initialization:
    % Given chunk size and global dimensions, fopen and fwrite the cached
    % files with zeros. It is necessary so that when re-writing, we could
    % use memmapfile functionality which is faster than fwrite.
    
    % Two main functions:
    % WRITE: X() = blob; - assignment
    % READ: blob = X(); - reference
    
    % WRITE algorithm
    % 
    
properties (GetAccess = 'public', SetAccess = 'private')    
    data; % contains N-d matrix which is a part of CachedArray
    border; % pair of values that denote location of the window (first and last element)
    dimension; % window dimension, the broken dimension will be of size = (border.last-border.first)
end

methods
    function sw = SlidingWindow()
    end
    
    
    
end

end