(function(){
  window.liveChat = window.liveChat || {};
  window.liveChat.agentsAvailabilityView = function(){
    var AgentsAvailability =  Backbone.View.extend({
      availableAgents: [],
      unavailableAgents: [],
      offlineAgents: [],
      groupCollection: null,
      groupSelected: false,
      filterBy: "name",
      
      initialize: function(){
        this.availableAgentsTemplate = window.JST['livechat/templates/agentAvailability/agentAvailability'];
        this.setElement('#lc-availability');
        this.collection = userCollection;
        this.collection.syncAvailabilityStatus();
        this.resetCollection();
        this.listenToCollection();
        this.listenToEvents();
        if(this.autoRefreshAgentList){
          this.autoRefreshAgentList.stop();
        }
        this.autoRefreshAgentList = new PeriodicalExecuter(function(pe) {
          if(window.location.pathname !== "/helpdesk/agent_status"){
            this.autoRefreshAgentList.stop();
          }else{
            window.userCollection.syncAvailabilityStatus();
            this.resetCollection();
          }
        }.bind(this),120);
      },
      listenToCollection: function(){
        this.listenTo(this.collection,'change', _.bind(this.resetCollection, this, null));
      },
      listenToEvents: function(){
        var that = this;
        jQuery('#fc-group-filter').off('click').on('click', "a" , function(event){
          event.preventDefault();
          var $parentElem = jQuery(event.target.parentElement);
          if($parentElem.length > 0 && $parentElem.data('id') != "disabled"){
            jQuery("#fc-group-name").html(event.target.innerHTML); 
            that.getGroups($parentElem.data('id'));
          }
        });
        jQuery('#fc-sort-filter').off('click').on('click', "a", function(event){
          event.preventDefault();
          jQuery("#sort_by").html(event.target.innerHTML); 
          var $targetElem = jQuery(event.target.parentElement);
          if($targetElem.data('id') == "sort_presence"){
            that.filterBy = "last_activity_at";
          }else{
            that.filterBy = "name";
          }
          that.resetCollection();
        });
      },
      render: function(){
        this.$el.find("#lc-tab-1 .list").html(this.availableAgentsTemplate({
            models: this.availableAgents,
            showCount: true
        }));
        this.$el.find("#lc-tab-2 .list").html(this.availableAgentsTemplate({
            models: this.unavailableAgents,
            showCount: true
        }));
        this.$el.find("#lc-tab-3 .list").html(this.availableAgentsTemplate({
            models: this.offlineAgents,
            showCount: false
        }));
        this.setTabCount();
      },
      setTabCount: function(){
        jQuery("#accepting_count").html(this.availableAgents.length).show();
        jQuery("#not_accepting_count").html(this.unavailableAgents.length + this.offlineAgents.length).show();
        jQuery("#offline_count").html(this.offlineAgents.length).show();
      },
      getGroups: function(group_id){
        var that = this;
        if(group_id == 0){
            this.groupSelected = false;
            that.resetCollection();
        }else{
            this.groupSelected = true;
            that.getAgentsInGroups(window.liveChat.agentsInGroups[group_id].users);
        }
      },
      getAgentsInGroups: function(_agents){
        var that = this;
        var models = [];
        this.clearCollection();
        this.groupCollection = that.collection.clone();
        if(_agents.length){
         _.each(_agents,function(agent){
           _.filter(that.collection.models, function(model){
              if(model.id == agent){
                models.push(model);
              }
            });
          });  
          this.groupCollection.models = models;
          this.resetCollection();
        }else{
            this.groupCollection.models = models;
            this.render();
        }
      },
      clearCollection: function(){
        this.groupCollection = null;
        this.availableAgents = [];
        this.unavailableAgents = [];
        this.offlineAgents = []; 
      },
      resetCollection: function(){
        var that = this;
          if(this.groupSelected){
             that.groupCollection.models = that.sortByTime(that.groupCollection);
             that.availableAgents = that.groupCollection.availableAgents();
             that.unavailableAgents = that.groupCollection.unavailableAgents();
             that.offlineAgents = that.groupCollection.offlineAgents();
          }else{
             that.collection.models = that.sortByTime(that.collection);
             that.availableAgents = that.collection.availableAgents();
             that.unavailableAgents =  that.collection.unavailableAgents();
             that.offlineAgents = that.collection.offlineAgents();
          } 
        that.render();
      },
      sortByTime :function(collection){
        var that = this;
        if(that.filterBy == "name"){
          return _.sortBy(collection.models, function(model){
            if(model.attributes[that.filterBy]){
              return model.attributes[that.filterBy].toLowerCase();
            }
          });
        }else{
          return _.sortBy(collection.models, function(model){
            if(model.attributes[that.filterBy]){
              return new Date(model.attributes[that.filterBy]).getTime() * -1; // -1 for getting reverse array with null values at last
            }
          });
        }
      }
    });

    return new AgentsAvailability();
  };
})();