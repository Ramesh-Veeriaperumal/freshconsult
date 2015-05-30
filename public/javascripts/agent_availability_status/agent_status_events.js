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
              self.filter.sort_order_list=["name","presence_time"];
                $(" #sort_by ").text(freshfone.name);
                $(" .sort_presence").find('.icon').remove();
              }
             else if($(this).data("id")=="sort_presence"){   
               self.filter.sort_order_list=["presence_time","name"];
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
            filter.checkList(filter.AvailableAgentList.size(),".no-available-agents","#ffone-tab-1");
             $(".no-unavailable-agents").hide();
          }
           if(tab_id=="ffone-tab-2"){
            filter.checkList(filter.UnavailableAgentList.size(),".no-unavailable-agents","#ffone-tab-2");
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
    }

  };
}(window.jQuery));