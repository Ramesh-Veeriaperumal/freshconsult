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
  		if(typeof freshfone != "undefined" && freshfone.agents!=undefined){
          this.Filter.init();
          this.Node.init();
          App.AgentEvents.ffoneEventsInit();
         App.AgentEvents.bindPresenceToggle();
  		}
    },
    onLeave: function () {
      App.AgentEvents.leave();
    }
  };
})(jQuery); 