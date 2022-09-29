
local require, assert, tonumber, tostring, print = require, assert, tonumber, tostring, print;
local args = args;
local jit, os, string, table = jit, os, string, table;

local uv = require('uv');
local luvi = require('luvi');
local extension, json, path;

local jit_os = jit.os;
local bundle = luvi.bundle;
local format = string.format;
local insert = table.insert;
local execute = os.execute;

bundle.register('base', 'path/base.lua');
bundle.register('path', 'path/init.lua');
bundle.register('core', 'core.lua');
bundle.register('los', 'los.lua');
bundle.register('extension', 'extension.lua');
bundle.register('json', 'dkjson.lua');
extension = require('extension');
json = require('json');
path = require('path');

local USER_HOME_DIRECTORY 	= uv.os_homedir();
local ENV_VARIABLE_SET		= jit_os == 'Windows' and 'setx %s "%s"'								or jit_os == 'Linux' and 'export %s="%s"' or nil;
local ENV_VARIABLE_DISPLAY	= jit_os == 'Windows' and '%%%s%%'										or jit_os == 'Linux' and '$%s' or nil;
local BINARY_DIRECTORY 		= jit_os == 'Windows' and path.join(USER_HOME_DIRECTORY, 'luvit-bin')	or jit_os == 'Linux' and path.join('usr', 'bin') or nil;
local BINARY_EXTENSION 		= jit_os == 'Windows' and '.exe' 										or jit_os == 'Linux' and '' or nil;
local LIB_EXTENSION			= jit_os == 'Windows' and '.dll'										or jit_os == 'Linux' and '.so' or nil;
local GITHUB_REP_DIRECTORY	= jit_os == 'Windows' and path.join(USER_HOME_DIRECTORY, 'Documents', 'Github') or nil;
local LUVIT_EXE 			= 'luvit'..BINARY_EXTENSION;
local LUVI_EXE 				= 'luvi'..BINARY_EXTENSION;
local LIT_EXE 				= 'lit'..BINARY_EXTENSION;
local VSCODE_FOLDER			= '.vscode';
local VSCODE_SETTINGS		= path.join(VSCODE_FOLDER, 'settings.json');
local BASE_LUA_PATH			= './?.lua'; --path.join('.', '?.lua');
local MODULE_LUA_PATH		= './?/init.lua'; --path.join('.', '?', 'init.lua');
local LIBRARY_LUA_CPATH		= './?'..LIB_EXTENSION; --path.join('.', '?'..LIB_EXTENSION);
local GLOBAL_LUVIT_PATH		= path.join(BINARY_DIRECTORY, LUVIT_EXE);
local GLOBAL_LUVI_PATH		= path.join(BINARY_DIRECTORY, LUVI_EXE);
local GLOBAL_LIT_PATH		= path.join(BINARY_DIRECTORY, LIT_EXE);
local COMBINED_LUA_PATH 	= BASE_LUA_PATH..';'..MODULE_LUA_PATH;
local MAX_PERMS				= tonumber('777', 8);
local ENV_BUFFER_SIZE		= 32767;
local VERSION				= 1;

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
	print('Checking for luvit, luvi and lit binaries');
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
			print(name..' binary already moved');
		else
			print(name..' binary found');
			print('Moving binaries to '..BINARY_DIRECTORY);
			assert(uv.fs_rename(binary_path, global_path));
		end;
	end;
end;

--setting variables has to change
local setupEnvironmentVariables = function()
	local env_PATH = format(ENV_VARIABLE_DISPLAY, 'PATH');
	local env_LUA_PATH = format(ENV_VARIABLE_DISPLAY, 'LUA_PATH');
	local env_LUA_CPATH = format(ENV_VARIABLE_DISPLAY, 'LUA_CPATH');
	-- Add binary directory to standard path
	print('Checking '..env_PATH);
	local binary_path = assert(uv.os_getenv('PATH', ENV_BUFFER_SIZE));
	if (not binary_path) then
		print('Setting binary directory "'..BINARY_DIRECTORY..'" to '..env_PATH);
		os_setenv('PATH', BINARY_DIRECTORY..';');
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
			os_setenv('PATH', binary_path..BINARY_DIRECTORY..';');
		end;
	end;

	-- Add project paths to standard lua path
	print('Checking '..env_LUA_PATH);
	local lua_path = assert(uv.os_getenv('LUA_PATH', ENV_BUFFER_SIZE));
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
				print(env_LUA_CPATH..' already has the library project path '..tostring(ns_found));
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
	print('Checking '..env_LUA_CPATH);
	local lua_cpath = assert(uv.os_getenv('LUA_CPATH', ENV_BUFFER_SIZE));
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

local createGitIgnore = function()
	assert(not fs_exists('.gitignore', 'file'), '.gitignore found in current directory');
	print('Creating .gitignore');
	local fd = assert(uv.fs_open('.gitignore', 'w', MAX_PERMS));
	local body = assert(bundle.readfile('.gitignore'), '.gitignore not found');
	assert(uv.fs_write(fd, body, 0));
	print('Created .gitignore');
	return assert(uv.fs_close(fd));
end;

local createEditorConfig = function()
	assert(not fs_exists('.editorconfig', 'file'), '.gitignore found in current directory');
	print('Creating .editorconfig');
	local fd = assert(uv.fs_open('.editorconfig', 'w', MAX_PERMS));
	local body = assert(bundle.readfile('.editorconfig'), '.editorconfig not found');
	assert(uv.fs_write(fd, body, 0));
	print('Created .editorconfig');
	return assert(uv.fs_close(fd));
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

local includeGithubLibraries = function(libs)
	local n = #libs;
	assert(n > 0, 'no libraries detected');
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
		local library_path = path.join(GITHUB_REP_DIRECTORY, libs[i]);
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

local includeStandardLibraries = function(libs)
	local n = #libs;
	assert(n > 0, 'no libraries detected');
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

do
	local fx_flag = args[1];
	if (fx_flag == '--setup' or fx_flag == '-s') then
		local location = args[2];
		moveBinaries(location);
		setupEnvironmentVariables();
	elseif (fx_flag == '--version' or fx_flag == '-v') then
		print('SimpleLuv v'..tostring(VERSION));
	elseif (fx_flag == '--help' or fx_flag == '-h') then
		print('SimpleLuv v'..tostring(VERSION));
		print('alphafantomu [https://github.com/alphafantomu/simple-luv]');
		print('usage: simpleluv [flags] [...]\n');
		print(bundle.readfile('help.txt'));
	elseif (fx_flag == '--githublink' or fx_flag == '-gl') then
		assert(jit_os == 'Windows', 'only windows operating systems can link using github desktop');
		local libs = extension.table.slice(args, 2, #args);
		validWorkspace();
		includeGithubLibraries(libs);
	elseif (fx_flag == '--link' or fx_flag == '-l') then
		local libs = extension.table.slice(args, 2, #args);
		validWorkspace();
		includeStandardLibraries(libs);
	elseif (fx_flag == '--gitignore' or fx_flag == '-gi') then
		createGitIgnore();
	elseif (fx_flag == '--editorconfig' or fx_flag == '-ec') then
		createEditorConfig();
	else print('missing function flags, try using --help for a list of flags');
	end;
end;

uv.run();