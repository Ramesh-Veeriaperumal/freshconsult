define([
  'text!templates/visitor_details.html',
  'views/url_parser'  
], function(visitorTemplate,urlParser){
	var $ = jQuery;
	var visitorView = Backbone.View.extend({		
		isOpen: false,		
		render:function(chat, details){
			var that = this;
			that.details = details;
			if(!that.isOpen){
				that.isOpen = true;
				var userAgent = null;

				if(chat.userAgent){
					userAgent = JSON.parse(chat.userAgent);
				}

				$('body').append(_.template(visitorTemplate,{chat:chat,userAgent:userAgent}));
				$('.closeDialog, .cancelBtn').on('click', function(){
					that.isOpen = false;
					$('#visitor').remove();
				});	
				$('.saveBtn').on('click', function(){
					var details = {
							chatId: chat.id,
							userName: chat.visitor.userName,
							name:$("#visitorname").val(),
							phone:$("#contact").val(),
							email:$("#email").val(),
							tag:$("#tag").val()
					};
					chat_socket.emit("visitor details",details);					
					chat_socket.once("visitor details",function(data){
						that.isOpen = false;
						if(data.name!=""){
							chat.changeTitle(data.name);
						}
						$('#visitor').remove();
					});
				});
			}

			chat_socket.emit('visitor info',{
				userName: chat.visitor.userName
			});
			
			chat_socket.once('visitor info',function(data){
				if(data && data["name"]){
					$("#visitorname").val(data["name"]);
				}

				var phone = "";
				if(data && data.phone){
					phone = data.phone;
				}
				if(that.details && that.details.phone){
					if(phone!=""){
						phone += ",";
					}
					phone += that.details.phone;
				}
				$("#contact").val(phone);

				var mail = "";
				if(data && data.email){
					mail = data.email;
				}
				if(that.details && that.details.mail){
					if(mail!=""){
						mail += ",";
					}
					mail += that.details.mail;
				}
				$("#email").val(mail);

				if(data && data.tag){
					$("#tag").val(data.tag);
				}
			});
		}
	});
	return 	(new visitorView());
});