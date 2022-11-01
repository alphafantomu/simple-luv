
local args = args; ---@diagnostic disable-line
local require, print, unpack, xpcall = require, print, unpack, xpcall;
local format = string.format;
local exit = os.exit;

local uv = require('uv');
local extension = require('discordia-extensions');
local bin_package = require('./package.lua');

local VERSION_FORMAT = 'SimpleLuv version: %s';
local REPO_FORMAT = 'GitHub Open Source Repository <%s>';

local help = [=[

SimpleLuv Commands
==================
simpleluv setup				Moves Luvit, Luvi, and Lit binaries to a global binary directory then
simpleluv link <...>			Links libraries to the project directory with relative or absolute paths, usable only for VSCode
simpleluv githublink <...>		Links libraries to the project directory starting in Github Desktop's Repository Directory, usable only for VSCode
simpleluv gitignore			Creates a .gitignore file for the project directory, used for ignoring file extensions like .dll and .so.
simpleluv editorconfig			Creates a .editorconfig for the proejct directory, used for tabbing when reading code from GitHub Repositories.
]=];

local alias = {
	['-s'] = 'setup';
	['-h'] = 'help';
	['-gl'] = 'githublink';
	['-l'] = 'link';
	['-gi'] = 'gitignore';
	['-eg'] = 'editorconfig';
};

local getCommandFromArguments = function(t)
	local cmd = t[1] or 'help';
	if (cmd:sub(1, 2) == '--') then
		cmd = cmd:sub(3);
	end;
	cmd = alias[cmd] or cmd;
	return cmd;
end;

local executeCommand = function(cmd, t)
	if (cmd == 'help') then
		return print(help);
	end;
	local handler = require('./commands/'..cmd);
	return handler(unpack(t));
end;

local printStandard = function()
	print('');
	print(format(VERSION_FORMAT, bin_package.version));
	print(format(REPO_FORMAT, bin_package.homepage));
end;

coroutine.wrap(function()
	printStandard();
	local cmd = getCommandFromArguments(args);

	local res, msg = xpcall(function()
		return executeCommand(cmd, extension.table.slice(args, 2));
	end, debug.traceback);

	if (not res) then
		print(msg);
		return exit(1);
	end;

	return exit(0);
end)();

uv.run();