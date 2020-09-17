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
            this.resetBusyAgent(agent, this.filter.AvailableAgentList);
            this.addAvailableAgentToList(agent);
            this.filter.updateNoOfAgents();
            this.filter.sortLists();
        },

        changeToUnavailableAgent: function (agent) {
            this.userListUpdate(agent,this.filter.Status.OFFLINE,this.filter.Preference.FALSE);
            this.resetBusyAgent(agent, this.filter.UnavailableAgentList);
            this.addUnavailableAgentToList(agent);
            this.filter.updateNoOfAgents();
            this.filter.sortLists();
        },

        changeToBusyAgent: function (agent, agentAvailabilityText) {
            var agent=this.filter.getAgent(agent.id);
            this.userListUpdate(agent,this.filter.Status.BUSY,agent.preference);
            if(agent.preference==this.filter.Preference.TRUE){
                if(this.filter.AvailableAgentList.get("id", agent.id)){
                    var item=this.filter.AvailableAgentList.get("id",agent.id);
                    item.values({ presence_time_in_s: agentAvailabilityText,
                        busy_agent : this.filter.busyState.BUSY,
                        toggle_button : this.filter.toggleButton(agent.id,agent.presence,true) });
                }
            }
            if(agent.preference==this.filter.Preference.FALSE){
                if(this.filter.UnavailableAgentList.get("id",agent.id)){
                    var item=this.filter.UnavailableAgentList.get("id",agent.id);
                    item.values({ presence_time_in_s: agentAvailabilityText,
                        busy_agent : this.filter.busyState.BUSY,
                        toggle_button : this.filter.toggleButton(agent.id,agent.presence,false) });
                }
            }
            this.filter.sortLists();
            this.filter.updateNoOfAgents();
        },

        changeAgentDevice: function(agent){
            var device_image = (agent.on_phone=="true") ? this.filter.on_mobile_template : this.filter.on_browser_template;
            var item=this.filter.AvailableAgentList.get("id",agent.id);
            item.values({on_device_img: device_image });
            this.userListUpdate(agent,this.filter.Status.ONLINE,this.filter.Preference.TRUE);
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

        resetBusyAgent: function(agent, list){
            if(list.get("id",agent.id)){
                var agent=this.filter.getAgent(agent.id);
                var item=list.get("id",agent.id);
                var is_online = agent.presence == this.filter.Status.ONLINE ? true : false ;
                var presence_in_words=agent.last_call_time == null ? freshfone.no_activity :'<span data-livestamp="'+agent.last_call_time+'"></span>';
                var checked = agent.presence == this.filter.Status.ONLINE ? "checked" : "" ;
                item.values({ presence_time_in_s: presence_in_words,
                    presence_time: agent.last_call_time,
                    toggle_button: this.filter.toggleButton(agent.id,agent.presence,is_online),
                    busy_agent: this.filter.busyState.NOT_BUSY });
                this.filter.sortLists();
            }
        },

        userListUpdate: function(agent,presence,preference){
            var last_call=agent.presence_time==""? null:agent.presence_time;
            var on_phone = JSON.parse(agent.on_phone);
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