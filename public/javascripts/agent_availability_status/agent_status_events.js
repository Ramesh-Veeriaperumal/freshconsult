window.App = window.App || {};
(function ($) {
  "use strict";
  window.App.AgentEvents = { 
    
    agentTabEventsInit : function(){
      this.agentTabSelection();
    } ,
    ffoneEventsInit: function () {
    this.filter=App.Freshfoneagents.Filter;
      this.ffoneGroupDropdown();
      this.ffoneSortDropdown();
      this.ffoneAgentPillSelection();
      this.listenToSocket();
    },
    ticketEventsInit : function(){
      this.ticketsAgentPillSelection();
    },
    ffoneSortDropdown: function () {
     var self=this;
      $("body").on("click.agentevents",".sort li", function () {
           if($(this).data("id")==self.filter.prev_sort){
              return;
            }
           else{
             if($(this).data("id")=="sort_name"){
              self.filter.sort_order_list=["busy_agent","name","presence_time"];
                $(" #sort_by ").text(freshfone.name);
                $(" .sort_presence").find('.icon').remove();
              }
             else if($(this).data("id")=="sort_presence"){   
               self.filter.sort_order_list=["busy_agent","presence_time","name"];
                $(" #sort_by ").text(freshfone.last_modifed); 
                $(" .sort_name ").find('.icon').remove();
              }
             self.filter.prev_sort=$(this).data("id");
            $(this).prepend($('<span class="icon ticksymbol"></span>'));
             self.filter.sortLists();
             $(this).prepend($('<span class="icon ticksymbol"></span>'));
          }
       });    
    },
    ffoneGroupDropdown: function () {
      var self = this;
      $("body").on("click.agentevents ",".group li", function () {
          if(this!=self.filter.prev_group){
            self.filter.populateAgentsByGroups($(this).data("id"),$(this).text());
            $(self.filter.prev_group).find('.icon').remove();
            $(".filter-name ").text($(this).text());
            $(this).prepend($('<span class="icon ticksymbol"></span>'));
          }
          self.filter.prev_group=this;
      }); 
     
    },
    ffoneAgentPillSelection: function(){
      var filter=App.Freshfoneagents.Filter;
      $("body").on("click.agentevents","ul.ffone-minimal-swap li", function () {
          var tab_id = $(this).attr('data-tab');
          $('ul.ffone-minimal-swap li').removeClass('current');
          $('.ffone-minimal-tab').removeClass('current');
          $(this).addClass('current');
          $("#"+tab_id).addClass('current'); 
          if(tab_id=="ffone-tab-1"){                             
            filter.checkList(filter.AvailableAgentList.length,".no-available-agents","#ffone-tab-1");
             $(".no-unavailable-agents").hide();
          }
           if(tab_id=="ffone-tab-2"){
            filter.checkList(filter.UnavailableAgentList.length,".no-unavailable-agents","#ffone-tab-2");
            $(".no-available-agents").hide();
          }
       });
    },
    ticketsAgentPillSelection: function(){
      var filter=App.Freshfoneagents.Filter;
      $("body").on("click.agentevents","ul.ticket-minimal-swap li", function () {
          var tab_id = $(this).attr('data-tab');
          $('ul.ticket-minimal-swap li').removeClass('current');
          $('.ticket-minimal-tab').removeClass('current');
          $(this).addClass('current');
          $("#"+tab_id).addClass('current'); 

       });
    },
    agentTabSelection : function(){
      jQuery.noConflict();
      $('.roundrobin-tabs a').click(function(e) {
        e.preventDefault();
        history.pushState( null, null, jQuery(this).attr('href') );
        $(this).tab('show');
      });
     },
    leave: function() {
      $('body').off('.agentevents');
      $(document).off('.agentevents');
    },

    listenToSocket: function(){
      $(document).on("ffone_socket.agentevents", function (ev, data) {
        switch (data.event){
          case "agent_available":
            App.Freshfoneagents.Node.changeToAvailableAgent(data.user);
            break;
          case "agent_unavailable": 
            App.Freshfoneagents.Node.changeToUnavailableAgent(data.user);
            break;
          case "agent_busy":
            App.Freshfoneagents.Node.changeToBusyAgent(data.user,freshfone.call_in_progress);
            break;
          case "agent_in_acw_state":
            App.Freshfoneagents.Node.changeToBusyAgent(data.user,freshfone.call_in_acw);
            break;
          case "toggle_device":
            App.Freshfoneagents.Node.changeAgentDevice(data.user);
            break;
        }
      });  
    },
    bindPresenceToggle: function(){
      $('body').on('change','.phone_item',function() {
        $(this).prop('disabled','disabled')
            $.ajax({
               type: "POST",
               dataType: "json",
               url: '/freshfone/users/manage_presence',
               data: {
                 'agent_id': $(this).data("id")
               },
               success: function (data) {
               }
             });
        });
    }
  };
}(window.jQuery));