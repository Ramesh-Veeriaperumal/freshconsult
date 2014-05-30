define([
  'text!templates/layout.html'
], function(layoutTemplate){
	var $ = jQuery;
	var _view = null;
	var LayoutView = Backbone.View.extend({	 	
		el: "#freshchat_layout",
		render:function(){
			$(this.el).append(_.template(layoutTemplate));
		}
	 });

	if(!_view){_view = new LayoutView;}

	return _view;
});