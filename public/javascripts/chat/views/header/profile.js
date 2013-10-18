define([
  'text!templates/header/profile.html',
  'models/profile',
], function($,_, Backbone,profileTemplate,Profile){
	var _view = null;
	var ProfileView = Backbone.View.extend({
	 	render:function(){
	 		var that = this;
	 		that.profile = new Profile();
	 		if(CURRENT_USER.id)
	 		{
	 		    that.profile.fetch({
	 		    	error: function(model, xhr, options){
	 		    	},
	 				success: function(model, xhr, options){  
	 					$('.container-fluid').html(_.template(profileTemplate,{profile:that.profile}));
	 					that._listeners();	
					},
	 			});
	 		}else{
	 			$('.container-fluid').html(_.template(profileTemplate,{}));
	 			that._listeners();
	 		}
	 	}, 	
	 	_listeners:function(){
 			var that = this;
 			$("#save").on('click', function(){
					that.profile.set({
			            chat_name     :$('#chat_name').val(),
			            job_title     :$('#job_title').val(),
			            location      :$('#location').val(),
			            image_data    :image_data
	       		 	});
	        		that.profile.urlRoot = "/user/update";
	            	that.profile.save();
			});
			$("#file_upload").on('change', function(event){
		             if (event.currentTarget.files && event.currentTarget.files[0])
		             {
		                var reader = new FileReader();
						reader.onload = function (e) {
							var image_data=e.target.result;
							$('#photo').attr('src', e.target.result); 
		                }
		                reader.readAsDataURL(event.currentTarget.files[0]);
		             }
			});
 			$("#cancel").on('click', function(){
 				that.render();
 			});
	 	},
	 });
	if(!_view){_view = new ProfileView();}
	return _view;
});

