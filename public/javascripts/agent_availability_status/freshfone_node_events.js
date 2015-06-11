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
       this.ifWasBusy(agent,this.filter.AvailableAgentList);      
       this.addAvailableAgentToList(agent);
       this.filter.updateNoOfAgents();  
       this.filter.sortLists();
    },
    
    changeToUnavailableAgent: function (agent) {  
      this.userListUpdate(agent,this.filter.Status.OFFLINE,this.filter.Preference.FALSE);
       this.ifWasBusy(agent,this.filter.UnavailableAgentList);
       this.addUnavailableAgentToList(agent);
       this.filter.updateNoOfAgents();  
       this.filter.sortLists();
     },
    
    changeToBusyAgent: function (agent) {
      var agent=this.filter.getAgent(agent.id);
          this.userListUpdate(agent,this.filter.Status.BUSY,this.filter.Preference.TRUE);
          if(agent.preference==this.filter.Preference.TRUE){
            if(this.filter.AvailableAgentList.get("id",agent.id)){
                      var item=this.filter.AvailableAgentList.get("id",agent.id);
                      item.values({presence_time_in_s: freshfone.call_in_progress });
            }
            if(this.filter.UnavailableAgentList.get("id",agent.id)){
                      var item=this.filter.UnavailableAgentList.get("id",agent.id);
                      item.values({presence_time_in_s: freshfone.call_in_progress });
            }
         this.filter.updateNoOfAgents();
          }
    },
    
    addAvailableAgentToList: function(agent){
      if(!this.filter.AvailableAgentList.get("id",agent.id)&&
          this.filter.UnavailableAgentList.get("id",agent.id)){
          this.filter.addAgentByDevice(agent.id);
          this.removeAgent(agent,this.filter.UnavailableAgentList);
      }
    },
   
    addUnavailableAgentToList: function(agent){
      if(!this.filter.UnavailableAgentList.get("id",agent.id)&&
          this.filter.AvailableAgentList.get("id",agent.id)){
          this.filter.UnavailableAgentList.add(this.filter.unavailableUserListItem(agent.id)); 
          this.removeAgent(agent,this.filter.AvailableAgentList);
      }
    },
    
    ifWasBusy: function(agent,list){
       if(list.get("id",agent.id)){
         var agent=this.filter.getAgent(agent.id);
        var item=list.get("id",agent.id);
       var presence_in_words=agent.last_call_time==null ? freshfone.no_activity :'<span data-livestamp="'+agent.last_call_time+'"></span>';
     item.values({presence_time_in_s: presence_in_words, presence_time: agent.last_call_time});
      }
    },
    
   userListUpdate: function(agent,presence,preference){
    var last_call=agent.presence_time==""? null:agent.presence_time;
    var on_phone=agent.on_phone==="true"? true: false;
        $.each(freshfone.agents,jQuery.proxy(function(index,value)  {
            if(value["id"]==agent.id){
               value["presence"]=presence;
               value["preference"]=preference;
               value["last_call_time"]= last_call;
               value["on_phone"]=on_phone;
               this.filter.timeInWords(this.filter.getAgent(agent.id));
            }  
        },this)); 
    },
    removeAgent:function(agent,list){
          list.remove("id",agent.id);
    }
    
  };
  
  }(window.jQuery));