(function($){
	'use strict';

	var ticketOptions = function(){
		return{
			initialize: function(chat, visitor, excludeOngoing){
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
			checkTicketOrNote: function(){
				// Disabling Chat Tab
				window.chatCollection.disableChatTab(this.chat.chat_id,true);
				// If there is no external_id associated with the chat, we are showing the ticket option page
				if(window._.isEmpty(this.chat.external_id)){
					this.render();
				}else{
					this.ticket.existingExternalId = this.chat.external_id;
					this.getMessagesFromLivechat("note",this.addNote.bind(this));
				}
			},
			render: function(){
				var ticketTemplate = window.JST['livechat/templates/tickets/ticketOptions'];
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
			addNote: function(data){
				if(!data || this.ticket.existingExternalId == null){
	          		this.flashNotice('note',false);	
					this.closeWindow(null,null,true);
					return false;
				}
				if(!data.messages || data.messages.length === 0){
					var options = {
						externalId : this.ticket.existingExternalId,
						ongoingChat : data.ongoingChat,
						chatId : data.chatId
					}
					this.closeWindow(null,options);
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
					data: {"ticket_id":this.ticket.existingExternalId ,"note": note,"updateAgent": chatTransfered,"chatOwnerId": data.chatOwnerId},
					success: function(response){
						that.flashNotice('note', response.status, response.external_id);
						if(response.status === true){
							var options = {
								externalId : response.external_id,
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
			ticket: {},
			listen: function(){
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
				window.liveChatTempCloseFunc = this.cleanUp.bind(this);
				$(document).on('keyup', window.liveChatTempCloseFunc);	
			},
			
			
			showTicketOption: function(event){
				if(event){
					event.preventDefault();
				}
				this.$existingTicketElem.hide();
				this.$newTicketElem.hide();
				this.$ticketOptionElem.show();
			},
			showNewTicketOption: function(event){
				var visitorName = (this.visitor.name || this.visitor.visitor_id);
				var visitorEmail = this.visitor.email && this.visitor.email !== "null"? this.visitor.email : "" ;
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
			showExistingTicketOption: function(event){
				this.$existingTicketElem.liveChatTicketSearch({ 
					className: 'chat_tkt_search_container'
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
			closeWindow: function(event, options, noActionRequired){
				if(window.chatCollection && noActionRequired !== true ){
					var externalId = null;
					if(options && options.externalId){
						var externalId = options.externalId;
					}
					var chatModel = window.chatCollection.get(this.chat.id);
					if(chatModel){
						chatModel.requestChatClose(externalId);
					}else if(options){
						var requestData = {};
						var attributes = {
							siteId	:	SITE_ID,
							userId	: CURRENT_USER.id,
							chatId	:	options.chatId
						}
						if(externalId){
							attributes.external_id = externalId;
						}
						if(options.ongoingChat){
							attributes.ongoingChat = options.ongoingChat;
						}
						requestData.attributes = attributes;
						window.liveChat.request("chats/" + options.chatId , "PUT", requestData);
					}
				}else{
					window.chatCollection.disableChatTab(this.chat.chat_id,false);
				}

				if(this.$parentElem){
					this.$parentElem.find('.close').trigger('click');
				}
			},
			convertNewTicket: function(event){
				var requesterEmail = this.$newTicketElem.find('#requester_email').val();
				var ticketTitle = this.$newTicketElem.find('#ticket_title').val();
				var requesterName = this.$newTicketElem.find('#requester_name').val();
				if(this.validateMail(requesterEmail) && ticketTitle !=="" && requesterName !== ""){
					this.ticket.requesterEmail = requesterEmail;
					this.ticket.requesterName = requesterName;
					this.ticket.ticketSubject = ticketTitle;
					$(event.target).val(CHAT_I18n.saving).attr('disabled','true');
					this.getMessagesFromLivechat('ticket',this.createTicketHelpkit.bind(this));
				}
							
			},
			getMessagesFromLivechat: function(type, callback){
				var chat = this.chat;
				var chatId = chat.chat_id || chat.id;
	      var requestData = {
    			linked : true, 
    			excludeOngoing : this.excludeOngoing,
    		};
      	window.liveChat.request('chats/' + chatId + '/getUnmarkedMsgs', 'GET', requestData, function(err, data){
      		callback(data);
      	});
			},

			// TODO : Error icon css correction
			validateInputFields: function(event){
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
			validateMail: function(mail){
	      		var regex = /(^[-A-Z0-9.''_&%=~+]+@(?:[A-Z0-9\-]+\.)+(?:[A-Z]{2,15})$)/i
	      		if(!regex.test(mail)){
	        		return false;
	      		}
	      		return true;
	    	},
	    	
	    	addNoteToExistingTicket: function(event){
	    		this.$parentElem.find(".selected_tkt_button").hide();
	    		var $target = jQuery(event.target);
	    		$target.show().text(window.CHAT_I18n.saving).attr('disabled','true');
	    		this.ticket.existingExternalId = $target.data('id');
	    		this.getMessagesFromLivechat('note',this.addNote.bind(this));
	    	},
	    	// whenever the close button is clicked, all referenced nodes will be removed.
	    	cleanUp: function(event){
	    		if(event && event.type === "keyup" && event.keyCode !== 27) {
	    			return;
	    		};
	    		$(document).off("keyup", window.liveChatTempCloseFunc);
	    		window.liveChatTempCloseFunc = null;
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
			createTicketHelpkit: function(data){
				if(!data){
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
					"phone" : this.visitor.phone,
					"subject" : this.ticket.ticketSubject, 
					"widget_id" : chat.widget_id,
					"content": tkt_desc
				};

				if(chat.agent_id){
					ticket.agent_id = chat.agent_id;
				}
				// The ticket creation time will be the calculated by subtracting the queue_time of the chat from the actual created time received. 
				var createdTime = new Date(data.initiatedTime);
				createdTime = createdTime.getTime();
				//chat queue time won't available when agent convert the chat to ticket from archives 
				createdTime = chat.queue_time ? createdTime - chat.queue_time: createdTime;
				createdTime = new Date(createdTime).toISOString();
				ticket.chat_created_at = createdTime;
				
				if(this.chat.groups){
					ticket.group_id = eval(this.chat.groups)[0];
				}
				// the request to add the data of the created time
				$.ajax({
					type: "POST",
					url: "/livechat/create_ticket",
					dataType: 'json',
					data: {"ticket":ticket},
					success: function(response){
						that.flashNotice("ticket", response.status, response.external_id);
						if(response.status === true){
							var options = {
								externalId : response.external_id,
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
			parseMessages: function(messages){
				var msgclass, created_date, resObj, conversation = "";
				for (var r=0; r<messages.length; r++) {
					var msgObj = typeof messages[r] == "string" ? JSON.parse(messages[r]) : messages[r];
					if(msgObj.user_id || msgObj.userId){
						msgclass = ((msgObj.user_id || msgObj.userId).search('visitor') >= 0) ? "background:rgba(255,255,255,0.5);" : "background:rgba(242,242,242,0.3)";
					}else{
						msgclass = "background:rgba(255,255,255,0.5);";
					}
					var photo = msgObj.photo? WEB_ROOT + msgObj.photo : WEB_ROOT + '/images/fillers/profile_blank_thumb.gif';
					var descriptionTemplate = window.JST["livechat/templates/tickets/ticketDescription"];
					resObj =  descriptionTemplate({msg:msgObj.msg, name:msgObj.name, photo:photo, cls: msgclass});
					conversation += resObj;
				}
				return conversation;
			},
			flashNotice: function(type, status, ticket_id){
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
