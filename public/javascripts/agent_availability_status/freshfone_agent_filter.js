window.App = window.App || {};
window.App.Freshfoneagents = window.App.Freshfoneagents || {};
(function ($) {
  "use strict";
  window.App.Freshfoneagents.Filter = {
    start: function(){
      this.userList = [];
      this.availableListArray = [];
      this.unavailableListArray = [];
      this.agent = "";
      this.is_sorted_by_name = false;
      this.prev_sort= "sort_presence";
      this.prev_group = "";
      this.prev_pill = "";
      this.presence_in_words = "";
      this.last_call_in_words = "";
      this.list_length = freshfone.agents.length;
      this.Status = {ONLINE:1, OFFLINE:0, BUSY:2, ACW:3};
      this.Preference = {TRUE:1, FALSE:0};
      this.AvailableAgentListValuesName = ["id", "data_id", "name", "available_avatar_image", "presence_time",
                                            "presence_time_in_s", "on_device_img","busy_agent","toggle_button"];
      this.UnavailableAgentListValuesName = [ "id", "data_id", "name", "presence_time" , "unavailable_avatar_image" , "presence_time_in_s" ,
                                            "busy_agent", "toggle_button" ]
      this.AvailableAgentList = new List('ffone-tab-1',{page:this.list_length, valueNames: this.AvailableAgentListValuesName });
      this.UnavailableAgentList = new List('ffone-tab-2',{page:this.list_length, valueNames: this.UnavailableAgentListValuesName });
      this.busyState = { BUSY : "1", NOT_BUSY : "0" };
      this.sort_by = "name"
      this.sort_by_hash = {"name" : 1, "presence_time" :  -1, "busy_agent" : -1};
      this.sort_order_list = ["busy_agent","presence_time","name"];
      this.on_mobile_template = '<i class="ficon-available-on-mobile active fsize-20 pull-left "></i>';
      this.on_browser_template = '<i class="ficon-ff-on-browser active fsize-20 pull-left "></i>';
      this.toggle_button_template = $("#phone_toggle").clone();
      this.busy_toggle_button_template = $("#busy_phone_toggle").clone();
    },
    init: function () {
      this.start();
       var g_id=freshfone.group_from_cookie==""? 0 : freshfone.group_from_cookie;
      this.populateAgentsByGroups(g_id);
    },
    getAgent: function(agent_id){
      return freshfone.agents.find(function(agent){
              if(agent.id == agent_id){ 
                return agent;
              }
      });
    },
    
    timeInWords: function(agent){
      
     this.presence_in_words=agent.last_call_time==null ? freshfone.no_activity : '<span data-livestamp="'+agent.last_call_time+'"></span>';
      
    },
    availableUserListItem: function(id,img_on_device){
      this.agent=this.getAgent(id);
      this.timeInWords(this.agent);
      if(this.agent.presence==this.Status.BUSY){
        this.presence_in_words = freshfone.call_in_progress;
      }
      else if(this.agent.presence==this.Status.ACW){
        this.presence_in_words = freshfone.call_in_acw;
      }
      return { id : this.agent.id, 
               data_id : "<span class='id' data-id='"+this.agent.id+"'></span>",
               name : this.agent.name, 
               available_avatar_image : this.agent.avatar,
               presence_time : this.agent.last_call_time,
               presence_time_in_s : this.presence_in_words, 
               on_device_img : img_on_device,
               busy_agent : this.agent.presence==this.Status.BUSY ? this.busyState.BUSY : this.busyState.NOT_BUSY,
               toggle_button : this.toggleButton(this.agent.id,this.agent.presence,true)
              }
    },
    unavailableUserListItem: function(id){
       this.agent = this.getAgent(id);
       this.timeInWords(this.agent);
       if(this.agent.presence==this.Status.BUSY){
        this.presence_in_words = freshfone.call_in_progress;
       }
       else if(this.agent.presence==this.Status.ACW){
        this.presence_in_words = freshfone.call_in_acw;
       }
      return { id : this.agent.id, 
               data_id : "<span class='id' data-id='"+this.agent.id+"'></span>",
               name : this.agent.name,
               presence_time : this.agent.last_call_time,
               unavailable_avatar_image : this.agent.avatar, 
               presence_time_in_s : this.presence_in_words,
               busy_agent : this.agent.presence==this.Status.BUSY ? this.busyState.BUSY : this.busyState.NOT_BUSY,
               toggle_button : this.toggleButton(this.agent.id,this.agent.presence,false)
              }
    },
    toggleButton: function(user_id,presence,flag){
      if(presence==this.Status.BUSY){
        var busy_template = this.busy_toggle_button_template.tmpl(this.toggleButtonParams(user_id,this.toggleButtonType(flag),true));
        var busy_toggle_template = busy_template[0].outerHTML+busy_template[2].outerHTML
        return busy_toggle_template;
      }
      else{
        return this.toggle_button_template.tmpl(this.toggleButtonParams(user_id,this.toggleButtonType(flag),false))[0].outerHTML;
      }
    },
    toggleButtonType: function(flag){
      return flag ? "checked" : "" ;
    },
    toggleButtonParams: function(user_id,checked,busy){
      return  busy ? {id : user_id, value : checked, in_progress: freshfone.agent_on_call } : {id : user_id, value : checked } ;
    },
    populateAgents: function(){  
         this.AvailableAgentList.clear();
         this.UnavailableAgentList.clear();
         $.each(freshfone.agents,jQuery.proxy(function(index,value)  {
            this.addAgentByPresence(value["id"]);
         },this)); 
         this.setTickIcon(this.sort_order_list[0]);
          this.sortLists();
          this.updateNoOfAgents();
   },
   populateAgentsByGroups: function(group_id){  
      this.AvailableAgentList.clear();
      this.UnavailableAgentList.clear();
      this.availableListArray=[];
      this.unavailableListArray=[];
      this.getAgentsByGroup(group_id);   
    },

    getAgentsByGroup: function (freshfone_group_id) {
      var self=this;
           $.ajax({           
                        url:  '/helpdesk/dashboard/'+freshfone_group_id+'/agents',
                        dataType: "json",
                        method: 'GET',
                        success: function (data) {
                              if(data.id=="0"){
                                self.populateAgents();
                              }
                              else{
                                data.id.each(function(g_id){
                                  self.addAgentByPresence(g_id);
                                });   
                                self.setTickIcon(self.sort_order_list[0]);
                                self.sortLists();
                                self.updateNoOfAgents();
                              }
                        } ,
                        error: function(data){
                        }
                  });
    },
    
    addAgentByPresence: function (id) {
        this.agent=this.getAgent(id);
        if (this.agent.presence==this.Status.ONLINE){
              if(!this.AvailableAgentList.get("id",id)){
                this.addAgentByDevice(id);
              }
        }  
        if ((this.agent.presence==this.Status.BUSY) || (this.agent.presence==this.Status.ACW)){
           if(this.agent.preference==this.Preference.TRUE){
              if(!this.AvailableAgentList.get("id",id)){
                this.addAgentByDevice(id);
              }
            }
            else{
              this.UnavailableAgentList.add(this.unavailableUserListItem(id));
            }
        }  

        if (this.agent.presence==this.Status.OFFLINE){
              if(!this.UnavailableAgentList.get("id",id)){
              this.UnavailableAgentList.add(this.unavailableUserListItem(id));
              }
        }
    },
    
    addAgentByDevice: function(id){                                       
      this.agent=this.getAgent(id);
      var on_device_img=this.set_device(this.agent.on_phone)
      this.AvailableAgentList.add(this.availableUserListItem(id,on_device_img));
    },
    set_device: function(phone_flag){ 
       return phone_flag  ? this.on_mobile_template : this.on_browser_template ;
    },  
    setTickIcon: function(sort_by){
       if(sort_by=="name"){
            $(" .sort_name").prepend($('<span class="icon ticksymbol"></span>'));
          }
          else{
            $(" .sort_presence").prepend($('<span class="icon ticksymbol"></span>'));
          }  
    },
    sortLists: function() {                         
      this.checkList(this.AvailableAgentList.size(),".no-available-agents","#ffone-tab-1");
      this.checkList(this.UnavailableAgentList.size(),".no-unavailable-agents","#ffone-tab-2");  
         
       for(var i=this.sort_order_list.length-1;i>=0;i--){
        this.sort_by=this.sort_order_list[i];
        this.AvailableAgentList.sort('', {sortFunction: this.sortFunction});
        this.UnavailableAgentList.sort('',{sortFunction: this.sortFunction});

        }
    },

    sortFunction: function(a,b){
      var sort_by=App.Freshfoneagents.Filter.sort_by;
      var val_hash=App.Freshfoneagents.Filter.sort_by_hash;
      var a_val = a.values()[sort_by] || "";
      var b_val = b.values()[sort_by] || "";
      var temp=a_val.localeCompare(b_val);
      return temp*val_hash[sort_by];
    },
    
    updateNoOfAgents: function(){      
          $("#accepting_count").html(this.AvailableAgentList.size());
          $("#not_accepting_count").html(this.UnavailableAgentList.size());
    },
    checkList: function(list_size,title_class,tab_id){
        if(list_size==0){ 
          $(title_class).html(freshfone.no_agents);
          this.checkCurrentTab(tab_id,title_class);
        }
        if(list_size>0){ 
          $(title_class).html("");
          $(title_class).hide();
        }
        
    },
    checkCurrentTab : function(tab_id,title_class){
      if($(tab_id).hasClass('current')){
              $(title_class).show();
            }
            else{
              $(title_class).hide();
            }  
    }
    
  };
}(window.jQuery));