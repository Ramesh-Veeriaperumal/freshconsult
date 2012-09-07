var FD = FD || {};
FD.Notifications = (function($){
	var options = {
		sticky:false,
		pollUrl : '/helpdesk/notifications',
		pollInterval: 10000,
		image : '/images/badges/trophy.png',
		time : 8000,
		position : 'bottom-right',
		fade_in_speed: 10,
		fade_out_speed: 2000,
	},
	publish = function(feeds){
		$.each(feeds,function(index,feed) {
			var feed = $.parseJSON(feed),
				feedData = { text: feed.body.message, image : feed.body.icon, title:''},
				gritterOpts = $.extend(true,{},options,feedData);
			$.gritter.add(gritterOpts);
		})
	},
	initialize = function(){
		var fn = function() {
			$.getJSON(options.pollUrl,publish);
		};
		if(options.pollInterval){
			requestInterval(fn,options.pollInterval)
		}
		fn();
	};
	return {
		init : function(opts){
			$.extend(options,opts);
			initialize();
		}
	}
})(jQuery)