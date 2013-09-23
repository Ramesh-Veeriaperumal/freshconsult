define([
  'views/recent_chats',
  'views/users',
  'text!templates/sidebar.html',
  'views/visitor_list',
  'views/search/filter'
], function(recentChat,userView,sidebarTemplate,visitorsView,filterView){
	var $ = jQuery;
	var _view = null;
	var SidebarView = Backbone.View.extend({			
	 	items:function(){
	 		return ['db','chat','install','archive','user'];
	 	},
	 	render:function(){
	 		$('.fc_sneakpeak_wrap').append(_.template(sidebarTemplate));
	 		this._listeners();
	 		userView.render();
	 		recentChat.render();
	 	},
	 	_listeners:function(){
	 		var that = this;
	 		$(".agent").on('click', function(event){
	 			event.stopPropagation();
	 			if($('#visitor-list').is(":visible")){
	 				$('#visitor-list').hide("slow");
	 			}
	 			if($('#recent_container').is(":visible")){
	 				$('#recent_container').slideToggle("slow");
	 			}
	 			$('#agent-list').slideToggle("slow");
	 		});
	 		$("#bar_visitor_icon").on('click', function(event){
	 			event.stopPropagation();
	 			if($('#agent-list').is(":visible")){
	 				$('#agent-list').hide("slow");
	 			}
	 			if($('#recent_container').is(":visible")){
	 				$('#recent_container').slideToggle("slow");
	 			}
	 			$('#visitor-list').slideToggle("slow");
	 		});
	 		$("#bar_recent_list").on('click', function(event){
	 			event.stopPropagation();
	 			if($('#agent-list').is(":visible")){
	 				$('#agent-list').hide("slow");
	 			}
	 			if($('#visitor-list').is(":visible")){
	 				$('#visitor-list').hide("slow");
	 			}
	 		});
	 		$("#pop_chat_count").parent().on('click', function(e){
	 			that.showDetails(e,'agent');
	 		});
	 		$("#pop_online_count").parent().on('click', function(e){
	 			that.showDetails(e,'online');
	 		});
	 		$("#pop_return_count").parent().on('click', function(e){
	 			that.showDetails(e,'return');
	 		});
	 	},
	 	showDetails:function(evt,type){
	 		var title="";
	 		var href = $(evt.currentTarget).attr("href");
	 		history.pushState('', '', href);
			evt.preventDefault();

			$("#Sidebar").remove();
			$("body").addClass('single');
			if(type=="archive"){
				title="Chat Archive";
				filterView.render();
			}else{
				title="Visitors List"
				visitorsView.render(type);
			}

	 		if(i18n.portal_name!=""){
	 			title += " : "+i18n.portal_name;
	 		}
	 		document.title=title;
	 	}
	 });

	 if(!_view){_view = new SidebarView;}

	return _view;

});