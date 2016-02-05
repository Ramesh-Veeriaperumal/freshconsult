window.App = window.App || {};
window.App.Freshfonedashboard = window.App.Freshfonedashboard || {};
(function($){
  "use strict";
  window.App.Freshfonedashboard.LiveCallUpdate = {
    init: function() {
      this.bindNewQueuedCall();
      this.bindDequeueCall();
      this.bindNewActiveCall();
      this.bindEndActiveCall();
    },
    bindNewQueuedCall: function() {
      var self = this;
      $("body").on('queued_call.freshfone_dashboard', "#freshfone_dashboard_events", function(ev, data){
        self.addToQueueList(data);
        self.updateQueuedCallCount();
        self.toggleQueueList();
        if(freshfonesocket.queuedCalls == 21) {self.sendLimitExceedsNotificaiton('Queue');}
      });
      
    },
    bindDequeueCall: function() {
      var self = this;
      $("body").on('dequeued_call.freshfone_dashboard', "#freshfone_dashboard_events", function(ev, data){
        App.Freshfonedashboard.queuedList.remove('call_id',data.call_details.call_id);
        self.updateQueuedCallCount();
        self.toggleQueueList();
      });
    },
    bindNewActiveCall: function() {
      var self = this;
      $("body").on('new_active_call.freshfone_dashboard', "#freshfone_dashboard_events", function(ev, data){
        self.addToActiveCallsList(data);
        self.updateActiveCallCount();
        self.toggleActiveList();
        if(freshfonesocket.activeCalls == 51) {self.sendLimitExceedsNotificaiton('Active');}
      });
    },
    bindEndActiveCall: function() {
      var self = this;
      $("body").on('active_call_end.freshfone_dashboard', "#freshfone_dashboard_events", function(ev, data){
        App.Freshfonedashboard.activeCallsList.remove('call_id',data.call_details.call_id);
        self.updateActiveCallCount();
        self.toggleActiveList();
        if(freshfoneSupervisorCall.supervisorCallId == data.call_details.call_id){
          freshfonecalls.hangup();
        }
      });
    },
    addToQueueList: function(data) {
      if (typeof data.call_details == 'undefined' ) {return;}
      $("#freshfone_queued_calls").show();
      App.Freshfonedashboard.queuedList.add(this.formatListItems(data));
    },
    formatListItems: function(data, isQueuedCall) {
      var call = data.call_details, self = this;
      isQueuedCall = isQueuedCall || true;
      return {
        'call_id': call.call_id,
        'user_avatar': call.caller_avar, 
        'caller_name': call.caller_name,
        'user_location': call.user_location,
        'agent_user_avatar': call.agent_user_avatar,
        'agent_name': call.agent_group_name,
        'helpdesk_number': call.helpdesk_number,
        'call_direction': self.call_directionDom(call.direction, isQueuedCall),
        'call_created_at': self.timestampDom(call.call_created_at),
        'join_call_btn': self.joinCallBtnDom(call.call_id)
      }
    },
    joinCallBtnDom: function(call_id){
      var dom=[];
      if(freshfone.isCallMonitoringMode){
        var disable = freshfoneSupervisorCall.isSupervisorOnCall ? 'disabled' : '';
        dom= ["<a data-callid='",call_id , "' class='btn call_to_join ", disable ,"'>Join</a>"];
       }
      return dom.join('');
    },
    timestampDom: function(callTimestamp) {
      var formatedDate = moment.unix(callTimestamp).format("dddd, MMM D, h:mm A"), dom;
      dom = ["<abbr data-livestamp='",callTimestamp , "' class='tooltip'title='",
                  formatedDate, "'>", formatedDate, "</abbr>"]
      return dom.join('');
    },
    call_directionDom: function(directionClass, isQueuedCall) {
      var dom = ["<div class='", directionClass, " ff-png-icon vertical-alignment'></div>"];
      return dom.join('');
    },
    updateQueuedCallCount: function() {
      $("#queued_calls-tab .freshfone_queue_call_count").html(freshfonesocket.queuedCalls);
    },
    updateActiveCallCount: function() {
      $("#active_calls-tab .freshfone_active_call_count").html(freshfonesocket.activeCalls);
    },
    addToActiveCallsList: function(data) {
      if (typeof data.call_details == 'undefined' ) {return;}
      App.Freshfonedashboard.activeCallsList.add(this.formatListItems(data, false));
    },
    toggleQueueList: function() {
        $("#freshfone_queued_calls").toggle($("#freshfone_queued_calls .list li").length != 0);
        $(".no_queue_calls").toggle($("#freshfone_queued_calls .list li").length == 0)
    },
    toggleActiveList: function() {
        $("#freshfone_active_calls").toggle($("#freshfone_active_calls .list li").length != 0);
        $(".no_active_calls").toggle($("#freshfone_active_calls .list li").length == 0);
    },
    sendLimitExceedsNotificaiton: function (call_type) {
      $.ajax({
        dataType: "json",
        data: { "call_type": call_type },
        url: '/phone/dashboard/calls_limit_notificaiton',
        error: function () {
          console.log("Unable to notify the limit exceeded waring!!");
        }
      });
    },
   leave: function() {
    $("body").off('.freshfone_dashboard');
   } 
  }
})(window.jQuery);