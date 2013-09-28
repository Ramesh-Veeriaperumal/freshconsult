define([
  'text!templates/search/group.html'
], function(groupTemplate){
	var _view = null;
	var $ = jQuery;
	var GroupsView = Backbone.View.extend({
		render:function(date, time){
			date.setHours(0,0,0,0);
			var group_id = "group_"+date.getTime();
			if($("#"+group_id).length>0){
				return group_id;
			}
			var groupDiv = $('<div>');
			groupDiv.attr("id",group_id);
			groupDiv.addClass("rsltgrp");
			time = new Date(time);
			$('#search_chat_list').append(groupDiv.html(_.template(groupTemplate,{date:$.datepicker.formatDate("D, M dd 'at '",time) + time.toString("hh:mm tt")})));
			return group_id;
		}
	});

	if(!_view){_view = new GroupsView;}

	return _view;
});