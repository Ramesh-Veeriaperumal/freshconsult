define([], function(){
	var Profile = Backbone.Model.extend({
		 urlRoot: "/user/edit",
		defaults : {
		  "username"		:  "",
		  "chat_name"		:  "",
		  "job_title"		:  "",
		  "location"		:  ""
    	},                                                                                                          
	});
	return Profile;
});
