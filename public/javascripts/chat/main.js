// This set's up the module paths for underscore and backbone
require.config({ 
		'urlArgs': 'v0.8',
	  'baseUrl': '/javascripts/chat'
});

require([
	'app',
	'views/flash'
	], 
	function(app, flashView){		
		window.flashView = flashView;
		app.init();
});
