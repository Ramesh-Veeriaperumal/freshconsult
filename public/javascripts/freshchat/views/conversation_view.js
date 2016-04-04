
window.freshChat = window.freshChat || {};

window.freshChat.conversationView = function(){
		return Backbone.View.extend({
			initialize :function(options){
				window.showLoaderPage();
				this.router = options.router;
				this.isVisible = false;
				this.setElement('#conversation-wrap');
				this.visitorTemplate = window.JST["freshchat/templates/freshchat_visitor_details"] ;
				this.conversationTemplate = window.JST["freshchat/templates/freshchat_conversation"];
			},
			events :{
				"click #archive-page-link"	: "navigateArchive",
				"keydown input"	: "showVisitorEdit",
				"click #save-visitor-detail"	: "saveVisitorDetail",
				"click #cancel-visitor-detail" : "resetVisitorDetail",
				"click #navigateMessage"	: "loadMessage",
				"click #convertTicket"		: "convertTicket", 
				"click #add-note"		: "addNote",
				"click #mark-spam"		: "markAsSpam"
			},
			navigateArchive:function(event){
				event.preventDefault();
				this.router.navigate('archive',{trigger:true});
			},
			showVisitorEdit : function(event){
				if(event && event.keyCode === 13){
					this.saveVisitorDetail();
				}else{
					var $target = this.$('.title').find('.btn');
					if($target.hasClass('hide')){
						$target.removeClass('hide');
					}
				}
				//this.$el.find("#visitor_details").addClass('edit');
			},
			saveVisitorDetail:function(event){
				event.preventDefault();
				var newDetails = this.validate();
				var oldDetails = this.visitorModel.attributes;
				if(newDetails){
					var notChanged = _.every(newDetails,function(value,key){
						return newDetails[key] === oldDetails[key];
					});
					if(notChanged){
						this.$('.title').find('.btn').addClass('hide');
					}else{
						jQuery(event.currentTarget).addClass('disabled').html('Saving...');
						this.visitorModel.saveDetails(newDetails);
					}
				}
			},
			resetVisitorDetail:function(event){
				event.preventDefault();
				this.$('.title').find('.btn').addClass('hide');
				if(this.visitorModel){
					this.$('#visitorname').val(this.visitorModel.attributes.name);
					this.$('#visitoremail').val(this.visitorModel.attributes.email);
					this.$('#visitorphone').val(this.visitorModel.attributes.phone);
				}
				this.$el.find('.error').removeClass('error');
			},
			validate : function(){
				var changedDetails = {};
				this.$el.find('.error').removeClass('error');

				// Name
				var name = jQuery.trim(this.$("#visitorname").val());
				if(name != ""){
					changedDetails.name = name;
				}else{
					this.$("#visitorname").addClass("error");
					return false;
				}
				//Email
				var email = jQuery.trim(this.$("#visitoremail").val());
				if(email != ""){
					var isEmail = email.match(/^([a-zA-Z0-9_\.\-\+])+\@(([a-zA-Z0-9\-])+\.)+([a-zA-Z0-9]{2,4})+$/);
					if(!isEmail){
						this.$("#visitoremail").addClass("error");
						return false;
					}
				changedDetails.email = email;
				}else{
					changedDetails.email = null;
				}
				//Phone
				var phone = jQuery.trim(this.$("#visitorphone").val());
				if(phone != ""){
					var isPhone = phone.match(/^[0-9\-\(\)\s+]+$/);
					if(!isPhone){
						this.$("#visitorphone").addClass("error");
						return false;
					}
					changedDetails.phone = phone;
				}else{
					changedDetails.phone = null;
				}
				return changedDetails;
				////
			},
			loadMessage : function(event){
				event.preventDefault();
				var data = jQuery(event.currentTarget).data();
				if(data && data.id){
					this.router.navigate("archive/"+data.id,{trigger:true});		
				}
				window.showLoaderPage();
			},
			convertTicket :function(event){
				if(window.liveChat.ticketOptions && this.archiveModel){
					var archiveAttr = this.archiveModel.toJSON();
					window.liveChat.ticketOptions.initialize(archiveAttr,null,true);
				}
			},
			addNote : function(event){
				jQuery(event.target).addClass('disabled');
				jQuery(event.target).html('<i class="ficon-file-edit"></i> Adding Note');
				if(window.liveChat.ticketOptions && this.archiveModel){
					var archiveAttr = this.archiveModel.toJSON();
					liveChat.ticketOptions.initialize(archiveAttr,null,true);
				}

			},
			listenToCollection :function(){
				this.listenTo(this.collection,'change',this.renderMessage);
			},
			renderMessage:function(archiveModel){
				var messages = archiveModel.attributes.message;
				if(messages){
					this.archiveModel = archiveModel;
					var chatData = archiveModel.attributes;
					this.$el.html(this.conversationTemplate({
						chatData :chatData,
						messages : messages
					}));
					window.removeLoaderPage();
					if(chatData.type ==="visitor"){
						this.loadVisitorDetail(archiveModel);
					}
					// To check if spam param is changed. Taking type for random check
					if(archiveModel.hasChanged('spam') === true && archiveModel.hasChanged('message') === false && archiveModel.attributes.spam === true){
						this.showSpamFlash();
					}
				}
			},
			loadVisitorDetail : function(archiveModel){
				var visitorId = archiveModel.attributes.participant_id;
				var visitorModel = window.visitorCollection.updateOrCreate({visitor_id:visitorId},{usedIn:'archive'});
				// Linking Visitor Model to Conversation View....
				this.visitorModel = visitorModel;
				this.listenTo(visitorModel,'change',this.checkBothAjaxAndRenderVisitor);
				var widgetId = archiveModel.attributes.widget_id;
				if(!widgetId){
					widgetId = window.CURRENT_ACCOUNT.widget_id;
				}
				if(visitorModel.attributes.recentChats === undefined){
					/* When the user loads the same visitor again and there is no change in data, no events will be triggered.
				 	  * But render function is called when change event is triggered. So passing silent param to both fetch
				 	  * and triggering explicitly
				 	  */
					visitorModel.fetchDetails({widgetId : widgetId});
					visitorModel.fetchRecentChats();	
				}else{
					this.renderVisitor(visitorModel);
				}
				
			},
			/* Two ajax requests will be called to load visitor page. So to render visitor only 
			 * after two ajax are loaded.
			 */
			checkBothAjaxAndRenderVisitor : function(visitorModel){
				if(visitorModel.attributes.recentChats && visitorModel.attributes.name){
					this.renderVisitor(visitorModel);
				}
			},
			renderVisitor : function(visitorModel){
				 if(visitorModel.attributes.widget){
				 	/* visitorData 
					 *     - Object with keys
					 *       visitorData, userAgent, recentChats
					 */
					var visitorData = this.parseVisitor(visitorModel);
					
					jQuery('#chat-title').html(visitorData.name);

					this.$el.find('#visitor_details').html(this.visitorTemplate(visitorData));
					this.$el.find('#visitor_details').removeClass('sloading');
				}
			},
			parseVisitor : function(visitorModel){
				var visitorData = visitorModel.toJSON();
				var userAgent = null;
	  			userAgent = (visitorData.useragent) ? JSON.parse(visitorData.useragent) : null;
	  			if(userAgent && !userAgent.title && userAgent.page){
	    			userAgent.title = this.urlParser(userAgent.page);
	  			}
	  			var recentChats = visitorData.recentChats;

		  		// The Current conversation should not be shown in recent chats. So filtering it out.
		  		if(recentChats && recentChats.length > 0){
		  			recentChats = _.filter(recentChats,function(chat){
	  					return chat.chat_id !== this.archiveModel.id;
	  				},this);
	  			}

	  			// Location Parsing
				if(visitorData.location){
					if(!_.isString(visitorData.location)){
						var location = CHAT_I18n.unknown;
						if(visitorData.location.address){
							if(visitorData.location.address.city){
								location = visitorData.location.address.city+", ";
							}
							if(visitorData.location.address.region){
								if(location == CHAT_I18n.unknown){
									location = "";
								}
								location += visitorData.location.address.region+", ";
							}
							if(visitorData.location.address.country){
								if(location == CHAT_I18n.unknown){
									location = "";
								}
								location += visitorData.location.address.country;
							}
						}
						visitorData.location = location;
					}
				}else{
					visitorData.location = CHAT_I18n.unknown;
				}
				return {
					visitorData : visitorData,
					userAgent : userAgent,
					recentChats : recentChats
				};
			},
			markAsSpam : function(event){
				if(this.archiveModel && this.archiveModel.attributes.spam !== true){
					var confirmation = window.confirm("Are you sure you want to mark this chat as spam ?");
					if(confirmation){
						this.archiveModel.markSpam(true);
					}
				}
				
			},
			showSpamFlash : function(){
				var that = this;
				var msg = "Chat has been marked as spam.<a id = 'undo-spam' href='#' > Undo </a> ";
				var $flashDiv = jQuery("#noticeajax");
				$flashDiv.html(msg).show();
				$flashDiv.find("#undo-spam").on('click',function(event){
					if(that.archiveModel){
						that.archiveModel.markSpam(false);
						jQuery("#noticeajax").fadeOut(600);
						jQuery("#noticeajax").html("");
					}				
				});
				this.closeFlash($flashDiv);
			},
			closeFlash : function($flashDiv){
				flash = $flashDiv
   				jQuery("<a />").addClass("close").attr("href", "#").appendTo(flash).click(function(ev){
      				flash.fadeOut(600);
      				flash.html("");
      				return false;
   				});
   				setTimeout(function() {
      				if(flash.css("display") != 'none'){
         					flash.hide('blind', {}, 500);
      				}
      				flash.html("");
    				}, 20000);
			},
			hide:function(){
				this.isVisible = false;
				this.stopListening();
				this.$el.hide();
				this.$el.html("");
				window.removeLoaderPage();
			},
			show:function(){
				window.showLoaderPage();
				this.listenToCollection();
				this.$el.show();
				this.isVisible = true;
			},
		 	urlParser: function (uri) {
		 		var splitRegExp = new RegExp(
			        '^' +
			            '(?:' +
			            '([^:/?#.]+)' +                         // scheme - ignore special characters
			                                                    // used by other URL parts such as :,
			                                                    // ?, /, #, and .
			            ':)?' +
			            '(?://' +
			            '(?:([^/?#]*)@)?' +                     // userInfo
			            '([\\w\\d\\-\\u0100-\\uffff.%]*)' +     // domain - restrict to letters,
			                                                    // digits, dashes, dots, percent
			                                                    // escapes, and unicode characters.
			            '(?::([0-9]+))?' +                      // port
			            ')?' +
			            '(([^?#]+))?' +                           // path
			            '(?:\\?([^#]*))?' +                     // query
			            '(?:#(.*))?' +                          // fragment
			            '$');

				if(!uri || uri.length==0){
				    return "";
				}
				var split = uri.match(splitRegExp);
				var path = (split[5])?split[5]:"";
				path = path.replace("\/","");
				if(path=="" && split[3]){
				    return uri;
				}else{
				    return split[5];
				}
			}
	});
};