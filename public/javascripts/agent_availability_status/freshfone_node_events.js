window.App = window.App || {};
window.App.Freshfoneagents = window.App.Freshfoneagents || {};
(function ($) {
  "use strict";
  window.App.Freshfoneagents.Node = { 
    
    init: function () {
    this.filter=App.Freshfoneagents.Filter;
    },

    changeToAvailableAgent: function (agent) {
      this.userListUpdate(agent,this.filter.Status.ONLINE,this.filter.Preference.TRUE);
       this.ifBusyToAvailable(agent);      
       this.removeAgent(agent,this.filter.UnavailableAgentList);
       this.addAvailableAgentToList(agent);
       this.filter.sortLists();
    },
    
    changeToUnavailableAgent: function (agent) {  
      this.userListUpdate(agent,this.filter.Status.OFFLINE,this.filter.Preference.FALSE);
       this.removeAgent(agent,this.filter.AvailableAgentList);
       this.addUnavailableAgentToList(agent);
       this.filter.sortLists();
     },
    
    changeToBusyAgent: function (agent) {
      var agent=this.filter.getAgent(agent.id);
          this.userListUpdate(agent,this.filter.Status.BUSY,this.filter.Preference.TRUE);
          if(agent.preference==this.filter.Preference.TRUE){
            if(this.filter.AvailableAgentList.get("id",agent.id)){
              $.each(this.filter.availableListArray,jQuery.proxy(function(index,value)  {
                  if(value==agent.id){
                      var item=this.filter.AvailableAgentList.get("id",agent.id);
                      item.values({presence_time_in_s: freshfone.call_in_progress });
                  }
              },this));
            }
         this.filter.updateNoOfAgents();
          }
    },
    
    addAvailableAgentToList: function(agent){
      if(!this.filter.AvailableAgentList.get("id",agent.id)){
        $.each(this.filter.unavailableListArray,jQuery.proxy(function(index,value)  {
          if(value==agent.id){
            this.filter.addAgentByDevice(agent.id);
            this.filter.availableListArray[agent.id]=agent.id; 
            this.filter.updateNoOfAgents();
          }
          },this)); 
         this.filter.unavailableListArray.splice(agent.id,1,'');
      }
    },
   
    addUnavailableAgentToList: function(agent){
      if(!this.filter.UnavailableAgentList.get("id",agent.id)){
        $.each(this.filter.availableListArray,jQuery.proxy(function(index,value)  {
        if(value==agent.id){
          this.filter.UnavailableAgentList.add(this.filter.unavailableUserListItem(agent.id)); 
          this.filter.unavailableListArray[agent.id]=agent.id; 
          this.filter.updateNoOfAgents();
        }
        },this)); 
       this.filter.availableListArray.splice(agent.id,1,'');
      }
    },
    
    ifBusyToAvailable: function(agent){
       if(this.filter.AvailableAgentList.get("id",agent.id)){
         var agent=this.filter.getAgent(agent.id);
        var item=this.filter.AvailableAgentList.get("id",agent.id);
       var presence_in_words=agent.last_call_time==null ? freshfone.no_activity :'<span data-livestamp="'+agent.last_call_time+'"></span>';
     item.values({presence_time_in_s: presence_in_words});
      }
    },
    
   userListUpdate: function(agent,presence,preference){
    var last_call=agent.presence_time==""? null:agent.presence_time;
        $.each(freshfone.agents,jQuery.proxy(function(index,value)  {
            if(value["id"]==agent.id){
               value["presence"]=presence;
               value["preference"]=preference;
               value["last_call_time"]= last_call;
               this.filter.timeInWords(this.filter.getAgent(agent.id));
            }  
        },this)); 
    },
    removeAgent:function(agent,list){
      if(list.get("id",agent.id)){
          list.remove("id",agent.id);
          }
    }
    
  };
  
  }(window.jQuery));