# simple-luv
A self-contained binary CLI that helps with setting up for a new project or for future projects for Luvit. Supports Windows and Linux but Linux hasn't been tested

# Installation
You can get the latest release [here](https://github.com/alphafantomu/simple-luv/releases/latest), only Windows x64 binaries are provided.

# Build
Install [lit](https://github.com/luvit/lit), change to the SimpleLuv directory and run `lit make .'

# Usage
- `simpleluv setup`				Moves Luvit, Luvi, and Lit binaries to a global binary directory then
- `simpleluv link <...>`			Links libraries to the project directory with relative or absolute paths, usable only for VSCode
- `simpleluv githublink <...>`		Links libraries to the project directory starting in Github Desktop's Repository Directory, usable only for VSCode
- `simpleluv gitignore`			Creates a .gitignore file for the project directory, used for ignoring file extensions like .dll and .so.
- `simpleluv editorconfig`			Creates a .editorconfig for the proejct directory, used for tabbing when reading code from GitHub Repositories.

# License
[MIT License](LICENSE)

# Contact
- Discord: `Arivistraliavatoriar#2678`
