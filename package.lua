return {
	name = 'alphafantomu/simpleluv',
	version = '1.2.0',
	description = 'a self-contained binary that helps with setting up for a new project or for future projects for Luvit',
	tags = { 'luvi', 'lit', 'binary', 'setup'},
 	license = 'MIT',
	author = {name = 'Ari Kumikaeru'},
	homepage = 'https://github.com/alphafantomu/simple-luv',
	dependencies = {
		'luvit/require';
		'luvit/json';
    	'alphafantomu/discordia-extensions';
    },
    files = {
		'**.lua',
		'assets/**',
		'!test*',
		'!deps'
	}
}