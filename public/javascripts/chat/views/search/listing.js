define([
  'views/search/group',
  'text!templates/search/listing.html'
], function(groupView,listingTemplate){
	var _view = null;
	var $ = jQuery;
	var ResultsView = Backbone.View.extend({
	 	render:function(data){
	 		$("#search_results_list").hide();
	 		$("#search_results_expand").show();
	 		$("#search_chat_hdr span").eq(0).unbind().bind('click',function(){
	 			$("#search_results_list").show();
	 			$("#search_results_expand").hide();
	 			$(window).scrollTop(0);
	 		});
	 		$("#search_chat_hdr span").eq(1).unbind().bind('click',function(){
	 			chat_socket.emit('join chat',{
	 				id: data.id
	 			})
	 		});
	 		if(data.closed){
	 			$("#search_chat_hdr span").eq(1).hide();
	 		}else{
	 			$("#search_chat_hdr span").eq(1).show();
	 		}
	 		this.chatviews(data.messages);
	 	},	
	 	chatviews:function(results){
	 		var len = results.length;
			$('#search_chat_list').html("");
	 		for(var r=0; r<len; r++){
				var date = new Date(results[r].createdAt);
				var group_id = groupView.render(date);
				var resDiv = $('<div>');
				date = new Date(results[r].createdAt);
				var resObj = {name: results[r].name, time:date.getHours()+":"+date.getMinutes(), msg:results[r].msg};
				$('#'+group_id).append(resDiv.html(_.template(listingTemplate,{obj:resObj})));
	 		}
	 		$(window).scrollTop(0);
	 	}
	});

	if(!_view){_view = new ResultsView;}

	return _view;
});