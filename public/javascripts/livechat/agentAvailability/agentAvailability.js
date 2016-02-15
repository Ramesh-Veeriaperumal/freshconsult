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
        this.applyCachedFilters();
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
        jQuery('#lc-group-filter').off('click').on('click', "a" , function(event){
          event.preventDefault();
          var $parentElem = jQuery(event.target.parentElement);
          if($parentElem.length > 0 && $parentElem.data('id') != "disabled"){
            jQuery("#lc-group-name").html(event.target.innerHTML); 
            that.getGroups($parentElem.data('id'));
            window.localStorage.setItem('lc_av_group_filter', $parentElem.data('id'));
          }
        });
        jQuery('#lc-sort-filter').off('click').on('click', "a", function(event){
          event.preventDefault();
          jQuery("#lc-sort-by").html(event.target.innerHTML); 
          var $targetElem = jQuery(event.target.parentElement);
          if($targetElem.data('id') == "sort-presence"){
            that.filterBy = "last_activity_at";
          }else{
            that.filterBy = "name";
          }
          that.resetCollection();
          window.localStorage.setItem('lc_av_sort_filter', $targetElem.data('id'));
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
      applyCachedFilters: function(){
        var lc_av_group_filter = window.localStorage.getItem('lc_av_group_filter');
        var lc_av_sort_filter = window.localStorage.getItem('lc_av_sort_filter');

        if(lc_av_group_filter){
          this.$el.find("#lc-group-filter li[data-id="+lc_av_group_filter+"] a").trigger('click');
        }

        if(lc_av_sort_filter){
          this.$el.find("#lc-sort-filter li[data-id="+lc_av_sort_filter+"] a").trigger('click');
        }
      },
      setTabCount: function(){
        jQuery("#lc-availability #accepting_count").html(this.availableAgents.length).show();
        jQuery("#lc-availability #not_accepting_count").html(this.unavailableAgents.length + this.offlineAgents.length).show();
        jQuery("#lc-availability #offline_count").html(this.offlineAgents.length).show();
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
          return _.sortBy(_.sortBy(collection.models, function(model){
            if(model.attributes[that.filterBy]){
              return new Date(model.attributes[that.filterBy]).getTime() * -1; // -1 for getting reverse array with null values at last
            }
          }), function(model){
            return !model.attributes.onGoingChatCount;
          });
        }
      }
    });

    return new AgentsAvailability();
  };
})();