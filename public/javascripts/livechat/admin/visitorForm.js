window.liveChat = window.liveChat || {};

window.liveChat.visitorFormSettings = function($){
	return {
		dropdownIsChanged: false,
		
		render: function(){
			var _widget = window.liveChat.adminSettings.currentWidget;
			var form_details = _widget.prechat_fields;
			var prechat_form = _widget.prechat_form;
			var prechat_msg = _widget.prechat_message;

			var form_details_list = [];
			var show = _widget.show, required = _widget.required;
			var labels = {'name': _widget['name_label'], 'phone': _widget['phone_label'], 'email': _widget['mail_label'], 'textfield': _widget['textfield_label'], 'dropdown': _widget['dropdown_label']};
			var offline_chat_form = liveChat.adminSettings.currentWidget['offline_chat']['form'];

			if(prechat_form == 1){
				$("#prechat_form").prop('checked', true);
				$("li.prechat_form").show(); 
			}else{
				$("#prechat_form").prop('checked', false);
				$("li.prechat_form").hide();
			}

			$('#prechat_form').itoggle({
				checkedLabel: CHAT_I18n.on,
				uncheckedLabel: CHAT_I18n.off
			}).change(function() {
				$("li.prechat_form").toggle();
			});

			$("#prechat_message").val(prechat_msg);

			$("#missed_chat_name").val(offline_chat_form['name']);
			$("#missed_chat_email").val(offline_chat_form['email']);

			for(var k in form_details){
				var list = '<li class="inline-field" data-type="'+k+'"><i class="ficon-rearrange"></i>';
				var showCheck = '', reqCheck = '', isDisable = '';
				if(k == 'name'){
					isDisable = 'disabled ';
					reqCheck = 'checked';
					showCheck = 'checked';
				}else{
					if(form_details[k].show && form_details[k].show > 0){
						if(form_details[k].show == 2){
							reqCheck = 'checked';
						}
						showCheck = 'checked';
					}
				}
				if(k == "dropdown"){
					list += '<div class="prechat_wrap">';
				}
				list += '<input type="text" class="prechat_input" id="prechat_form_'+k+'" name="prechat_form_name" maxlength="20" value="'+form_details[k].title+'" placeholder="'+labels[k]+'">';
				if(k == "dropdown"){
					list += '<i class="ficon-caret-down"></i></div>';
				}
				list += '<div class="fields"><div class="ff_item"><label class="item"> <input class="filter_item" data-field="show" type="checkbox" '+isDisable + showCheck+' value="'+show+'"><span> '+CHAT_I18n['show']+'</span></label><label class="item">';
				list += '<input class="filter_item" data-field="req" type="checkbox" '+isDisable + reqCheck+' value="'+required+'"><span> '+CHAT_I18n['required']+'</span></label></div></div>';
				if(k == "dropdown"){
					list += '<div class="prechat_dropdown" id="prechat_dropdown_choice"><span>'+CHAT_I18n['dropdown_choices']+' - <a href="#">'+CHAT_I18n['edit']+'</a></span><ul class="dropdown_choices">';
					var options = form_details[k].options;
					if(options){
						var options_len = options.length;
						for(var l=0; l < options_len; l++){
							list += '<li data-val="'+options[l]+'">'+options[l]+'</li>';
						}
					}
					list += '</ul></div><div class="prechat_dropdown textarea" id="prechat_dropdown_input"><textarea></textarea><p>'+CHAT_I18n['dropdown_info']+'</p><a href="#" class="btn">'+CHAT_I18n['cancel']+'</a>';
					list += '<input class="btn btn-primary" name="done" type="button" value="'+CHAT_I18n['done']+'"></div>';
				}
				list += '</li>';
				form_details_list.push(list);
			}

			$("#prechat_form_fields").html(form_details_list.join('')).sortable({
				revert: true
			});

			$("#prechat_form_fields input:checkbox:not(:disabled)").on('click', function(){
				var field = $(this).attr('data-field');
				if(field == "show"){
					if(!$(this).is(":checked")){
						$(this).closest('label').next().find('input').removeAttr('checked');
					}
				}else{
					if($(this).is(":checked")){
						$(this).closest('label').prev().find('input').prop('checked', true);
					}
				}
			});
		},
	        
		visitorFormSave: function(){
			var self = this;
			var data = {};
			var valid = true;
			var preForm = CHAT_CONSTANTS.HIDE;
			var prechat_form_details = {};
			var _widget = liveChat.adminSettings.currentWidget;

			if($("#prechat_form").is(":checked")){
				preForm = 1;
			}
			data.prechat_form = preForm;

			var preMsg = $("#prechat_message").val();
			data.prechat_message = preMsg;

			$("#prechat_form_fields li").each(function(){
				var fieldName = $(this).attr('data-type');
				var fieldValue = "";
				if(fieldName == "name" || fieldName == "phone" || fieldName == "email" || fieldName == "textfield" || fieldName == "dropdown"){
					prechat_form_details[fieldName] = {};
					fieldValue = $(this).find('input:text').val();
					prechat_form_details[fieldName]['title'] = fieldValue;
					var fieldShow = $(this).find('input:checked:last').val();
	 				prechat_form_details[fieldName]['show'] = fieldShow;
					if(fieldName == "dropdown"){
						var dropList = self.dropdownChoices();
						if(dropList.length == 0){
							valid = false;
							self.showMsg({
								status: 'error',
								msg: 'Please provide dropdown options'
							});
							return false;
						}
						prechat_form_details[fieldName]['options'] = dropList;
					}
				}
			});
			data.prechat_fields = prechat_form_details;

			data.offline_chat = _widget.offline_chat;
			var form = {};
			form['name'] = $("#missed_chat_name").val() || CHAT_I18n.name;
			form['email'] = $("#missed_chat_email").val() || CHAT_I18n.email;
			data.offline_chat['form'] = form;

			if(valid){
				this.updateLiveChatWidgetSettings(data);
			}
		},

		updateLiveChatWidgetSettings: function(params){
			var self 					= this;
			var _widget 		 	= liveChat.adminSettings.currentWidget;
			var _routing 		 	= window.liveChat.routingSettings;
			var data = {	
					"siteId" 			: window.SITE_ID, 
					"widget_id"		: _widget.widget_id, 
					"attributes"	: params,
					"token"				: LIVECHAT_TOKEN,
					"userId"			: CURRENT_USER.id
			 };
			if(CURRENT_ACCOUNT.chat_routing && params.prechat_fields && self.dropdownIsChanged){
				var newRouting = {};
				var newRoutingChoices = {};
				var choices = params.prechat_fields.dropdown.options;
				if(_widget.routing){
					var oldChoices = ((typeof _widget.routing == 'string')
																? JSON.parse(_widget.routing) 
																: _widget.routing).choices;
					choices.each(function(choice){
						newRoutingChoices[choice] = ["0"];
						_.each(oldChoices, function (value, prop) {  
							if(prop == choice){
								newRoutingChoices[choice] = value;
							}
						});
					});
					newRoutingChoices['default'] = oldChoices['default'];
				}else{
					choices.each(function(choice){
						newRoutingChoices[choice] = ["0"];
					});
					newRoutingChoices['default'] = ["0"];
				}
				newRouting.choices = newRoutingChoices;
				newRouting.dropdown_based = $("#dropdown_routing_enable").is(":checked") ? true : false;
				data.attributes.routing = newRouting;
			}
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
						if(CURRENT_ACCOUNT.chat_routing){
							if(self.dropdownIsChanged){
								self.dropdownIsChanged = false;
								window.liveChat.preferenceSettings.renderRoutingSettings(newRouting, "new");
							}
							if(params.prechat_fields){
								var oldPrechatFields = (typeof _widget.prechat_fields == 'string') 
																						? JSON.parse(_widget.prechat_fields) 
																						: _widget.prechat_fields;
								var old_dropdown_value = parseInt(oldPrechatFields.dropdown.show);
								var new_dropdown_value = parseInt(params.prechat_fields.dropdown.show);
								if(!(old_dropdown_value == new_dropdown_value && old_dropdown_value && new_dropdown_value && chat_pusher)){
									var availableChannel = chat_pusher.channel('presence-Available-'+SITE_ID);
									var status = new_dropdown_value ? true : false;
									if(availableChannel){
										availableChannel.trigger('client-channel-routing', {status: status});
									}
								}
							}
						}
					}
				}
			});
		},        
		defaultPrechatFields: function(){
	    return {
	      name      : { "title" : CHAT_I18n.name, "show" : "2" },
	      email     : { "title" : CHAT_I18n.email, "show" : "2" },
	      phone     : { "title" : CHAT_I18n.phone, "show" : "0" },
	      textfield : { "title" : CHAT_I18n.textfield, "show" : "0" },
	      dropdown  : { "title" : CHAT_I18n.dropdown, "show" : "0", "options" : ["list1","list2","list3"]}
	    }
	  },
		
		getdropdownOptions: function(){
			var dropOptions = $('#prechat_dropdown_input textarea').val().split(/\n/);
			var dropList = [], len = dropOptions.length;
			for (var i=0; i < len; i++) {
				if (/\S/.test(dropOptions[i])) {
					var value = this.escapeHTML($.trim(dropOptions[i]));
					dropList.push('<li data-val="'+value+'">'+ value+'</li>');
				}
			}
			return dropList;
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

		dropdownChoices: function(){
			var dropOptions = [];
			$("#prechat_dropdown_choice .dropdown_choices li").each(function(){
				dropOptions.push($(this).data('val'));
			});
			return dropOptions;
		},

		setdropdownOptions: function(){
			var choices = this.dropdownChoices();
			$('#prechat_dropdown_input textarea').val(choices.join('\n'));
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
				window.liveChat.widgetSettings.pendingChanges = 1;
			}else{
				msg = CHAT_I18n.update_success_msg;
				window.liveChat.widgetSettings.pendingChanges = 0;
			}

			$("#chat_settings_notice").text(msg).show();
			closeableFlash('#chat_settings_notice');
			$('html,body').animate({scrollTop: 220}, 800);
		},

		bindEvents: function(){
			var self = this;
			$("#visitor-form_save").on('click', function(){
				$(this).prop('disabled', true);
				self.visitorFormSave();
			});
			$("#visitor-form input, #visitor-form select").on('change', function(){
				window.liveChat.widgetSettings.pendingChanges = true;
				$("#visitor-form_save").removeAttr('disabled');
			});

			$("#prechat_dropdown_choice a").on('click', function(evt){
				evt.preventDefault();
				$("#prechat_dropdown_choice").hide();
				$("#prechat_dropdown_input").show();
				self.setdropdownOptions();
			});

			$("#prechat_dropdown_input input").on('click', function(){
				self.dropdownIsChanged = true;
				$("#prechat_dropdown_choice").show();
				$("#prechat_dropdown_input").hide();
				var drplist = self.getdropdownOptions();
				$("#prechat_dropdown_choice ul").html(drplist.join(''));
			});

			$("#prechat_dropdown_input a").on('click', function(evt){
				evt.preventDefault();
				$("#prechat_dropdown_choice").show();
				$("#prechat_dropdown_input").hide();
			});
		}
	}
}(jQuery);
