define([
		'backbone',
		'underscore',
		'customer/models/main',
		'customer/views/client',
		'customer/views/chat'
		],
function(Backbone, _, model, client,chatView){
	var View = Backbone.View.extend({
		el: '#main',
		initialize: function(){
			this.model = new model({
				message: 'Visitor Chat'
			});
			$('body').append($('<script type="text/template" class="main_html"></script>').html(this.mainTemplate()));
			this.main_template = _.template( $( "script.main_html" ).html(), { model: this.model.toJSON() } );
			$('body').append($('<script type="text/template" class="chat_html"></script>').html(this.chatTemplate()));
			this.chat_template = _.template( $( "script.chat_html" ).html());
			$('body').append("<link href='http://fonts.googleapis.com/css?family=Roboto' rel='stylesheet' type='text/css'>");
		},
		render: function(){
			$("body").append(this.main_template);
			$("#fc_chat_layout").append(this.chat_template);
			this.textColor();
			client.show(chatView);
			this.listen();
			this.proactive_timer();
		},
		textColor : function(){
			var r,b,g,hsp;
			var color = $("#fc_chat_header").css('background-color');
			if(color.match(/^rgb/)){
				color = color.match(/^rgba?\((\d+),\s*(\d+),\s*(\d+)(?:,\s*(\d+(?:\.\d+)?))?\)$/);
				r = color[1];
				b = color[2];
				g = color[3];
			}else{
				color = +("0x" + color.slice(1).replace(
					color.length < 5 && /./g, '$&$&'
				));
				r = color >> 16;
				b = color >> 8 & 255;
				g = color & 255;
			}

			hsp = Math.sqrt(0.299 * (r * r) + 0.587 * (g * g) + 0.114 * (b * b));
			if (hsp>127.5) {
				$("#fc_chat_header").css("color", "#000");
			}else{
				$("#fc_chat_header").css("color", "#FFF");
			}
		},
		mainTemplate:function(){
			return '<div id="fc_chat_layout" style="display:none;"></div>';
		},
		proactive_timer:function(){
			var proactive_time = FRESH_CHAT_SETTING.proactive_time;
			if(FRESH_CHAT_SETTING.proactive_chat==1 && proactive_time>0){
				chatView.greet = setTimeout(function(){
					if(!$("#fc_chat_container").is(':visible')){
						$("#fc_chat_container").slideToggle('slow');
					}
					if($(".fc_pre-form").is(":visible")){
						$(".fc_pre-form").hide();
						$("#fc_chat_window").show();
					}
					chatView.update({
						name:"",
						msg:FRESH_CHAT_SETTING.welcome_message,
						type:"welcome"
					});
					$("#fc_chat_inputcontainer").focus();
				}, (proactive_time*1000));
			}
		},
		waitTemplate:function(){
			$('#fc_chat_messagewindow').append("<p class='fc_hold_msg'>"+FRESH_CHAT_SETTING.wait_message+"</p>");
		},
		chatTemplate:function(){
			var title = FRESH_CHAT_SETTING.minimized_title;
			var userName = $.cookie('fc_vname');
			var mail = $.cookie('fc_vmail');
			var phone = $.cookie('fc_vphone');
			var template = '<div id="fc_chat_header"><span id="fc_chat_title">'+title+'</span><span id="fc_chat_symbol">&#9650;</span></div><div id="fc_chat_container">';
			if(FRESH_CHAT_SETTING.prechat_form==1 && (userName == null || (FRESH_CHAT_SETTING.prechat_mail==2 && mail == null) || (FRESH_CHAT_SETTING.prechat_phone==2 && phone == null))){
				var premsg=FRESH_CHAT_SETTING.prechat_message;
				template+='<div class="fc_pre-form"><p>'+premsg+'</p><ul class="formfield_wrap">';
				if(userName == null){userName = "";}
				template+='<li class="txtfield_wrap"><span class="icon-user"></span><input type="text" value="'+userName+'" id="fc_chat_name" placeholder="'+FRESH_CHAT_SETTING.name_placeholder+'"><span class="chat_required">*</span></li>';
				if(FRESH_CHAT_SETTING.prechat_mail>0){
					template+='<li class="txtfield_wrap">';
					if(mail == null){mail="";}
					template+='<span class="icon-envelop"></span><input type="email" value="'+mail+'" id="fc_chat_mail" placeholder="'+FRESH_CHAT_SETTING.mail_placeholder+'">';
					if(FRESH_CHAT_SETTING.prechat_mail==2){
						template+='<span class="chat_required">*</span>';
					}else{
						template+='<span></span>';
					}
					template+='</li>';
				}
				if(FRESH_CHAT_SETTING.prechat_phone>0){
					template+='<li class="txtfield_wrap">';
					if(phone == null){phone = "";}
					template+='<span class="icon-mobile"></span><input type="text" value="'+phone+'" id="fc_chat_phone" placeholder="'+FRESH_CHAT_SETTING.phone_placeholder+'">';
					if(FRESH_CHAT_SETTING.prechat_phone==2){
						template+='<span class="chat_required">*</span>';
					}else{
						template+='<span></span>';
					}
					template+='</li>';
				}
				template+='</ul><div class="fc_btn_holder"><input type="button" id="fc_chat_start" value="Start Chat"/></div></div>';
			}

			var welcome = "";
			if(FRESH_CHAT_SETTING.proactive_chat==0 && FRESH_CHAT_SETTING.welcome_message!=""){
				welcome = '<p class="welcome">'+FRESH_CHAT_SETTING.welcome_message+'</p>';
			}
			template+='<div id="fc_chat_window"><div id="fc_chat_messagewindow">'+welcome+'</div>'+
			'<textarea id="fc_chat_inputcontainer" placeholder="'+FRESH_CHAT_SETTING.text_placeholder+'"></textarea></div></div>';
			return template;
		},
		startChat:function(){
			var that=this;
			if(FRESH_CHAT_SETTING.prechat_form==1){
				name = that.escapeHtml($("#fc_chat_name").val());
				$("#fc_chat_name").removeClass("fc_input_error").next().removeClass("icon-warning").addClass("chat-required").text("*");
				if(FRESH_CHAT_SETTING.prechat_mail==2){
					$("#fc_chat_mail").removeClass("fc_input_error").next().removeClass("icon-warning").addClass("chat-required").text("*");
				}else{
					$("#fc_chat_mail").removeClass("fc_input_error").next().removeClass("icon-warning");
				}
				if(FRESH_CHAT_SETTING.prechat_phone==2){
					$("#fc_chat_phone").removeClass("fc_input_error").next().removeClass("icon-warning").addClass("chat-required").text("*");
				}else{
					$("#fc_chat_phone").removeClass("fc_input_error").next().removeClass("icon-warning");
				}
				if(name==""){
					$("#fc_chat_name").addClass("fc_input_error").next().removeClass("chat-required").addClass("icon-warning").text("").attr("title","Please provide name");
					return false;
				}
				if(name!=undefined && name!=""){
					$.cookie('fc_vname',name);
				}
				mail = $("#fc_chat_mail").val();
				if(FRESH_CHAT_SETTING.prechat_mail==2 && mail==""){
					$("#fc_chat_mail").addClass("fc_input_error").next().removeClass("chat-required").addClass("icon-warning").text("").attr("title","Please provide mail id");
					return false;
				}
				if(mail!=undefined && mail!=""){
					var regex = /^([a-zA-Z0-9_\.\-\+])+\@(([a-zA-Z0-9\-])+\.)+([a-zA-Z0-9]{2,4})+$/;
					if(!regex.test(mail)){
						$("#fc_chat_mail").addClass("fc_input_error").next().removeClass("chat-required").addClass("icon-warning").text("").attr("title","Please provide valid mail id");
						return false;
					}
					$.cookie('fc_vmail',mail);
				}
				phone = $("#fc_chat_phone").val();
				if(FRESH_CHAT_SETTING.prechat_phone==2 && phone==""){
					$("#fc_chat_phone").addClass("fc_input_error").next().removeClass("chat-required").addClass("icon-warning").text("").attr("title","Please provide Phone number");
					return false;
				}
				if(phone!=undefined && phone!=""){
					var isPhone = phone.match(/^[0-9\s(-)+]*$/);
					if(!isPhone){
						$("#fc_chat_phone").addClass("fc_input_error").next().removeClass("chat-required").addClass("icon-warning").text("").attr("title","Please provide valid Phone number");
						return false;
					}
					$.cookie('fc_vphone',phone);
				}
			}
			$(".fc_pre-form").hide();
			$("#fc_chat_window").show();
			$("#fc_chat_inputcontainer").focus();
			if(FRESH_CHAT_SETTING.wait_message!=""){
				chatView.wait = setTimeout(function(){
					that.waitTemplate();
				}, 2*60*1000);
			}
			var data = {prefrm:"s", msg:''};
			chatView.send(data);
		},
		listen:function(){
			var that=this, name='', mail='', phone='';
			$("#fc_chat_name, #fc_chat_mail, #fc_chat_phone").on("keyup",function(e){
				if(e.keyCode==13){
					that.startChat();
				}
			});
			$("#fc_chat_start").on('click',function(){
				that.startChat();
			});

			$("#fc_chat_header").on('click',function(){
				$("#fc_chat_container").slideToggle('slow', function(){
					clearTimeout(chatView.greet);
					if($(this).is(':visible')){
						$("#fc_chat_symbol").html("&#9660;");
						$("#fc_chat_title").html(FRESH_CHAT_SETTING.maximized_title);
						if($(".fc_pre-form").is(":visible")){
							$("#fc_chat_name").focus();
						}else{
							$("#fc_chat_inputcontainer").focus();
						}
					}else{
						$("#fc_chat_symbol").html("&#9650;");
						$("#fc_chat_title").html(FRESH_CHAT_SETTING.minimized_title);
					}
				});
			});

			$("#fc_chat_inputcontainer").on("keydown",function(e){
				if(e.keyCode==13 && !e.shiftKey){
					e.preventDefault();
					if(chatView.type=="site"){
						if(chatView.greet!=""){
							clearTimeout(chatView.greet);
						}
						if(chatView.wait=="" && FRESH_CHAT_SETTING.wait_message!=""){
							chatView.wait = setTimeout(function(){
								that.waitTemplate();
							}, 2*60*1000);
						}
					}
					var value = $.trim($(this).val());
					if(value != ""){
						chatView.send({msg:that.escapeHtml($(this).val())});
					}
					$(this).val("");
				}else if(!that.isIgnoreKey(e.keyCode)){
					chatView.typing();
				}
			});
		},
		isIgnoreKey:function(keyCode){
			var keys = [224,9,18,17,16,27,37,38,39,40];
			return ($.inArray(keyCode,keys)!=-1);
		},
		escapeHtml:function(string) {
			var entityMap = {
				"&": "&amp;",
				"<": "&lt;",
				">": "&gt;",
				'"': '&quot;',
				"'": '&#39;'
			};
			return String(string).replace(/[&<>"']/g, function (s) {
				return entityMap[s];
			});
		}
	});
	return new View();
});