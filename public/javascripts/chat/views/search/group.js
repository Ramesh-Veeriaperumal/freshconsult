define([
  'text!templates/search/group.html'
], function(groupTemplate){
	var _view = null;
	var $ = jQuery;
	var GroupsView = Backbone.View.extend({
		render:function(results){
			var groupDiv = $('<div>');
			groupDiv.attr("id","search_results_grp");
			groupDiv.addClass("rsltgrp");
			var title = "";
			if(results.location){
				title = i18n.chat_with_loc;
				title = title.replace('$1',results.title).replace('$2',userCollection.get(results.userId).get('name')).replace('$3',results.location);
			}else{
				title = i18n.chat_with_noloc;
				title = title.replace('$1',results.title).replace('$2',userCollection.get(results.userId).get('name'));
			}

			var time = new Date(results.createdAt);
			$('#search_chat_list').append(groupDiv.html(_.template(groupTemplate,{title:title,date:$.datepicker.formatDate("D, M dd 'at '",time) + time.toString("hh:mm tt")})));
		}
	});

	if(!_view){_view = new GroupsView;}

	return _view;
});