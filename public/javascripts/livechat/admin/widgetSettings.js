window.liveChat = window.liveChat || {};

window.liveChat.widgetSettings = function($){
	return {
		pendingChanges: false,

		render: function(){
			var self = this;
			var _widget = liveChat.adminSettings.currentWidget;
			var _widgetPreferences = _widget.widget_preferences;
			var _nonavailabilityMessage = _widget.non_availability_message;
			var _offlineChatMessages = _widget['offline_chat']['messages'];
			var bgColor = _widgetPreferences.window_color;
			var max_title = _widgetPreferences.maximized_title;
			var max_txt = (max_title != "")? max_title : CHAT_I18n.max_title;

			var positions = ['Bottom Left','Bottom Right'],
				poslen = positions.length,
				position = _widgetPreferences.window_position;

			this.setTextColor(bgColor);
			$("#fc-header").text(max_txt);
			$("#window_color").val(bgColor).trigger('keyup');

			var opt = [];
			for(var i=0; i<poslen; i++){
				if(positions[i] == position){
					opt.push('<option selected>'+positions[i]+'</option>');
				}else{
					opt.push('<option>'+positions[i]+'</option>');
				}
			}
					
			$("#window_position").html(opt.join(''));
			$("#window_offset").val(_widgetPreferences["window_offset"]);

			$("#minimized_title").val(_widgetPreferences["minimized_title"]);
			$("#maximized_title").val(max_title);
			$("#welcome_message").val(_widgetPreferences["welcome_message"]);
			$("#text_place").val(_widgetPreferences["text_place"]);
			$("#connecting_msg").val(_widgetPreferences["connecting_msg"]);
			$("#wait_message").val(_widgetPreferences["wait_message"]);
			$("#agent_joined_msg").val(_widgetPreferences["agent_joined_msg"]);
			$("#agent_left_msg").val(_widgetPreferences["agent_left_msg"]);
			$("#thank_message").val(_widgetPreferences["thank_message"]);
			$("#agent_transfer_msg_to_visitor").val(_widgetPreferences["agent_transfer_msg_to_visitor"]);
			$("#offline_title").val(_offlineChatMessages["title"]);
			$("#offline_thank_msg").val(_offlineChatMessages["thank"]);
			$("#offline_thank_header_msg").val(_offlineChatMessages["thank_header"]);

			$('#window_color').on({
				change: function (){
					self.setTextColor($(this).val());
				},
				colorpicked: function (){
					self.setTextColor($(this).val());
				},
				keyup: function() {
					self.setTextColor($(this).val());
				}
			});

			$("#maximized_title").keyup(function() {
				if($(this).val() != ""){
					$("#fc-header").text($(this).val());
				}else{
					$("#fc-header").text(CHAT_I18n.max_title);
				}
			});

			// non_availability_message
			if(_nonavailabilityMessage && _nonavailabilityMessage.text != ""){
				$("#non_availability_message").val(_nonavailabilityMessage.text);
				if(_nonavailabilityMessage.customLink == "1" ){
					$("#custom_link_url").val(_nonavailabilityMessage.customLinkUrl);
					$("#custom_link_url_item").show();
					$(".offline_messages").hide();
				}else{
					$("#custom_link_url_item").hide();
					$("#custom_link").prop('checked', false);
				}
			} else {
				$("#custom_link_url_item").hide();
				$("#custom_link").prop('checked', false);				
			}

			$("#custom_link").on('change',function(){
				if($(this).is(":checked")){
					$("#custom_link_url_item").show();
					$(".offline_messages").hide();
				}else{
					$("#custom_link_url_item").hide();
					$(".offline_messages").show();
				}
			});

			$('#custom_link_url').on('change', function (){
				self.validateUrl($(this).val());
			});
		},

		widgetSave: function (id){
			var _data = {};
			var _offlineMessages 						= {};
			var _widgetPreferences					= {};
			var _nonavailabilityPreferences = {};
			var _isValidUrl 								= true;
			var _windowColor 								= $("#window_color").val();
			var _windowOffset 							= $("#window_offset").val();
			var _isValidColor 							= this.validateColor(_windowColor);
			var _isValidOffset 							= this.validateOffset(_windowOffset);
			var _nonavailabilityMessage 		= $('#non_availability_message').val();
			var _useCustomLink 							= $("#custom_link").is(":checked");
			
			if(_useCustomLink){
				_isValidUrl = this.validateUrl($("#custom_link_url").val());
			}

			if(_isValidColor && _isValidOffset && _isValidUrl){
				_widgetPreferences['window_color'] 			= _windowColor;
				_widgetPreferences['window_position'] 	= $("#window_position").val();
				_widgetPreferences['window_offset'] 		= _windowOffset;
				_widgetPreferences['text_place'] 				= $("#text_place").val();
				_widgetPreferences['connecting_msg'] 		= $("#connecting_msg").val();
				_widgetPreferences['agent_left_msg'] 		= $("#agent_left_msg").val();
				_widgetPreferences['agent_joined_msg']  = $("#agent_joined_msg").val();
				_widgetPreferences['minimized_title'] 	= $("#minimized_title").val();
				_widgetPreferences['maximized_title'] 	= $("#maximized_title").val();
				_widgetPreferences['welcome_message'] 	= $("#welcome_message").val();
				_widgetPreferences['thank_message'] 		= $("#thank_message").val();
				_widgetPreferences['wait_message'] 			= $("#wait_message").val();

				_nonavailabilityPreferences['text'] = _nonavailabilityMessage;
				_nonavailabilityPreferences['customLink'] = _useCustomLink ? 1 : 0;
				_nonavailabilityPreferences['customLinkUrl'] = _useCustomLink ? $("#custom_link_url").val() : "";

				_data.offline_chat = liveChat.adminSettings.currentWidget['offline_chat'];

				_offlineMessages['title'] = $("#offline_title").val() || CHAT_I18n.offline_title;
				_offlineMessages['thank'] = $("#offline_thank_msg").val() || CHAT_I18n.offline_thank_msg;
				_offlineMessages['thank_header'] = $("#offline_thank_header_msg").val() || CHAT_I18n.offline_thank_header_msg;

				_data.offline_chat['messages'] = _offlineMessages
				_data.widget_preferences = _widgetPreferences;
				_data.non_availability_message = _nonavailabilityPreferences;

				this.updateLiveChatWidgetSettings(_data, id);
			}
		},

		defaultWidgetMessages: function(){
	    return {
	      window_color  	: "#777777",
	      window_position : "Bottom Right",
	      window_offset   : "30",
	      minimized_title : CHAT_I18n.min_title,
	      maximized_title : CHAT_I18n.max_title,
	      text_place      : CHAT_I18n.text_place,
	      welcome_message : CHAT_I18n.wel_msg,
	      thank_message   : CHAT_I18n.thank_msg,
	      wait_message    : CHAT_I18n.wait_msg,
	      agent_joined_msg: CHAT_I18n.agent_joined_msg,
	      agent_left_msg  : CHAT_I18n.agent_left_msg,
	      connecting_msg  : CHAT_I18n.connecting_msg,
	      agent_transfer_msg_to_visitor : CHAT_I18n.agent_transfer_msg_to_visitor
	    }
		},

		defaultNonAvailabilitySettings: function(){
			return {
	      text               : CHAT_I18n.non_availability_message,
	      ticket_link_option : false,
	     	custom_link_url    : ""
	    }
		},

		validateColor: function(color){
			if(!/^#[0-9a-f]{3}([0-9a-f]{3})?$/i.test(color)){
				$("#window_color_error").show();
				return false;
			}else{
				$("#window_color_error").hide();
			}
			return true;
		},

		setTextColor: function(color){
			var txtColor = textColor(color);
			$("#fc-header").css({"background-color": color, "color": txtColor});
			if(txtColor == "black"){
				$("#fc-header").addClass('dark-icon');
			}else{
				$("#fc-header").removeClass('dark-icon');
			}

			var borderColor = this.convert2Hex(color, 30);
			$("#chat-container").css("background-color", borderColor);
			$("#messagewindow").css("border", "1px solid "+borderColor);
			return true;
		},


		validateOffset: function(offset){
			if(!(/^[\d]*$/).test(offset) || (offset > 500)){
				$("#window_offset_error_msg").show();
				return false;
			}else{ 
				$("#window_offset_error_msg").hide();
				return true;
			}
		},

		validateUrl: function(url){
			var regexUrlCheck = /(http(s)?:\\)?([\w-]+\.)+[\w-]+[.com|.in|.org]+(\[\?%&=]*)?/;
			if(!url || !regexUrlCheck.test(url)){
				$('#url_error_msg').show();
				return false;
			}else{
				$('#url_error_msg').hide();
				return true;
			}
		},

		updateLiveChatWidgetSettings: function(params, widget_id){
			var self 					= this;
			var _widget 		 	= liveChat.adminSettings.currentWidget;
			var _visitorForm 	= window.liveChat.visitorFormSettings;
			var _routing 		 	= window.liveChat.routingSettings;
			var data = {	
					"siteId" 			: window.SITE_ID, 
					"widget_id"		: widget_id, 
					"attributes"	: params,
					"token"				: LIVECHAT_TOKEN,
					"userId"			: CURRENT_USER.id
			 };

			$.ajax({
				type: "POST",
				url: window.liveChat.URL + "/widgets/update",
				data: data,
				dataType: "json",
				success: function(resp){
					if(resp.status == "success"){
						window.liveChat.adminSettings.currentWidget = $.extend({}, _widget, params);
						window.liveChat.mainSettings.parseStringJsonFields();
						self.showMsg(resp);
					}
				}
			});
		},

		convert2Hex: function(hex, opacity){
			hex = hex.replace('#','');
			var r = parseInt(hex.substring(0,2), 16);
			var g = parseInt(hex.substring(2,4), 16);
			var b = parseInt(hex.substring(4,6), 16);

			return 'rgba('+r+','+g+','+b+','+opacity/100+')';
		},

		showMsg: function(resp){
			$(".chat_setting_save").removeAttr('disabled');
			var msg = '';
			if(resp.status == "error"){
				if(resp.msg){
					msg = resp.msg;
				}else{
					msg = CHAT_I18n.update_error_msg;
				}
				this.pendingChanges = true; //There was an erro while saving the changed so modifications are still pending
			}else{
				msg = CHAT_I18n.update_success_msg;
				this.pendingChanges = false; //Update was susscessful so there are no pending modifications.
			}

			$("#chat_settings_notice").text(msg).show();
			closeableFlash('#chat_settings_notice');
			$('html,body').animate({scrollTop: 220}, 800);
		},

		bindEvents: function(){
			var self = this;
			var _widget = window.liveChat.adminSettings.currentWidget;

			window.liveChat.widgetCode.bindClipBoardEvents();
			window.liveChat.preferenceSettings.bindEvents();
			window.liveChat.visitorFormSettings.bindEvents();
			window.liveChat.widgetCode.updateCode();
			
			$("#widget_save").on('click', function(){
				$(this).prop('disabled', true);
				self.widgetSave(_widget.widget_id);
			});

			$("#widget input, #widget select").on('change', function(){
				self.pendingChanges = true;
				$("#widget_save").removeAttr('disabled');
			});

			//Registered an event to prompt an user if there are unsaved changed and user is navigating away from that page.
			$("#chat_setting ul.nav-tabs").on('click', function(){
				if(self.pendingChanges){
					if(confirm(CHAT_I18n.settings_save)){ //Means he opted to stay on the same settings page
						var href = $("#chat_setting li.active a").attr("href");
						$(href+"_save").trigger('click');
						return false;
					}else{                     // Means he opted to navigate away eventhough there were pending changes
						self.pendingChanges = false;
					}
				}
			});
		}
	}
}(jQuery);