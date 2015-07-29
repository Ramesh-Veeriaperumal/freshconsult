window.liveChat = window.liveChat || {};

liveChat.archiveView = function(){
		return Backbone.View.extend({
			initialize :function(options){
				this.isVisible = false;
				this.router = options.router;
				this.setElement('#archive-container');
				this.$pageWrap = jQuery('#report-page');
				this.archiveTemplate = window.JST["livechat/templates/archive/main"];
				this.archiveRowTemplate  = window.JST["livechat/templates/archive/archiveRow"];
			},
			events:{
				"click #change-page"	: "loadPage",
				"click #next-page"		: "loadNextPage",
				"click #prev-page"		: "loadPrevPage",
				"click #convert-ticket"	: "showTicketOption",
				"click #add-note"		: "addNote",
				"click tr" 				: "navigateToMessage",
				"click #ticket-link" 	: "loadTicketPage"
			},
			listenToCollection:function(){
				this.listenTo(this.collection,'reset',this.render);
				this.listenTo(this.collection,'change',this.collectionChange);
			},
			render:function(){
				this.$el.html(this.archiveTemplate({
					models:this.collection.toJSON(),
					paginationData : this.collection.getPaginationData(),
					archiveRowTemplate: this.archiveRowTemplate
				}));
				this.$pageWrap.show();
				window.removeLoaderPage();
			},
			loadPage:function(event){
				event.preventDefault();
				var pageNo = parseInt(event.target.innerHTML);
				if(typeof pageNo ==="number"){
					this.collection.loadPage(pageNo);
				}
			},
			loadPrevPage:function(event){
				event.preventDefault();
				this.collection.loadPrevPage();				
			},
			loadNextPage:function(event){
				event.preventDefault();
				this.collection.loadNextPage();				
			},
			navigateToMessage:function(event){
				var msgId = event.currentTarget.id;
				if(msgId){
					this.router.navigate("archive/"+msgId,{trigger:true});		
				}
			},
			show:function(){
				this.listenToCollection();
				this.$pageWrap.show();
				jQuery('#report-filter-edit').show();
				this.isVisible = true;
			},
			hide:function(){
				this.isVisible = false;
				this.stopListening();
				jQuery('#report-filter-edit').hide();
				this.$pageWrap.hide();

			},
			showTicketOption : function(event){
				event.preventDefault();
				event.stopPropagation();

				var archiveModelAttr = this.findArchiveModel(event);
				if(window.liveChat.ticketOptions && archiveModelAttr){
						liveChat.ticketOptions.initialize(archiveModelAttr,null,true);
				}
			},
			addNote : function(event){
				event.preventDefault();
				event.stopPropagation();
				var archiveModelAttr = this.findArchiveModel(event);
				if(window.liveChat.ticketOptions && archiveModelAttr){
					liveChat.ticketOptions.initialize(archiveModelAttr,null,true);
				}
			},
			findArchiveModel :function(event){
				var $targetElement = jQuery(event.currentTarget);
				var chatId = $targetElement.data().chatId;
				var archiveModel = this.collection.get(chatId);
				if(archiveModel){
					return archiveModel.toJSON();;
				}else{
					return null;
				}
			},
			collectionChange :function(model){
				this.renderRow(model);
			},
			renderRow:function(archiveModel){
				var $targetRow = this.$el.find("#"+archiveModel.id);
				if($targetRow.length>0){
					$targetRow.html(this.archiveRowTemplate({
						modelJson:archiveModel.toJSON()
					}));	
				}
			},
			loadTicketPage:function(event){
				event.stopPropagation();
			}
		});
	};