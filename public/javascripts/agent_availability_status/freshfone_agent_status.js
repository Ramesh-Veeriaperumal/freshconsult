window.App = window.App || {};
(function ($){
  "use strict";
  App.Freshfoneagents = {
    onFirstVisit: function (data) {
      this.onVisit(data);
    },
    onVisit: function (data) {
      App.AgentEvents.ticketEventsInit();
      App.AgentEvents.agentTabEventsInit();
  		if(freshfone.agents!= undefined && typeof freshfone != "undefined"){
          this.Filter.init();
          this.Node.init();
          App.AgentEvents.ffoneEventsInit();
  		}
    },
    onLeave: function () {
      App.AgentEvents.leave();
    }
  };
})(jQuery); 