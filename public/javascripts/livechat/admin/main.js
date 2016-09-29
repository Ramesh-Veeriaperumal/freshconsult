/*jslint browser: true */
/*global  App */

window.App = window.App || {};
window.App.Admin = window.App.Admin || {};

// window.liveChat = window.liveChat || {};
(function ($) {
	// "use strict";

App.Admin.LiveChatAdminSettings = {
	// return {

		widgetList: [],
		currentWidget: null,
		eventsRegistered: false,

		onVisit: function () {
			if ('admin/chat_widgets/index' == App.namespace) {
				// have to do if check for index page 
				this.initializeWidgetList();
			} else {
				this.initializeWidget();
			}
		},

		initializeWidgetList: function(_widgetList){
			if($('#chat_widgets_list').get(0)) {
				this.widgetList = _widgetList || jQuery('#chat_widgets_list').data('widgetList');
				this.bindEvents();
				window.liveChat.mainSettings.getSiteSettings();

				$('#chat_enable').itoggle();
				$('.toggle_widget').itoggle();
				if(window.fc_cobrowsing == true){
					$("#chat_cobrowsing").prop('checked', true);
					$(".chat_cobrowsing").show(); 
				}else{
					$("#chat_cobrowsing").prop('checked', false);
					$(".chat_cobrowsing").hide();
				}
				$('#chat_cobrowsing').itoggle();
			}
		},

		initializeWidget: function(widget){
			this.currentWidget = widget || $('#chat_header').data('widget');

			var widget = this.currentWidget;

			if(widget.widget_id){
				window.liveChat.mainSettings.renderWidget();
			}else{
				window.liveChat.mainSettings.createWidget("edit");
			}
		},

		bindEvents: function(){
			var self = this;
			$('#chat_enable').on('change', function (){
				CURRENT_ACCOUNT.chat_enabled = $(this).is(":checked");
				window.liveChat.mainSettings.toggleSite(CURRENT_ACCOUNT.chat_enabled);
	    	});

			$('.toggle_widget').on('change', function (){
	    	if($("#chat_enable").is(":checked")){
					self.currentWidget = {};
				  var selectedWidgetId = ($(this).parent()).attr('rel');			  
				  var status = $(this).is(":checked") ? true : false;

				  for(i=0; i < self.widgetList.length; i++){
				  	if(self.widgetList[i].id == selectedWidgetId){
				  		self.currentWidget = self.widgetList[i];
				  	}
					}

				  if(self.currentWidget.widget_id){
				  	window.liveChat.mainSettings.toggleWidget(status);
				  }else if(status){
				  	self.currentWidget.active = true;
				  	window.liveChat.mainSettings.createWidget("index");
				  }
				}
	    });

			window.liveChat.mainSettings.bindCobrowsingSetting();	    
			window.liveChat.mainSettings.bindMaxChatEvents();
		},

		onLeave: function () {

		}

	}
}(window.jQuery));
