function fname = get_fname(path, var_name, idx_chunk)
fname = [path '_' var_name '_' num2str(idx_chunk) '.dat'];