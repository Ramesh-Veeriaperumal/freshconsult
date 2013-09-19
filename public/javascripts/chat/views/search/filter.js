define([
  'views/daterange',
  'text!templates/search/layout.html'
], function(daterangeView,layoutTemplate){
	var _view = null;
	var $ = jQuery;
	var FilterView = Backbone.View.extend({
	 	render:function(){
	 		$("#Pagearea").html(_.template(layoutTemplate,{}));
			daterangeView.render();
	 		this.agents();
	 		this._listeners();
	 		this.filter();
	 	},
	 	filter:function(){
	 		chat_socket.emit('search request',{
          		key: '',
          		type: 'normal'
        	});
	 	},
	 	advanceFilter:function(){
	 		var dat = $('#date-range-field span').text().split('-'),
 				frm = $.trim(dat[0]),
 				to = $.trim(dat[1]);
            chat_socket.emit('search filter',{
              	key: $('#search_input').val(),
              	loc: $('#filterLoc').val(),
              	frm: frm,
              	to: to,
              	tag: $('#filterTag').val(),
              	agent: $("#agentList").val(),
              	type: 'advance'
            });
            $("#search_results_list").html('<div class="sloading loading-small loading-block"></div>');
	 	},
	 	_listeners:function(){
	 		var that = this;
	 		$("#web_chat_visitors").on('click', function(e){
	 			var sidebarView = require('views/sidebar');
	 			sidebarView.showDetails(e,'online');
	 		});
	 		$("#startFilter").on('click', function(){
	 			that.advanceFilter();
	 		});
	 		$("#search_input, #filterLoc, #filterTag").on("keyup",function(e){
				if(e.keyCode==13){
					that.advanceFilter();
				}
			});
	 	},
        agents: function(){
            var agentList = '<option value="all">All</option>';
            _.each(userCollection.models, function(user) {
                agentList += '<option value="'+user.get('id')+'">'+user.get('username')+'</option>';
            })
            $('#agentList').html(agentList);
        }
	 });

	 if(!_view){_view = new FilterView;}

	return _view;

});