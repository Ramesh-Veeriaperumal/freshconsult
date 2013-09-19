// This set's up the module paths for underscore and backbone
require.config({ 
	'urlArgs': 'v0.1',
	'baseUrl': WEB_ROOT+'/javascripts/chat',
	'paths': {
		"cookies" : "../frameworks/plugins/jquery.cookie",
		"underscore": "lib/underscore-min",
		"backbone": "lib/backbone-min"
	},
	'shim': {
		backbone: {
			'deps': ['underscore'],
			'exports': 'Backbone'
		},
		underscore: {
			'exports': '_'
		}
	}
});

require([
	'underscore',
	'backbone',
	'customer/widget'
	],
	function(_, Backbone, widget){
		window._= _;
		widget.init();
});