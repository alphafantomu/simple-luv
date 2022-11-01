
local insert = table.insert;

local uv = require('uv');
local luvi = require('luvi');
local json = require('json');

local path = luvi.path;

local VSCODE_FOLDER			= '.vscode';
local MAX_PERMS				= tonumber(777, 8); ---@diagnostic disable-line
local VSCODE_SETTINGS		= path.join(VSCODE_FOLDER, 'settings.json');

local fs_exists = function(location, t)
	local data = uv.fs_stat(location);
	local res = data and data.type == (t or 'file');
	return res;
end;

local validWorkspace = function()
	if (not fs_exists(VSCODE_FOLDER, 'directory')) then
		assert(uv.fs_mkdir(VSCODE_FOLDER, MAX_PERMS));
		print('Created '..VSCODE_FOLDER..' directory');
	end;
	if (not fs_exists(VSCODE_SETTINGS, 'file')) then
		local fd = assert(uv.fs_open(VSCODE_SETTINGS, 'w+', MAX_PERMS));
		local default_data = json.encode{['Lua.workspace.library'] = {};};
		print('Created '..VSCODE_SETTINGS..' file');
		assert(uv.fs_write(fd, default_data, 0));
		assert(uv.fs_close(fd));
	end;
end;

return function(...)
	local libs = {...};
	local n = #libs;
	assert(n > 0, 'libraries not listed');
	validWorkspace();
	print('Getting workspace settings...');
	local vscode_settings_data = assert(uv.fs_stat(VSCODE_SETTINGS));
	local vscode_settings_size = vscode_settings_data.size;
	local fd = assert(uv.fs_open(VSCODE_SETTINGS, 'r+', MAX_PERMS));
	local body = assert(uv.fs_read(fd, vscode_settings_size, 0));
	-- Get current json body
	assert(uv.fs_close(fd));
	if (body == '') then
		body = '{"Lua.workspace.library":[]}';
	end;

	-- Decode to prepare for changes
	local settings = json.decode(body);

	-- Library list setup
	local library_paths = settings['Lua.workspace.library'];
	if (library_paths == nil) then
		library_paths = {};
		settings['Lua.workspace.library'] = library_paths;
	end;

	-- Add in all existing files
	print('Linking all paths...');
	for i = 1, n do
		local library_path = libs[i];
		assert(fs_exists(library_path, 'file') or fs_exists(library_path, 'directory'), 'library at path "'..library_path..'" not found');
		local n_paths = #library_paths;
		local found = false;
		for e = 1, n_paths do
			if (library_paths[e] == library_path) then
				print('Already linked'..library_path);
				found = true;
				break;
			end;
		end;
		if (not found) then
			insert(library_paths, library_path);
			print('Linked '..library_path);
		end;
	end;

	-- Encode and write updated json back and close
	fd = assert(uv.fs_open(VSCODE_SETTINGS, 'w+', MAX_PERMS));
	assert(uv.fs_write(fd, json.encode(settings), 0));
	assert(uv.fs_close(fd));
	print('Finished linking libraries');
end;