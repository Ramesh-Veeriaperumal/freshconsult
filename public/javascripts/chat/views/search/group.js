define([
  'text!templates/search/group.html'
], function(groupTemplate){
	var _view = null;
	var GroupsView = Backbone.View.extend({
		render:function(date){
			date.setHours(0,0,0,0);
			var group_id = "group_"+date.getTime();
			if(jQuery("#"+group_id).length>0){
				return group_id;
			}
			var groupDiv = jQuery('<div>');
			groupDiv.attr("id",group_id);
			groupDiv.addClass("rsltgrp");
			jQuery('#search_chat_list').append(groupDiv.html(_.template(groupTemplate,{date:jQuery.datepicker.formatDate('DD, MM dd, yy',date)})));
			return group_id;
		}
	});

	if(!_view){_view = new GroupsView;}

	return _view;
});