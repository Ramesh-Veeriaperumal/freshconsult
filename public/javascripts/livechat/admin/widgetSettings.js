window.liveChat = window.liveChat || {};

window.liveChat.widgetSettings = function($){
	return {
		pendingChanges: false,

		render: function(){
			var self = this;
			var _widget = App.Admin.LiveChatAdminSettings.currentWidget;
			var _widgetPreferences = _widget.widget_preferences;
			var _defaultMessages = _widget.defaultMessages;
			var default_widget_preferences = _defaultMessages.widget_preferences;

			var _nonavailabilityMessage = _widget.non_availability_message;
			var default_non_availability = _defaultMessages.non_availability_message;

			var _offlineChatMessages = _widget['offline_chat']['messages'];
			var default_offline_chat_messages = _defaultMessages.offline_chat.messages;

			var bgColor = _widgetPreferences.window_color;
			var max_title = _widgetPreferences.header;
			var max_txt = max_title ? max_title : default_widget_preferences["header"];
			var wc_txt = (_widgetPreferences.welcome_message != "") ? _widgetPreferences.welcome_message : default_widget_preferences["welcome_message"];
			var input_txt = (_widgetPreferences["text_place"] != "") ? _widgetPreferences["text_place"] : default_widget_preferences["text_place"];

			var positions = ['Bottom Left','Bottom Right'],
				poslen = positions.length,
				position = _widgetPreferences.window_position;

			this.setTextColor(bgColor);
			$("#lc_chat_header").text(max_txt);
			$("#cw_welcome_msg").text(wc_txt)
			$("#window_color").val(bgColor).trigger('keyup');
			$("#inputcontainer").text(input_txt);

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
			$("#window_offset").attr("placeholder",default_widget_preferences["window_offset"] );

			$("#header_title").val(_widgetPreferences["header"]);
			$("#header_title").attr("placeholder",default_widget_preferences["header"] );

			$("#welcome_message").val(_widgetPreferences["welcome_message"]);
			$("#welcome_message").attr("placeholder",default_widget_preferences["welcome_message"] );

			$("#text_place").val(_widgetPreferences["text_place"]);
			$("#text_place").attr("placeholder",default_widget_preferences["text_place"] );

			$("#wait_message").val(_widgetPreferences["wait_message"]);
			$("#wait_message").attr("placeholder",default_widget_preferences["wait_message"] );

			$("#thank_message").val(_widgetPreferences["thank_message"]);
			$("#thank_message").attr("placeholder",default_widget_preferences["thank_message"] );

			$("#end_chat_confirm_msg").val(_widgetPreferences["end_chat_confirm_msg"]);
			$("#end_chat_confirm_msg").attr("placeholder",default_widget_preferences["end_chat_confirm_msg"] );

			$("#agent_network_disconnect_msg").val(_widgetPreferences["agent_network_disconnect_msg"]);
			$("#agent_network_disconnect_msg").attr("placeholder",default_widget_preferences["agent_network_disconnect_msg"] );

			$("#agent_transfer_msg_to_visitor").val(_widgetPreferences["agent_transfer_msg_to_visitor"]);
			$("#agent_transfer_msg_to_visitor").attr("placeholder",default_widget_preferences["agent_transfer_msg_to_visitor"] );

			$("#offline_title").val(_offlineChatMessages["title"]);
			$("#offline_title").attr("placeholder",default_offline_chat_messages["title"] );

			$("#offline_thank_msg").val(_offlineChatMessages["thank"]);
			$("#offline_thank_msg").attr("placeholder",default_offline_chat_messages["thank"] );

			$("#offline_thank_header_msg").val(_offlineChatMessages["thank_header"]);
			$("#offline_thank_header_msg").attr("placeholder",default_offline_chat_messages["thank_header"] );

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

			$("#header_title").keyup(function() {
				if($(this).val() != ""){
					$("#lc_chat_header").text($(this).val());
				}else{
					$("#lc_chat_header").text(default_widget_preferences["header"]);
				}
			});
			
			$("#welcome_message").keyup(function() {
				if($(this).val() != ""){
					$("#cw_welcome_msg").text($(this).val());
				}else{
					$("#cw_welcome_msg").text(default_widget_preferences["welcome_message"]);
				}
			});

			$("#text_place").keyup(function() {
				if($(this).val() != ""){
				    $("#inputcontainer").text($(this).val());
				}else{
					$("#inputcontainer").text(default_widget_preferences["text_place"]);
				}
			});

			// non_availability_message
			var non_avail_msg = default_non_availability.text;
			non_avail_msg = non_avail_msg.replace('# leave us a message #','leave us a message');
			$("#non_availability_message").attr("placeholder",non_avail_msg);
			$("#custom_link_url_item").hide();
			$("#custom_link").prop('checked', false);			
			$(".offline_messages").show();	
			$("#custom_link_url").attr("placeholder",default_non_availability.custom_link_url);

			if(_nonavailabilityMessage && _nonavailabilityMessage.text != ""){
				$("#non_availability_message").val(_nonavailabilityMessage.text);
				if(_nonavailabilityMessage.customLink == "1" ){
					$("#non_availability_message").attr("placeholder",default_non_availability.text);
					$("#custom_link_url").val(_nonavailabilityMessage.customLinkUrl);
					$("#custom_link").prop('checked', true);
					$("#custom_link_url_item").show();
					$(".offline_messages").hide();
				}
			} 

			$("#custom_link").on('change',function(){
				if($(this).is(":checked")){
					$("#non_availability_message").attr("placeholder",default_non_availability.text);
					$("#custom_link_url_item").show();
					$(".offline_messages").hide();	
				}else{
					$("#non_availability_message").attr("placeholder",non_avail_msg);
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
				_widgetPreferences['header'] 	= $("#header_title").val();
				_widgetPreferences['welcome_message'] 	= $("#welcome_message").val();
				_widgetPreferences['thank_message'] 		= $("#thank_message").val();
			    _widgetPreferences['end_chat_confirm_msg']  = $("#end_chat_confirm_msg").val();
			    _widgetPreferences['agent_network_disconnect_msg']  = $("#agent_network_disconnect_msg").val();
				_widgetPreferences['wait_message'] 			= $("#wait_message").val();
				_widgetPreferences["agent_transfer_msg_to_visitor"] = $("#agent_transfer_msg_to_visitor").val();
				_nonavailabilityPreferences['text'] = _nonavailabilityMessage;
				_nonavailabilityPreferences['customLink'] = _useCustomLink ? 1 : 0;
				_nonavailabilityPreferences['customLinkUrl'] = _useCustomLink ? $("#custom_link_url").val() : "";

				_data.offline_chat = App.Admin.LiveChatAdminSettings.currentWidget['offline_chat'];

				_offlineMessages['title'] = $("#offline_title").val() || "";
				_offlineMessages['thank'] = $("#offline_thank_msg").val() || "";
				_offlineMessages['thank_header'] = $("#offline_thank_header_msg").val() || "";

				_data.offline_chat['messages'] = _offlineMessages
				_data.widget_preferences = _widgetPreferences;
				_data.non_availability_message = _nonavailabilityPreferences;

				this.updateLiveChatWidgetSettings(_data, id);
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
			var _widget 		 	= App.Admin.LiveChatAdminSettings.currentWidget;
			var _visitorForm 	= window.liveChat.visitorFormSettings;
			var _routing 		 	= window.liveChat.routingSettings;
			$.ajax({
				type: "PUT",
				url: "/admin/chat_widgets/"+_widget.id,
				data: { attributes: params },
				dataType: "json",
				success: function(resp){
					if(resp.status == "success"){
						App.Admin.LiveChatAdminSettings.currentWidget = $.extend({}, _widget, params);
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
			var _widget = App.Admin.LiveChatAdminSettings.currentWidget;

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
			$("#chat_setting ul.nav-tabs").on('click', function(e){
				e.preventDefault();
				if(self.pendingChanges){
					if(confirm(CHAT_I18n.settings_save)){ //Means he opted to stay on the same settings page
						var href = $("#chat_setting li.active a").attr("href");
						$(href+"_save").trigger('click');
						return false;
					}else{                     // Means he opted to navigate away eventhough there were pending changes
						self.pendingChanges = false;
					}
					history.pushState( null, null, $(this).attr('href') );
				}
			});
		}
	}
}(jQuery);
