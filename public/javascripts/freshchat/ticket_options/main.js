(function($){
	'use strict';

	var ticketOptions = function(){
		return{
			initialize : function(chat, visitor, excludeOngoing){
				this.excludeOngoing = excludeOngoing;
				if(chat && visitor){
					this.chat = chat;
					this.visitor = visitor;
					this.checkTicketOrNote();
					
				}else if(chat && visitor == null){
					this.chat = chat;
					if(window.visitorCollection){
						var that = this;
						var tempVisitorModel = new window.visitorCollection.model({id:chat.participant_id});
						tempVisitorModel.fetchDetails(null,
							//Success Callback
						function(model,response,options){
							that.visitor = model.toJSON();
							tempVisitorModel = null;
							that.checkTicketOrNote.bind(that)();
						},
							//Error Callback
						function(model,response,options){

						});
					}
				}
			},
			checkTicketOrNote : function(){
				// Disabling Chat Tab
				window.chatCollection.disableChatTab(this.chat.chat_id,true);
				// If there is no external_id associated with the chat, we are showing the ticket option page
				if(window._.isEmpty(this.chat.external_id)){
					this.render();
				}else{

					this.ticket.existingTicketId = this.chat.external_id;
					this.getMessagesFromLivechat("note",this.addNote.bind(this));
				}
			},
			render : function(){
				var ticketTemplate = window.JST['freshchat/templates/ticket_options'];
				// If the pop div is already present,we are removing it.
				if($('#fc_end_chat_form').length){
	        		$('#fc_end_chat_form').remove();
	      		}

	        	$('body').append(ticketTemplate());
	        	$('#end_chat_popup').trigger('click');
	        	this.$parentElem = $('#fc_end_chat_form');
	        	this.$ticketOptionElem = this.$parentElem.find('.chat_ticket_options_container');
	        	this.$newTicketElem = this.$parentElem.find('.chat_new_ticket_container');
	        	this.$existingTicketElem = this.$parentElem.find('.chat_tkt_search_container');
	        	this.listen();

			},
			addNote:function(data){
				if(this.ticket.existingTicketId == null || (data.status ==="error")){
	          		this.flashNotice('note',false);	
					this.closeWindow(null,null,true);
					return false;
				}
				var that = this;
	          	var note = "<div class='conversation_wrap'><table style='width:100%; font-size:12px; border-spacing:0px; margin:0; border-collapse: collapse;'>"+this.parseMessages(data.messages)+"</table></div>";
	          	var chatTransfered = false;
	          	if(that.chat.isTransferred || that.chat.transfer_id){
			         chatTransfered = true;
			      }else{
			         chatTransfered = false;
			      }  

				$.ajax({
					type: "POST",
					url: "/livechat/add_note",
					dataType: 'json',
					data: {"ticket_id":this.ticket.existingTicketId ,"note": note,"updateAgent": chatTransfered,"chatOwnerId": data.chatOwnerId},
					success: function(response){
						that.flashNotice('note',response.status,response.ticket_id);
						if(response.status === true){
							var options = {
								ticketId : response.ticket_id,
								ongoingChat : data.ongoingChat,
								chatId : data.chatId
							}
							that.closeWindow(null,options);
						}else{
							that.flashNotice('note',false);	
							that.closeWindow(null,null,true);
						}
					},
					error:function(){
						that.flashNotice('note',false);	
						that.closeWindow(null,null,true);
					}
				});
	    	},
			// This variable has the ticket details like requester name, requester email and ticket subject.
			ticket:{},
			listen :function(){
				// Show new ticket option
				this.$parentElem.on('click','#new_ticket_button',this.showNewTicketOption.bind(this));
				// Show Existing ticket option
				this.$parentElem.on('click','#existing_ticket_button',this.showExistingTicketOption.bind(this));
				// Close the ticket option.
				this.$parentElem.on('click','#do_nothing_button',this.closeWindow.bind(this,null,null));
				// Go back to ticket menu option.
				this.$parentElem.on('click','.go_back',this.showTicketOption.bind(this));
				// Save while clicking from new ticket option
				this.$parentElem.on('click','#new_tkt_save',this.convertNewTicket.bind(this));
				// Cleaning up the memory
				this.$parentElem.on('click','.close',this.cleanUp.bind(this));
				// Validating all input fields on blur
				this.$parentElem.on('blur','input',this.validateInputFields.bind(this));
				//Selecting ticket from existing ticket option page
				this.$parentElem.on('click','.selected_tkt_button',this.addNoteToExistingTicket.bind(this));
			},
			
			
			showTicketOption:function(event){
				if(event){
					event.preventDefault();
				}
				this.$existingTicketElem.hide();
				this.$newTicketElem.hide();
				this.$ticketOptionElem.show();
			},
			showNewTicketOption : function(event){
				var visitorName = (this.visitor.name || this.visitor.visitor_id);
				var visitorEmail = this.visitor.email;
				// Ticket Subject
				this.ticket.ticketSubject = window.CHAT_I18n.ticket_subject.replace("$1",visitorName)
	                                                 .replace("$2", moment(this.chat.created_at).format("ddd, Do MMM YYYY"));
				if(visitorEmail){
	        		this.ticket.requesterEmail = visitorEmail.split(',')[0];
	        		this.ticket.requesterName = visitorName;
	      		}else{
	        		this.ticket.requesterEmail = window.CURRENT_USER.email;
	        		this.ticket.requesterName = window.CURRENT_USER.username;
	      		}                                                 
	      		
	      		this.$newTicketElem.find('#ticket_title').val(this.ticket.ticketSubject);
	      		this.$newTicketElem.find('#requester_name').val(this.ticket.requesterName);
	      		this.$newTicketElem.find('#requester_email').val(this.ticket.requesterEmail);
				
				this.$ticketOptionElem.hide();
				this.$newTicketElem.show();
			},
			showExistingTicketOption : function(event){
				var searchlistTemplate = window.JST['freshchat/templates/ticket_search_list'];
				this.$existingTicketElem.freshTicketSearch({ 
					className: 'chat_tkt_search_container',
					template:  new Template(searchlistTemplate())
				});
	      		var requester = (this.visitor && this.visitor.name) ? this.visitor.name : this.participant_id;
	      		this.$existingTicketElem.initializeRequester(requester);

				this.$ticketOptionElem.hide();
				this.$existingTicketElem.show();
			},
			/* If options is passed, depending on the parameters , Chat window will be closed if available or 
			 * ticket Id will be updated
			 * If noActionRequired is set to True, only the ticket window will be closed
			 */
			closeWindow:function(event, options, noActionRequired){
				if(window.chatCollection && noActionRequired !== true ){
					if(options && options.ticketId){
						var ticketId = options.ticketId;
					}else{
						var ticketId = null;
					}
					var chatModel = window.chatCollection.get(this.chat.id);
					if(chatModel){
						chatModel.requestChatClose(ticketId);
					}else if(options){
	        			var request = { 
	        				action : "chat/updateticketid",
	        				data: {
	        					siteId 	: window.SITE_ID,
	        					code 	: "fd",
	        					chatId 	: options.chatId,
	        					userId 	: window.CURRENT_USER.id,
	        					token 	: LIVECHAT_TOKEN,
	        					closed  : true
	        				}
	        			}
	        			if(ticketId){
	        				request.data.ticketId = ticketId;
	        			}
	        			if(options.ongoingChat){
	        				request.data.ongoingChat = options.ongoingChat;
	        			}
	        			request.data = jQuery.param(request.data);
						fc_helper.jsonpRequest(request);
					}
				}else{
					window.chatCollection.disableChatTab(this.chat.chat_id,false);
				}

				if(this.$parentElem){
					this.$parentElem.find('.close').trigger('click');
				}
			},
			convertNewTicket:function(event){
				var requesterEmail = this.$newTicketElem.find('#requester_email').val();
				var ticketTitle = this.$newTicketElem.find('#ticket_title').val();
				var requesterName = this.$newTicketElem.find('#requester_name').val();
				if(this.validateMail(requesterEmail) && ticketTitle !=="" && requesterName !== ""){
					this.ticket.requesterEmail = requesterEmail;
					this.ticket.requesterName = requesterName;
					this.ticket.title = ticketTitle;
					$(event.target).val(CHAT_I18n.saving).attr('disabled','true');
					this.getMessagesFromLivechat('ticket',this.createTicketHelpkit.bind(this));
				}
							
			},
			getMessagesFromLivechat:function(type, callback){
				var chat = this.chat;
	      		var data = {
	      			siteId :window.SITE_ID,
	      			chatId:(chat.chat_id || chat.id ), 
	      			userId: CURRENT_USER.id,
	      			linked : true, 
	      			excludeOngoing : this.excludeOngoing,
	      			token : window.LIVECHAT_TOKEN
	      		};
	        	var request = {
	        		action : "chat/getUnmarkedMsgs",
	        		data  : jQuery.param(data)
	        	}
	        	window.fc_helper.jsonpRequest(request,callback);
			},

			// TODO : Error icon css correction
			validateInputFields:function(event){
				var $inputField = $(event.target);
				var type = $inputField.data('validationType');
				switch(type){
					case "email": 
						var validationStatus = this.validateMail($inputField.val());
						if(validationStatus){
							 $inputField.css("background-color","#FFF").next().removeClass("icon-warning");
						}else{
							$inputField.css("background-color","#FEF7F7").next().addClass("icon-warning").attr("title","Please provide valid Email Id");
						}
						break;
					default :
						var fieldValue = $inputField.val();
						if(fieldValue === ""){
							//If Field is empty, adding error
							$inputField.css("background-color","#FEF7F7").next().addClass("icon-warning").attr("title","Field should not be empty");
						}else{
							// If Field is not empty, removing the error.
							$inputField.css("background-color","#FFF").next().removeClass("icon-warning");
						}

				}

			},
			validateMail:function(mail){
	      		var regex = /^([a-zA-Z0-9_\.\-\+])+\@(([a-zA-Z0-9\-])+\.)+([a-zA-Z0-9]{2,4})+$/;
	      		if(!regex.test(mail)){
	        		return false;
	      		}
	      		return true;
	    	},
	    	
	    	addNoteToExistingTicket:function(event){
	    		this.$parentElem.find(".selected_tkt_button").hide();
	    		var $target = jQuery(event.target);
	    		$target.show().text(window.CHAT_I18n.saving).attr('disabled','true');
	    		this.ticket.existingTicketId = $target.data('id');
	    		this.getMessagesFromLivechat('note',this.addNote.bind(this));
	    	},
	    	// whenever the close button is clicked, all referenced nodes will be removed.
	    	cleanUp:function(event){
	    		// If the user clicks the close button directly
	    		if(event && event.isTrigger !== true){
					window.chatCollection.disableChatTab(this.chat.chat_id,false);
	    		}
	    		this.$parentElem = null;
	    		this.$ticketOptionElem = null;
	    		this.$newTicketElem = null;
	    		this.$existingTicketElem = null;
	    		this.ticket = {};

	    	},
			createTicketHelpkit:function(data){
				if(data.status === "error"){
					this.flashNotice("ticket",false);
					this.closeWindow(null,null,true);
					return false;
				}
				var messages = data.messages;
				var sorted = _(messages).sortBy(function(obj) { return +new Date(obj.createdAt); });
				data.messages = sorted;

				var that = this;
				var chat = that.chat;
				//var visitor_location = this.chat.visitor_location ? " ("+ this.chat.visitor_location.replace(/,/g, ', ')+") " : " ";

				var tkt_desc = "<div class='conversation_wrap' style='padding-top:0'><div style='padding:10px 0 10px 10px'>"
					+ CHAT_I18n.ticket_description.replace('$1',this.visitor.name).replace('$2'," ").replace('$3',CURRENT_USER.username)
					+"<br></div><table style='width:100%; font-size:12px; border-spacing:0px; border-collapse: collapse; margin:0; border-right:0;  border-bottom:0'>"
					+ that.parseMessages(data.messages)+"</table></div>";
				var ticket = { 
					"email" : this.ticket.requesterEmail, 
					"name" : this.ticket.requesterName, 
					"subject" : this.ticket.ticketSubject, 
					"widget_id" : chat.widget_id,
					"content": tkt_desc,
					"agent_id": chat.agent_id
				};

				if(this.chat.groups){
					ticket.group_id = eval(this.chat.groups)[0];
				}
				
				$.ajax({
					type: "POST",
					url: "/livechat/create_ticket",
					dataType: 'json',
					data: {"ticket":ticket},
					success: function(response){
						that.flashNotice("ticket",response.status,response.ticket_id);
						if(response.status === true){
							var options = {
								ticketId : response.ticket_id,
								ongoingChat : data.ongoingChat,
								chatId : data.chatId
							}
							that.closeWindow(null,options);
						}else{
							that.flashNotice("ticket",false);
							that.closeWindow(null,null,true);
						}
					},
					error:function(){
						that.flashNotice("ticket",false);
						that.closeWindow(null,null,true);
					}
				});
			},
			parseMessages:function(messages){
				var msgclass, created_date, resObj, conversation = "";
				for (var r=0; r<messages.length; r++) {
					var msgObj = typeof messages[r] == "string" ? JSON.parse(messages[r]) : messages[r];
					if(msgObj.user_id || msgObj.userId){
						msgclass = ((msgObj.user_id || msgObj.userId).search('visitor') >= 0) ? "background:rgba(255,255,255,0.5);" : "background:rgba(242,242,242,0.3)";
					}else{
						msgclass = "background:rgba(255,255,255,0.5);";
					}
					var photo = msgObj.photo? window.location.protocol+WEB_ROOT+msgObj.photo : window.location.protocol+WEB_ROOT+'/images/fillers/profile_blank_thumb.gif';
					var descriptionTemplate = window.JST["freshchat/templates/ticket_description"];
					resObj =  descriptionTemplate({msg:msgObj.msg, name:msgObj.name, date:moment(msgObj.createdAt).format("hh:mm A"), 
								photo:photo, cls: msgclass});
					conversation += resObj;
				}
				return conversation;
			},
			flashNotice : function(type, status, ticket_id){
				if(type === "ticket"){
					if(status === true){
						var msg = CHAT_I18n.ticket_success_msg+"<a data-pjax='#body-container' href='/helpdesk/tickets/"+
							ticket_id+"'>"+" "+CHAT_I18n.view_details+"</a>";
					}else{
						var msg = CHAT_I18n.ticket_error_msg;
					}
				}else if(type === "note") {
					if(status === true){
						var msg = CHAT_I18n.note_success+" #"+ticket_id+".<a data-pjax='#body-container' href='/helpdesk/tickets/" +
							ticket_id+"'>"+" "+CHAT_I18n.view_details+"</a>";
					}else{
						var msg = CHAT_I18n.note_error;
					}
				}
				if(msg!=""){
	        		$("#noticeajax").html(msg).show();
					closeableFlash('#noticeajax');
	      		}
			}
		};
    };

	window.liveChat = window.liveChat || {};
	liveChat.ticketOptions = new ticketOptions();

})(jQuery);