#remove files from 2i2c

#remove data file
cmd = paste0("rm '", file_loc, "'")
system(cmd)

#remove figures
cmd1 = paste0("rm -r ", curr_dir, "/figs/")
system(cmd1)

