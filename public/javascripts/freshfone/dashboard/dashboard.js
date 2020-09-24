window.App = window.App || {};
(function ($){
  "user strict";
  App.Freshfonedashboard = {
    onFirstVisit: function (data) {
      this.onVisit(data);
    },
    onVisit: function (data) {
      this.bindListView();
      this.LiveCallUpdate.init();
      this.SupervisorCallUpdate.init();
    },
    bindListView: function() {
      this.listOptions = {
        valueNames: ['call_id', 'user_avatar', 'caller_name', 'user_location', 'agent_user_avatar', 'call_direction','agent_name', 'helpdesk_number']
      };
      this.initializeQueueList();
      this.initializeActiveList();
    },
    initializeActiveList: function() {
      var activeListOptions = this.setListItemTemplate(false);
      if(freshfone.isCallMonitoringMode){
        activeListOptions.valueNames.push('join_call_btn'); 
      }
      this.activeCallsList = new List("freshfone_active_calls", activeListOptions);
      this.toggleNoCalls(false);
    },
    initializeQueueList: function() {
      var queueListOptions = this.setListItemTemplate(true);
      this.queuedList = new List("freshfone_queued_calls", queueListOptions);
      this.toggleNoCalls(true);
    },
    setListItemTemplate: function(isQueue) {
      var itemSelector = isQueue ? "queued-call-list-template" : "active-call-list-template"
      var options = { item: itemSelector }, listOptions = this.listOptions;
      if(this.isEmptyList(isQueue)) {
        listOptions = $.extend({}, listOptions, options);
      }
      return listOptions;
    },
    isEmptyList: function(isQueue) {
      var selector = isQueue ? "#freshfone_queued_calls" : "#freshfone_active_calls";
      return ($(selector+" .list li").length == 0);
    },
    toggleNoCalls: function (isQueue) {
      if (this.isEmptyList(isQueue)) {
        var messageSelector = isQueue ? ".no_queue_calls" : ".no_active_calls",
            listContainer = isQueue ? "#freshfone_queued_calls" : "#freshfone_active_calls";
        $(messageSelector).show();
        $(listContainer).hide();
      }
    },
    onLeave: function(data) {
      this.LiveCallUpdate.leave();
      this.SupervisorCallUpdate.leave();
    }
  };
})(jQuery);