
local format = string.format;
local execute = os.execute;

local uv = require('uv');
local luvi = require('luvi');
local extension = require('discordia-extensions');

local path = luvi.path;
local jit_os = jit.os;

local ENV_BUFFER_SIZE		= 32767;
local MAX_PERMS				= tonumber(777, 8); ---@diagnostic disable-line
local USER_HOME_DIRECTORY 	= uv.os_homedir();
local ENV_VARIABLE_SET		= jit_os == 'Windows' and 'setx %s "%s"'								or 'export %s="%s"';
local ENV_VARIABLE_DISPLAY	= jit_os == 'Windows' and '%%%s%%'										or '$%s';
local BINARY_DIRECTORY 		= jit_os == 'Windows' and path.join(USER_HOME_DIRECTORY, 'luvit-bin')	or path.join('usr', 'bin');
local BINARY_EXTENSION 		= jit_os == 'Windows' and '.exe' 										or '';
local LIB_EXTENSION			= jit_os == 'Windows' and '.dll'										or '.so';

local LUVIT_EXE 			= 'luvit'..BINARY_EXTENSION;
local LUVI_EXE 				= 'luvi'..BINARY_EXTENSION;
local LIT_EXE 				= 'lit'..BINARY_EXTENSION;

local BASE_LUA_PATH			= './?.lua'; --path.join('.', '?.lua');
local MODULE_LUA_PATH		= './?/init.lua'; --path.join('.', '?', 'init.lua');
local LIBRARY_LUA_CPATH		= './?'..LIB_EXTENSION; --path.join('.', '?'..LIB_EXTENSION);
local GLOBAL_LUVIT_PATH		= path.join(BINARY_DIRECTORY, LUVIT_EXE);
local GLOBAL_LUVI_PATH		= path.join(BINARY_DIRECTORY, LUVI_EXE);
local GLOBAL_LIT_PATH		= path.join(BINARY_DIRECTORY, LIT_EXE);
local COMBINED_LUA_PATH 	= BASE_LUA_PATH..';'..MODULE_LUA_PATH;

local fs_exists = function(location, t)
	local data = uv.fs_stat(location);
	local res = data and data.type == (t or 'file');
	return res;
end;

local qexecute = function(command)
	local res, _, code = execute(command);
	assert(res and code == 0, 'execute command encountered an error');
	return res, _, code;
end;

local os_setenv = function(name, value)
	local command = format(ENV_VARIABLE_SET, name, value);
	qexecute(command);
	if (jit_os == 'Linux') then
		assert(fs_exists('~/.bash_rc', 'file'), '.bash_rc not found in user directory');
		local fd = assert(uv.fs_open('~/.bashrc', 'a', MAX_PERMS));
		assert(uv.fs_write(fd, command..'\n', 0));
		return assert(uv.fs_close(fd));
	end;
end;

local moveBinaries = function(location)
	location = assert(location or USER_HOME_DIRECTORY, 'binaries cannot be found due to bad pathing, please specify -bp for binary path to search');
	local search = {
		luvit = path.join(location, LUVIT_EXE);
		luvi = path.join(location, LUVI_EXE);
		lit = path.join(location, LIT_EXE);
	};
	print('Checking for luvit, luvi and lit binaries\n');
	for name, binary_path in next, search do
		local installed = fs_exists(binary_path, 'file');
		local global_path = name == 'luvit' and GLOBAL_LUVIT_PATH or name == 'luvi' and GLOBAL_LUVI_PATH or name == 'lit' and GLOBAL_LIT_PATH or '';
		if (jit_os == 'Windows' and not fs_exists(BINARY_DIRECTORY, 'directory')) then
			print('Creating luvit-specific bins folder for Windows...');
			assert(uv.fs_mkdir(BINARY_DIRECTORY, MAX_PERMS));
		end;
		if (not installed) then
			print('Failed to find '..name..' binary');
			print('Checking for moved binary...');
			assert(fs_exists(global_path, 'file'), name..' binary not installed');
			print(name..' binary already moved\n');
		else
			print(name..' binary found');
			print('Moving binaries to '..BINARY_DIRECTORY..'\n');
			assert(uv.fs_rename(binary_path, global_path));
		end;
	end;
end;

local setupEnvironmentVariables = function()
	local env_PATH = format(ENV_VARIABLE_DISPLAY, 'PATH');
	local env_LUA_PATH = format(ENV_VARIABLE_DISPLAY, 'LUA_PATH');
	local env_LUA_CPATH = format(ENV_VARIABLE_DISPLAY, 'LUA_CPATH');

	print('Checking '..env_PATH..'\n');
	local binary_path = uv.os_getenv('PATH', ENV_BUFFER_SIZE);
	if (not binary_path) then
		print('Setting binary directory "'..BINARY_DIRECTORY..'" to '..env_PATH);
		os_setenv('PATH', BINARY_DIRECTORY);
	else
		local paths = extension.string.split(binary_path, ';');
		local n = #paths;
		local found = false;
		for i = 1, n do
			if (paths[i] == BINARY_DIRECTORY) then
				print(env_PATH..' already has the binary directory');
				found = true;
				break;
			end;
		end;
		if (not found) then
			print('Adding binary directory "'..BINARY_DIRECTORY..'" to '..env_PATH);
			print('heh?', binary_path, BINARY_DIRECTORY);
			os_setenv('PATH', BINARY_DIRECTORY);
		end;
	end;

	-- Add project paths to standard lua path
	print('\nChecking '..env_LUA_PATH..'\n');
	local lua_path = uv.os_getenv('LUA_PATH', ENV_BUFFER_SIZE);
	if (not lua_path) then
		print('Setting project paths "'..COMBINED_LUA_PATH..'" to '..env_LUA_PATH);
		os_setenv('LUA_PATH', COMBINED_LUA_PATH..';');
	else
		local paths = extension.string.split(lua_path, ';');
		local n = #paths;
		local ns_found, last_path = 0, nil;
		for i = 1, n do
			local target_path = paths[i];
			if (target_path == BASE_LUA_PATH or target_path == MODULE_LUA_PATH) then
				ns_found = ns_found + 1;
				last_path = target_path;
				print(env_LUA_PATH..' already has the library project path '..tostring(ns_found));
				if (ns_found >= 2) then
					break;
				end;
			end;
		end;
		if (ns_found < 2) then
			local add_path = (ns_found == 0 and COMBINED_LUA_PATH) or ns_found == 1 and (last_path == BASE_LUA_PATH and MODULE_LUA_PATH or last_path == MODULE_LUA_PATH and BASE_LUA_PATH);
			if (add_path) then
				print('Adding project paths "'..add_path..'" to '..env_LUA_PATH);
				os_setenv('LUA_PATH', lua_path..add_path..';');
			end;
		end;
	end;

	-- Add project paths to standard lua c path
	print('\nChecking '..env_LUA_CPATH..'\n');
	local lua_cpath = uv.os_getenv('LUA_CPATH', ENV_BUFFER_SIZE);
	if (not lua_cpath) then
		print('Setting project path "'..LIBRARY_LUA_CPATH..'" to '..env_LUA_CPATH);
		uv.os_setenv('LUA_CPATH', LIBRARY_LUA_CPATH..';');
	else
		local paths = extension.string.split(lua_cpath, ';');
		local n = #paths;
		local found = false;
		for i = 1, n do
			local target_path = paths[i];
			if (target_path == LIBRARY_LUA_CPATH) then
				print(env_LUA_CPATH..' already has the library project path');
				found = true;
				break;
			end;
		end;
		if (not found) then
			print('Adding project paths "'..LIBRARY_LUA_CPATH..'" to '..env_LUA_CPATH);
			os_setenv('LUA_CPATH', lua_cpath..LIBRARY_LUA_CPATH..';');
		end;
	end;
end;

return function()
	moveBinaries();
	setupEnvironmentVariables();
end;