function fname = get_fname(path, var_name, idx_chunk)
fname = [path var_name num2str(idx_chunk) '.dat'];