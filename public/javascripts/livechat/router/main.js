window.liveChat = window.liveChat || {};

window.liveChat.archiveRouter = function(){
	return Backbone.Router.extend({
		routes: {
			"archive" : "loadArchiveHomePage",
			"archive/visitor/:params": "filterByVisitor",
			"archive/:params" : "loadMessage",
			"visitor/:type"   : "loadVisitor",
			"archive/agent/:params": "filterByAgent"
		},
		initialize:function(options){
			window.archiveRouter = this;
			this.archiveCollection = new options.archiveCollection();
			this.visitorCollection = options._visitorCollection;
			this.archiveView = new options.archiveView({collection:this.archiveCollection,router:this});
			this.conversationView= new options.conversationView({
				collection:this.archiveCollection,
				router :this,
			});
      		this.visitorListView = options.visitorListView;
		},
		loadArchiveHomePage:function(filterParams){
		 	this._showArchivePage();
			this.archiveCollection.loadHomePage(filterParams);
		},
		loadMessage : function(params){
			// If archive page is already visible
			if(this.archiveView.isVisible === true){
				this.archiveView.hide();
			}
			if(this.conversationView.isVisible === false){
				this.conversationView.show();
			}
			//Getting the models from the collection or creating a new one.
			var archiveModel = this.archiveCollection.get(params);
			if(archiveModel === undefined){
				archiveModel = new this.archiveCollection.model({id:params});
				this.archiveCollection.add(archiveModel);
			}
			archiveModel.fetchMessage();
		},
		filterByVisitor:function(params){
			var visitorId = _.escape(params);
			this.navigate("/archive");
			this._showArchivePage(); 
			jQuery("#visitor_id").val(params);
			jQuery("#submit").click();
		},
		filterByAgent:function(params){
			var agentIds = _.escape(params);
			this.navigate("/archive");
			this._showArchivePage();
			jQuery("#agent_ids").val(params);
			jQuery("#submit").click();
		},
		destroyAll : function(){
			this.conversationView.remove();
			this.archiveView.remove();
			this.archiveCollection.reset();
			if(this.filterd_visitors){
			  this.filterd_visitors.remove();
			}
			if(this.filterd_view){
			  this.filterd_view.remove();
			  this.filterd_view.destroyAutoRefreshTimer();
			}
			window.visitorCollection.removeUsedInParam(null,"archive");
			window.Backbone.history.stopListening();
			window.Backbone.history.stop();
		},
		_showArchivePage : function(){
			if(this.conversationView.isVisible === true){
				this.conversationView.hide();
			}
			if(this.archiveView.isVisible === false){
				this.archiveView.show();
			}
		},
		loadVisitor : function (type){
			//create a new fileterd view of visitors
			var that = this;
			if(this.filterd_visitors){
				this.filterd_visitors.remove();
			}
			if(this.filterd_view){
				this.filterd_view.remove();
				this.filterd_view.destroyAutoRefreshTimer();
			}
			this.filterd_visitors = new that.visitorCollection();
			this.filterd_view = new that.visitorListView({
				type:type,
				collection : visitorCollection,
				filteredCollection : that.filterd_visitors,
				router : that
			});
			this.filterd_view.addLoader();
			visitorCollection.fetch({ type:type });
		}
	});
};

