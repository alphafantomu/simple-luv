
local uv = require('uv');
local luvi = require('luvi');

local bundle = luvi.bundle;

local MAX_PERMS = tonumber(777, 8); ---@diagnostic disable-line

local fs_exists = function(location, t)
	local data = uv.fs_stat(location);
	local res = data and data.type == (t or 'file');
	return res;
end;

return function()
	assert(not fs_exists('.gitignore', 'file'), '.gitignore exists');
	print('Creating .gitignore');
	local fd = assert(uv.fs_open('.gitignore', 'w', MAX_PERMS));
	local body = assert(bundle.readfile('assets/.gitignore'), 'saved .gitignore missing');
	assert(uv.fs_write(fd, body, 0));
	print('Created .gitignore');
	return assert(uv.fs_close(fd));
end;