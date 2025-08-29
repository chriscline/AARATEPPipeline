function modTime = c_path_getLastModTime(filePath)

assert(ischar(filePath));

listing = dir(filePath);
assert(length(listing)==1);
modTime = datetime(listing(1).datenum, 'convertFrom', 'datenum');

end