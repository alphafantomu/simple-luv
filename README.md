# simple-luv
A self-contained binary CLI that helps with setting up for a new project or for future projects for Luvit. Supports Windows and Linux but Linux hasn't been tested

# Build
Install [Luvi](https://github.com/luvit/luvi), change to the SimpleLuv directory and run `luvi . -o simpleluv`

# Usage
- `--version` `-v`: Shows current SimpleLuv version
- `--setup` `-s` [location]: Moves Luvit, Luvi, and Lit binaries to a global binary directory then adds that directory to PATH, LUA_PATH and LUA_CPATH is adjusted to have an easy require in project folder.
- `--help` `-h`: Shows the help menu
- `--githublink` `-gl` [paths]: Links libraries to the project directory for SumNeko's LLS but starts in Github Desktop's Repository Directory
- `--link` `-l` [paths]: Links libraries to the project directory with relative or absolute paths
- `--gitignore` `-gi`: Creates a .gitignore file for the project directory, used for ignoring certain file extensions like .dll and .so.
- `--editorconfig` `-ec`: Creates a .editorconfig for the proejct directory, used for tabbing when reading code from GitHub Repositories.

# License
[MIT License](LICENSE)

# Contact
- Discord: `Arivistraliavatoriar#2678`