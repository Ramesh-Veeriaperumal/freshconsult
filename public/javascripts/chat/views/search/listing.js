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
	 		$("#search_chat_hdr").unbind('click').bind('click',function(){
	 			$("#search_results_list").show();
	 			$("#search_results_expand").hide();
	 			$(window).scrollTop(0);
	 		});
	 		this.chatviews(data);
	 	},	
	 	chatviews:function(data){
	 		var results = data.messages;
	 		var len = results.length;
			$('#search_chat_list').html("");
			groupView.render(data);
	 		for(var r=0; r<len; r++){
	 			var time = results[r].createdAt;
				var date = new Date(results[r].createdAt);
				
				var resDiv = $('<div>');
				date = new Date(results[r].createdAt);
				var cls= "";
				if(!results[r].userId){
					cls = 'fc_self';
				}else{
					var check = results[r].userId.search('visitor');
					if(check < 0){
						cls = 'fc_guest_expanded';
					}else{
						cls = 'fc_self_expanded';
					}
				}
				resDiv.addClass(cls);

				var photo = results[r].photo;
				if(!photo){
					photo = "../../images/fillers/profile_blank_thumb.gif";
				}

				var resObj = {name: results[r].name, time:date.toString("hh:mm tt"), msg:results[r].msg, photo:photo};
				$('#search_results_grp').append(resDiv.html(_.template(listingTemplate,{obj:resObj})));
	 		}
	 		$(window).scrollTop(0);
	 	}
	});

	if(!_view){_view = new ResultsView;}

	return _view;
});