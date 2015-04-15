window.liveChat = window.liveChat || {};

window.liveChat.preferenceSettings = function($){
	return {
		render: function(){
			var self = this;
			var _widget = window.liveChat.adminSettings.currentWidget;
			var business_calendar = _widget.business_calendar;

			// business calendar
			if(business_calendar == null || business_calendar == "null" || business_calendar == 0){ // Set 24x7
				$("#chat_anytime").prop('checked', true);
				$("#chat_business_options").hide();
			}else{
				$("#chat_business_hours").prop('checked', true);
				$("#chat_business_options").show();
			}

			//offline chat
			var elementPrefix = _widget.offline_chat.show == 1 ? "show" : "hide";
			$("#"+elementPrefix+"_offline_chat_window").prop('checked', true);

			// Proactive chat
			if(_widget.proactive_chat == 1){
				$("#proactive_chat").prop('checked', true);
				$(".proactive_chat").show(); 
			}else{
				$("#proactive_chat").prop('checked', false);
				$(".proactive_chat").hide();
			}
			$('#proactive_chat').itoggle({
				checkedLabel: CHAT_I18n.on,
				uncheckedLabel: CHAT_I18n.off
			}).change(function() {
				$(".proactive_chat").toggle();
			});

			$('#proactive_time').attr('value', _widget.proactive_time).on('change', function(){
				$('.proactive_time_display').html(self.timeConversion()); 
			});
			
			$('.proactive_time_display').html(self.timeConversion());

			if(business_calendar == null || business_calendar == "null" || business_calendar == 0){ // Set 24x7
				$("#chat_anytime").prop('checked', true);
				$("#chat_business_options").hide();
			}else{
				$("#chat_business_hours").prop('checked', true);
				$("#chat_business_options").show();
			}
			
			//Routing
			if(CURRENT_ACCOUNT.chat_routing){
				if(!_widget.routing){
					var routing = {};
					$(".dropdown_routing_choices").hide();
					$("#dropdown_routing_enable").prop('checked', false);
					// create routing from dropdown choices with everyone('[0]') option as default
					var dropdown_options = (_widget.prechat_fields.dropdown.options || []);
					var choices = {};
					dropdown_options.each(function(choice){
						choices[choice] = ["0"];
					});
					choices["default"] = ["0"];
					routing.choices = choices;
		    	routing.dropdown_based = $("#dropdown_routing_enable").is(":checked") ? true : false;
					this.renderRoutingSettings(routing, "default");
				}else{
					if(_widget.routing.dropdown_based == 'true'){
						$("#dropdown_routing_enable").prop('checked', true);
						$(".dropdown_routing_choices").show();
						$(".dropdown_enable_info").text(CHAT_I18n.enabled);
					}else{
						$("#dropdown_routing_enable").prop('checked', false);
						$(".dropdown_routing_choices").hide();
						$(".dropdown_enable_info").text(CHAT_I18n.disabled);
					}
					this.renderRoutingSettings(_widget.routing, "old");
				}
			}

			$('#dropdown_routing_enable').change(function() {
	      if($(this).is(":checked")) {
					$(".dropdown_routing_choices").show();
					$(".dropdown_enable_info").text(CHAT_I18n.enabled);
	      }else{
					$(".dropdown_routing_choices").hide();
					$(".dropdown_enable_info").text(CHAT_I18n.disabled);
	      }
	    });
		},

		preferencesSave: function (){
			var self = this;
      var _widget = window.liveChat.adminSettings.currentWidget;
			var show_chat_hours = $("input[name='show_chat_hours']:checked").val();

			if(show_chat_hours != 0 && $("#business_calendar_id").length > 0){
				show_chat_hours = $("#business_calendar_id").val();
			}

			var data = {'siteId': window.SITE_ID, routing: {}};
			data.business_calendar_id = show_chat_hours;
			data.show_on_portal = $("#show_on_portal").is(":checked") ? 1 : 0;
			data.portal_login_required = $("#portal_login_required").is(":checked") ? 1 : 0;
			data.product_id = _widget.product_id;
			
			if(CURRENT_ACCOUNT.chat_routing){
		    data.routing.choices = this.routingChoices();
		    data.routing.dropdown_based = $("#dropdown_routing_enable").is(":checked") ? true : false;
		  }

			data.proactive_chat = ($("#proactive_chat").is(":checked") ? 1 : CHAT_CONSTANTS.HIDE);
			data.proactive_time = $("#proactive_time").val();
			data.offline_chat = _widget.offline_chat;
			data.offline_chat['show'] = $("input[name='offline_chat_window']:checked").val();

			$.ajax({
				type: "PUT",
				url: "/admin/chat_widgets/"+_widget.id,
				data: data,
				dataType: "json",
				success: function(resp){
					window.liveChat.adminSettings.currentWidget = $.extend({}, _widget, data);
					window.liveChat.mainSettings.parseStringJsonFields();
					self.showMsg(resp);
				},
				error: function(resp){
					resp.status = 'error';
					self.showMsg(resp);
				}
			});
		},

		escapeHTML: function (string) {
		   return string
		   .replace(/&/g, "&amp;")
		   .replace(/</g,"&lt;")
		   .replace(/>/g, "&gt;")
		   .replace(/\"/g, "&quot;")
	     .replace(/'/g, "&#39;")
	     .replace(/[\[\]]+/g,'');
	  },

		renderRoutingSettings: function(routing, type){			
			var self = this;
			var choices = routing.choices;
			var _widget = window.liveChat.adminSettings.currentWidget;

			if (!_.isEmpty(choices)) {
				$.ajax({
					type: "GET",
					url: "/livechat/get_groups",
					data: {"widget_id": _widget.widget_id},
					dataType: "json",
					success: function(resp){
						if(resp.groups){
							$('.dropdown_routing_choices').html('');
							var groups = JSON.parse(resp.groups);
							var chat_routing = '';
							var default_options = '';
							_.each(choices, function (value, prop) { 
								prop = self.escapeHTML(prop);
								if(prop != "default"){
									chat_routing 	+= '<li class="inline-field label-field"><label class="item">'
																+CHAT_I18n.choice_info.replace('$',prop)
																+'</label>'+ '</li><li class="inline-field"><select id='
																+prop.replace(/ /g,"_")+' name = '+prop.replace(/ /g,"_")+' '
																+ 'class = "select2" placeholder="Select groups">'
																+self.groupOptions(value, groups)+'</select>'+'</li>';
								}
							});
							$('.dropdown_routing_choices').html('<ul>'+chat_routing+'</ul>');
							if(type == "old" || type == "default"){
								var default_value = choices['default'];
								var default_routing = '<li class="inline-field">'+'<select id="default" name = "default"'
																			+ ' class = "select2" placeholder="Select groups">'
																			+self.groupOptions(default_value, groups)+'</select>'+ '</li>';
								$('.default_routing_choice').html('<ul>'+default_routing+'</ul>');
							}
							$('.routing_loader').remove();
							$('.routing').show();
						}
					}
				});
			}
		},

		groupOptions: function(value, groups){
			var options = '';
			for(var g=0; g < groups.length; g++){
				if(value && value.length){
					var isSelected = _.indexOf(value,JSON.stringify(groups[g][1])) == -1 ? '' : 'selected';
					options += '<option value = '+groups[g][1]+' '+isSelected+'>'+groups[g][0]+'</option>';
				}else{
					options += '<option value = '+groups[g][1]+'>'+groups[g][0]+'</option>';
				}
			}
			return options;
		},

		routingChoices: function(){
			var _routingChoices = {};
			var choice = "";
			var default_routing = [$("#preferences .default_routing_choice li select").val()]; // choices saved as array for future use(multiple groups)
			var default_choice = default_routing ? default_routing : ['0']; // ['0'] - everyone
			$("#preferences .routing li select").each(function(){
				if(!$(this).val()){
					$(this).select2().select2("val", default_choice);
				} 
				choice = this.name.replace(/_/g," ");
				_routingChoices[choice] = [$(this).val()]; // choices saved as array for future use(multiple groups)
			});
			return _routingChoices;
		},

		timeConversion: function(){ 
			var sec = $("#proactive_time").val();
			var mins = Math.floor(sec / 60);
			var seconds = sec - mins * 60;
			mins == 0? mins = '': mins = mins + "<span>m </span>";
			seconds == 0? seconds = '': seconds = seconds + "<span>s</span>";   
			var timer =mins + seconds + "<span class='caret'></span>"; 
			return timer;
		},


		showMsg: function(response){
			$(".chat_setting_save").removeAttr('disabled');
			var msg = '';
			if(response.status == "error"){
				if(response.msg){
					msg = response.msg;
				}else{
					msg = CHAT_I18n.update_error_msg;
				}
				window.liveChat.widgetSettings.pendingChanges = true;
			}else{
				msg = CHAT_I18n.update_success_msg;
				window.liveChat.widgetSettings.pendingChanges = false;
			}

			$("#chat_settings_notice").text(msg).show();
			closeableFlash('#chat_settings_notice');
			$('html,body').animate({scrollTop: 220}, 800);
		},

	  bindEvents: function(){
	  	var _widget = window.liveChat.adminSettings.currentWidget;
	  	var self = this;

			$("#preferences_save").on('click', function(){
				$(this).prop('disabled', true);
				self.preferencesSave();
			});

			if(_widget.show_on_portal){
				$("#show_on_portal").prop('checked', true);
				$("li.chat_portal_enable_form").show(); 
			}else{
				$("#show_on_portal").prop('checked', false);
				$("li.chat_portal_enable_form").hide(); 
			}

			if(_widget.portal_login_required){
				$("#portal_login_required").prop('checked', true);
			}

			$('#show_on_portal').itoggle({
				checkedLabel: CHAT_I18n.on,
				uncheckedLabel: CHAT_I18n.off
			}).change(function() {
				$("li.chat_portal_enable_form").toggle();
			});

			$("#preferences input, #preferences select").on('change', function(){
				window.liveChat.widgetSettings.pendingChanges = true;
				$("#preferences_save").removeAttr('disabled');
			});

			$("input[name='show_chat_hours']").on('click', function(){
				var value = $("input[name='show_chat_hours']:checked").val();
				if(value == 0){
					$("#chat_business_options").hide();
				}else{
					$("#chat_business_options").show();
				}
			});
	  }
	}
}(jQuery);