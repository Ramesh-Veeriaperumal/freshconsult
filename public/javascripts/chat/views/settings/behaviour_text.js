var behaviour = function(){
	var $ = jQuery;
	var chatsetting_save = function(){
		var windowColor = $("#window_color").val();
		var windowOffset = $("#window_offset").val();
		var isValidColor = behaviourObj.validateColor(windowColor);
	 	var isValidOffset = behaviourObj.validateOffset(windowOffset);
	 	if(isValidColor && isValidOffset){
			var preForm=CHAT_CONSTANTS.HIDE,preMsg="",prePhone=CHAT_CONSTANTS.HIDE,preMail=CHAT_CONSTANTS.HIDE,proChat=CHAT_CONSTANTS.HIDE;
			var data ={'minimized_title' : $("#minimized_title").val(), 
					   'maximized_title' : $("#maximized_title").val(), 
					   'welcome_message' : $("#welcome_message").val(),
					   'thank_message' : $("#thank_message").val(),
					   'wait_message' : $("#wait_message").val(),
					   'typing_message' : $("#typing_message").val()};
		 	if($("#prechat_form").is(":checked")){
		 		preForm=1;
		 	}
		 	preMsg = $("#prechat_message").val();
		 	if($("#prechat_phone").is(":checked")){
				prePhone = $("#prechat_phone").val();
				if($("#prechat_phone_req").is(":checked")){
					prePhone = $("#prechat_phone_req").val();
		 		}
		 	}
		 	if($("#prechat_mail").is(":checked")){
		 		preMail = $("#prechat_mail").val();
		 		if($("#prechat_mail_req").is(":checked")){
					preMail = $("#prechat_mail_req").val();
	 			}
	 		}
	 		data.prechat_form = preForm;
	 		data.prechat_message = preMsg;
		 	data.prechat_phone = prePhone;
		 	data.prechat_mail = preMail;

	 		if($("#proactive_chat").is(":checked")){
	 			proChat=1;
		 	}
		 	data.proactive_chat = proChat;
		 	data.proactive_time = $("#proactive_time").val();

		 	var preferences={};
			preferences['window_color']=windowColor;
			preferences['window_position']=$("#window_position").val();
			preferences['window_offset']=windowOffset;
			data.preferences = preferences;

		 	var chat_setting = {};
		 	chat_setting["chat_setting"] = data;

		 	$.ajax({
				type: "POST",
				url: "/admin/chat_setting/update",
				data: chat_setting,
				success: function(){
					$("#chat_setting_save").removeAttr('disabled');
					$("#noticeajax").text(i18n.update_success_msg).show();
					closeableFlash('#noticeajax');
				},
				error: function(){
					$("#chat_setting_save").removeAttr('disabled');
					var error_msg="";
					for (var i = response.message.length - 1; i >= 0; i--) {
						error_msg += response.message[i]+"</br>";
					};
					$("#noticeajax").html(error_msg).show();
					closeableFlash('#noticeajax');
				}
			});
		}else{
			$("#chat_setting_save").removeAttr('disabled');
		}
	}

	var textColor = function(color){
		var r,b,g,hsp;
    
    	color = +("0x" + color.slice(1).replace(
			color.length < 5 && /./g, '$&$&'
        ));
      	r = color >> 16;
      	b = color >> 8 & 255;
      	g = color & 255;
    
    	hsp = Math.sqrt(0.299 * (r * r) + 0.587 * (g * g) + 0.114 * (b * b));
    	if (hsp>127.5) {
      		return "#000";
    	} else {
      		return "#FFF";
    	}
	}

	var behaviourObj = {
		validateColor : function(color){
			if(!/^#[0-9a-f]{3}([0-9a-f]{3})?$/i.test(color)){
				$("#window_color_error").show();
				return false;
			}else{
				$("#window_color_error").hide();
			}

			var txtColor = textColor(color);
			$("#fc-header, #chat-container").css("background-color", color);
			$("#fc-header").css("color", txtColor);
			$("#messagewindow").css("border", "1px solid "+color);
			return true;
		},
		validateOffset : function(offset){
			if(!(/^\d+$/).test(offset) || (offset > 500)){
				$("#window_offset_error_msg").show();
				return false;
			}else{ 
				$("#window_offset_error_msg").hide();
				return true;
			}
		},
		initialize : function(chat){
			var options=[5,10,15,20,25,30,35,40,45,50,55,60];
			var positions=['Bottom Left','Bottom Right'],
				poslen = positions.length;
			var position = chat.position,
				prechat = chat.prechat,
				phone = chat.phone,
				mail = chat.mail,
				proactive = chat.proactive,
				proactive_time = chat.proactive_time,
				opt = [], len = options.length;

			if(prechat==1){
				$("#prechat_form").prop('checked', true);
				$("li.prechat_form").show();
			}else{
				$("li.prechat_form").hide();
			}
			if(phone>0){
				$("#prechat_phone").prop('checked', true);
	 			if(phone==2){
	 				$("#prechat_phone_req").prop('checked', true);
	 			}
			}
			if(mail>0){
				$("#prechat_mail").prop('checked', true);
	 			if(mail==2){
	 				$("#prechat_mail_req").prop('checked', true);
	 			}
			}

			if(proactive==1){
				$("#proactive_chat").prop('checked', true);
				$(".proactive_chat").show();
			}else{
				$(".proactive_chat").hide();
			}

			for(var i=0;i<poslen;i++){
	 			if(positions[i]==position){
	 				opt.push('<option selected>'+positions[i]+'</option>');
	 			}else{
	 				opt.push('<option>'+positions[i]+'</option>');
	 			}
	 		}
	 		$("#window_position").html(opt.join(''));

	 		opt = [];
			for(var i=0;i<len;i++){
	 			if(options[i]==proactive_time){
	 				opt.push('<option selected>'+options[i]+'</option>');
	 			}else{
	 				opt.push('<option>'+options[i]+'</option>');
	 			}
	 		}
	 		$("#proactive_time").html(opt.join(''));

			$("#prechat_form").on('click', function(){
	 			if($("#prechat_form").is(":checked")){
	 				$("li.prechat_form").show();
	 			}else{
	 				$("li.prechat_form").hide();
	 			}
	 		});

	 		$("#prechat_phone").on('click', function(){
	 			if(!$("#prechat_phone").is(":checked")){
	 				$("#prechat_phone_req").removeAttr('checked');
	 			}
	 		});
	 		$("#prechat_phone_req").on('click', function(){
	 			if($("#prechat_phone_req").is(":checked")){
	 				$("#prechat_phone").prop('checked', true);
	 			}
	 		});

	 		$("#prechat_mail").on('click', function(){
	 			if(!$("#prechat_mail").is(":checked")){
	 				$("#prechat_mail_req").removeAttr('checked');
	 			}
	 		});
	 		$("#prechat_mail_req").on('click', function(){
	 			if($("#prechat_mail_req").is(":checked")){
	 				$("#prechat_mail").prop('checked', true);
	 			}
	 		});

	 		$("#proactive_chat").on('click', function(){
	 			if($("#proactive_chat").is(":checked")){
	 				$(".proactive_chat").show();
	 			}else{
	 				$(".proactive_chat").hide();
	 			}
	 		});

	 		$("#chat_setting_save").on('click', function(){
	 			$("#chat_setting_save").prop('disabled',true);
	 			chatsetting_save();
	 		});

	 		$("#chat_setting_form input, #chat_setting_form select").change(function(){
	 			$("#chat_setting_save").removeAttr('disabled');
			});
			$("#fc-header").text(chat.max_title);
		}
	}
	return behaviourObj;
}();