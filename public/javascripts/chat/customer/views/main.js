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
			this.style();
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
    		if (color.match(/^rgb/)) {
				color = color.match(/^rgba?\((\d+),\s*(\d+),\s*(\d+)(?:,\s*(\d+(?:\.\d+)?))?\)$/);
				r = color[1];
				b = color[2];
				g = color[3];
		    } else {
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
    		} else {
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
				}, (proactive_time*1000));
			}
		},
		waitTemplate:function(){
			$('#fc_chat_messagewindow').append("<p class='fc_hold_msg'>"+FRESH_CHAT_SETTING.wait_message+"</p>");
		},
		chatTemplate:function(){
			var title = FRESH_CHAT_SETTING.minimized_title;
			var userName = $.cookie('fc_vname');
			var template = '<div id="fc_chat_header"><span id="fc_chat_title">'+title+'</span><span id="fc_chat_symbol">&#9650;</span></div><div id="fc_chat_container">';
			if(FRESH_CHAT_SETTING.prechat_form==1 && userName == null){
				var premsg=FRESH_CHAT_SETTING.prechat_message;
				template+='<div class="fc_pre-form"><p>'+premsg+'</p><ul><li id="fc_chat_error" class="fc_error"></li>';
				if(FRESH_CHAT_SETTING.prechat_form==1){
					template+='<li><span class="fc_required">*</span><input type="text" value="" id="fc_chat_name" placeholder="'+FRESH_CHAT_SETTING.name_placeholder+'"></li>';
				}
				if(FRESH_CHAT_SETTING.prechat_mail>0){
					template+='<li>';
					if(FRESH_CHAT_SETTING.prechat_mail==2){template+='<span class="fc_required">*</span>';}
					template+='<input type="email" value="" id="fc_chat_mail" placeholder="'+FRESH_CHAT_SETTING.mail_placeholder+'"></li>';
				}
				if(FRESH_CHAT_SETTING.prechat_phone>0){
					template+='<li>';
					if(FRESH_CHAT_SETTING.prechat_phone==2){template+='<span class="fc_required">*</span>';}
					template+='<input type="text" value="" id="fc_chat_phone" placeholder="'+FRESH_CHAT_SETTING.phone_placeholder+'"></li>';
				}
				template+='</ul><input type="button" id="fc_chat_start" value="Start Chat"/></div>';
			}

			var welcome = "";
			if(FRESH_CHAT_SETTING.proactive_chat==0 && FRESH_CHAT_SETTING.welcome_message!=""){
				welcome = '<p class="welcome">'+FRESH_CHAT_SETTING.welcome_message+'</p>';
			}
			template+='<div id="fc_chat_window"><div id="fc_chat_messagewindow">'+welcome+'</div>'+
				      '<div id="fc_status" class="fc_chat-status"></div>'+
				      '<textarea id="fc_chat_inputcontainer" placeholder="'+FRESH_CHAT_SETTING.text_placeholder+'"></textarea></div></div>';
			return template;
		},
		style:function(){
			var style = '#fc_chat_container{'+
				 			'height:300px;'+
				 			'width:250px;'+
				 			'display:none;'+
				 			'clear:both;'+
				 			'text-align: left;'+
				 			'box-shadow:5px 0 5px #888;'+
				 		'}'+
				 		'#fc_chat_header{'+
				 			'width:232px;'+
				 			'height:22px;'+
				 			'padding:5px 10px 5px;'+
				 			'box-shadow:5px 0 5px #888;'+
				 			'border-top-left-radius:5px;'+
				 			'border-top-right-radius:5px;'+
				 			'font-family:Roboto;'+
				 			'cursor:pointer;'+
				 		'}'+
				 		'#fc_chat_symbol{'+
				 			'opacity: 0.5;'+
				 			'float:right;'+
				 			'padding-right:5px;'+
				 			'font-size:8px;'+
				 			'position:relative;'+
				 			'top:7px;'+
				 			'cursor:pointer;'+
				 		'}'+
				 		'#fc_chat_window{'+
						    'position:relative;'+
						    'height:100%;'+
						'}'+
						'#fc_chat_messagewindow, #fc_chat_inputcontainer{'+
						    'position:absolute;'+
						    'left:0;'+
						    'right:0;'+
						    'border:0;'+
						    'background-color:#fff;'+
						'}'+
						'#fc_chat_messagewindow{'+
						    'overflow:auto;'+
						    'top:0;'+
						    'bottom:3em;'+
						'}'+
						'#fc_chat_inputcontainer{'+
						    'display:block;'+
						    'bottom:-3px;'+
						    'height:36px;'+
						    'width:237px;'+
						    'padding: 2px;'+
						    'font-size: 12px;'+
						    'color: #444;'+
						    'margin:0 6px 7px;'+
						    'border-radius:3px;'+
						    'resize:none;'+
						    'font-family:Roboto;'+
						'}'+
						'#fc_chat_layout{'+
						    'display:block;'+
						    'text-align:left !important;'+
						    'bottom:0;'+
						    'position:fixed;'+
						    'z-index:100000;'+
						'}'+
						'#fc_chat_messagewindow p{'+
							'margin: 0;'+
							'padding: 5px;'+
							'font-size: 13px;'+
							'border-bottom: 1px solid #ccc;'+
							'font-family:Roboto;'+
						'}'+
						'#fc_chat_messagewindow p img{'+
							'width: 25px;'+
							'height: 25px;'+
							'margin:0; '+
							'vertical-align:top;'+
						'}'+
						'.fc_msg-block{'+
							'width: 100%;'+
							'font-size: 12px;'+
							'font-family:Roboto;'+
						'}'+
						'.fc_msg-block b{'+
							'text-transform: capitalize;'+
							'margin-left:5px;'+
							'font-family:Roboto;'+
							'color:#666;'+
						'}'+
						'.fc_time{'+
							'float: right;'+
							'font-size: 10px;'+
							'color:#CCC;'+
							'font-family:Roboto;'+
						'}'+
						'.fc_msg{'+
							'display: block;'+
							'margin-left: 30px;'+
							'margin-top: -5px;'+
							'-ms-word-break: break-all;'+
							'word-break: break-all;'+
							'font-family:Roboto;'+
						'}'+
						'.fc_msg-noname{'+
							'display: inline-block;'+
							'margin-left: 0px;'+
						'}'+
						'.fc_guest{'+
							'background: #fffcec;'+
							'border-color: #CCC;'+
						'}'+
						'.fc_self{'+
							 'background: #FFF;'+
							 'border-color: #CCC;'+
						'}'+
						'.fc_pre-form{'+
						    'background-color: rgba(255, 255, 255,1);'+
						    'display: block;'+
						    'height:300px;'+
				 			'width:250px;'+
				 			'border:1px solid #d3d3d3;'+
						'}'+
						'.fc_pre-form p{'+
							'font-family: roboto;'+
							'font-size: 12px;'+
							'color: #666;'+
							'padding: 10px 5px 0px 10px;'+
						'}'+
						'.fc_pre-form input{'+
							'width: 194px;'+
							'margin: 10px;'+
							'border: 1px #ccc solid;'+
							'padding: 4px;'+
							'color: #999;'+
						'}'+
						'.fc_pre-form input[type="button"]{'+
							'float: right;'+
							'margin: 10px 27px 10px 31px;'+
							'cursor: pointer;'+
							'padding: 2px;'+
							'width: 70px;'+
							'border-radius: 2px;'+
							'font-size: 12px;'+
							'color: #fff;'+
							'background: #333'+
						'}'+
						'.fc_pre-form ul{'+
							'margin: 0;'+
							'padding: 0px 0px 0px 10px;'+
						'}'+
						'.fc_pre-form ul li{'+
							'list-style: none;'+
						    'padding: 0px;'+
						    'position: relative;'+
						'}'+
						'.fc_required{'+
						    'position: absolute;'+
						    'color: #b83232;'+
						    'left: 0px;'+
						    'top: 5px;'+
						'}'+
						'.fc_send-mail-text{'+
							'color: #666666;'+
							'background-color: #ccc;'+
							'display: block;'+
							'width: 100%;'+
							'font-size: 12px;'+
							'position: absolute;'+
							'bottom: -5px;'+
							'padding-bottom: 10px;'+
							'font-family:Roboto;'+
						'}'+
						'.fc_send-mail-text input{'+
							'float: left;'+
							'width: 170px;'+
							'margin-left: 10px;'+
							'padding: 3px 0px;'+
						'}'+
						'.fc_send-mail-text span{'+
							'padding-bottom: 3px;'+
							'display: block;'+
							'margin-left: 10px;'+
							'padding-top: 6px;'+
						'}'+
						'.fc_send-mail-text .send-btn{'+
							'float: left;'+
							'margin-left: 5px;'+
							'text-decoration: none;'+
							'background-color: #333333;'+
							'color: #ffffff;'+
							'padding: 3px 10px;'+
							'border-radius: 2px;'+
						'}'+
						'.fc_welcome{'+
							'color: #666666;'+
							'font-size: 13px;'+
							'padding: 7px !important;'+
							'border-bottom: 0px !important;'+
						'}'+
						'.fc_error{'+
							'font-family: roboto;'+
							'font-size: 12px;'+
							'color: #b83232;'+
							'padding: 10px 5px 0px 10px;'+
						'}'+
						'.fc_hold_msg{'+
							'color: #c7423f;'+
							'border-bottom: none !important;'+
							'font-size: 13px;'+
						'}'+
						'.fc_chat-status{'+
							'display: none;'+
							'color: #999;'+
							'text-indent:6px;'+	
							'z-index:100;'+
							'padding: 8px 0px;'+
							'background-color: #fff;'+
							'position:absolute;'+
							'font-size:11px;'+
							'bottom:50px;'+
							'font-family:Roboto;'+
							'width:100%;'+						
						'}';

				$('body').append($('<style type="text/css"></style>').html(style));
		},
		startChat:function(){
			var that=this;
			if(FRESH_CHAT_SETTING.prechat_form==1){
				name = that.escapeHtml($("#fc_chat_name").val());
				if(name==""){
					$("#fc_chat_error").html("Please provide name");
					return false;
				}
				if(name!=undefined && name!=""){
					$.cookie('fc_vname',name);
				}
				mail = $("#fc_chat_mail").val();
				if(FRESH_CHAT_SETTING.prechat_mail==2 && mail==""){
					$("#fc_chat_error").html("Please provide mail id");
					return false;
				}
				if(mail!=undefined && mail!=""){
					var regex = /^([a-zA-Z0-9_\.\-\+])+\@(([a-zA-Z0-9\-])+\.)+([a-zA-Z0-9]{2,4})+$/;
						if(!regex.test(mail)){
							$("#fc_chat_error").html("Please provide valid mail id");
						return false;
						}
				}
				phone = $("#fc_chat_phone").val();
				if(FRESH_CHAT_SETTING.prechat_phone==2 && phone==""){
					$("#fc_chat_error").html("Please provide Phone number");
					return false;
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
			var data = {prefrm:"s", msg:'', name:name, mail:mail, phone:phone};
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
				}
				else if(!that.isIgnoreKey(e.keyCode)){
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