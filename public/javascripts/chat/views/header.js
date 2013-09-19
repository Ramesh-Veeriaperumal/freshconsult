define([
  'text!templates/header.html',
  'views/settings',
  'views/header/profile',
  'views/visitor_list'
], function(headerTemplate,settingsView,profileView,visitorList){
	var $ = jQuery;
	var _view = null;
	var HeaderView = Backbone.View.extend({	 	
			el:"#header_container",
		 	render:function(){
		 		$("#header_container").append(_.template(headerTemplate,{current_user:CURRENT_USER}));
		 		this._listeners();		 		
		 	},
		 	_listeners:function(){		 		
		 		$("#visitor-script").on('click', function(){
		 			settingsView.render();
		 			$('#nav_options').slideToggle('slow');
		 			$('#nav_icon').removeClass().addClass('icon-cog');
		 			$('#live-visitors').removeClass('active-icon');
		 			$(this).addClass('active-icon');		 			
		 		 });
		 		$("#live-visitors").on('click', function(){		 			
		 			$('#nav_options').slideToggle('slow');
		 			$('#nav_icon').removeClass().addClass('icon-comments');
		 			$('#visitor-script').removeClass('active-icon');
		 			$(this).addClass('active-icon');
		 			visitorList.fetch();
		 		 });		 		
		 		$('#user-icon').on('click', function(event){
		 			event.stopPropagation();
		 			$('#userProfile').slideToggle('slow');
		 			$('#nav_options').hide('slow');
		 		});
		 		$('#navigator').on('click', function(event){
		 			event.stopPropagation();
		 			$('#nav_options').slideToggle('slow');
		 			$('#userProfile').hide('slow');
		 		});
		 		$('#header-profile-view').on('click', function(event){
		 			event.stopPropagation();
		 			profileView.render();
		 			$('#userProfile').slideToggle('slow');
		 		});
		 	}
	 	});

	   if(!_view){_view = new HeaderView;}

	return _view;

});