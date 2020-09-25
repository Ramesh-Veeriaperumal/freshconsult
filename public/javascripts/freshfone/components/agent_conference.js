var FreshfoneAgentConference;
(function ($) {
  "use strict";
  FreshfoneAgentConference = function (freshfone_call, id) {
    this.freshfone_call = freshfone_call;
    this.$freshfoneAvailableAgents = $('#freshfone_available_agents');
    this.$freshfoneAddAgentContainer = $('#freshfone_add_agent');
    this.$ongoingTransfer = $(".ongoing .transfer_call");
    this.$freshfoneTransferContainer = $('#freshfone_transfer');
    this.$addAgentInfo = this.$freshfoneAddAgentContainer.find('.add-agent-info');
    this.$freshfoneAvailableAgentsList = this.$freshfoneAvailableAgents.find('.available_agents_list');
    this.$freshfoneContextContainer = $('.freshfone-context-container');
    this.init(id);
  };

  FreshfoneAgentConference.prototype = {
    init: function(id) {
      this.handleAddingAgentState();
      this.showWidgets();
      this.initiateProgressBar();
      this.bindCancel();
      this.fillAddAgentDetails(id);
      this.addAgentRequest(id);
      this.bindSocketEvents();
      this.bindUnload();
    },
    addAgentRequest: function(id) {
      var self = this;
      $.ajax({
        type: 'POST',
        url: "/freshfone/agent_conference/add_agent",
        data: { "call" : this.freshfone_call.callId,
                "target"  : id },
        error: function () {
          self.errorAddAgent();
        },
        success: function (data) {
          if (data.status == 'error') {
            self.errorAddAgent();
          }
        }
      });
    },
    handleAddingAgentState: function() {
      this.setAddingAgentState(true);
      this.$ongoingTransfer.removeClass("active")
                           .addClass("transfer-disabled")
                           .attr('title', freshfone.add_or_transfer_call);
    },
    showWidgets: function() {
      this.$freshfoneAvailableAgents.hide();
      this.$freshfoneContextContainer.show();
      this.$freshfoneAddAgentContainer.show();
      this.$freshfoneTransferContainer.hide();
    },
    errorAddAgent: function() {
      this.removeAddingAgentState();
      this.callCompleted('no-answer');
      ffLogger.logIssue("Add Agent Failure",{
        'call_sid': this.freshfone_call.getCallSid(), 
        "outgoing": this.freshfone_call.isOutgoing() 
      });
    },
    removeAddingAgentState: function() {
      this.$ongoingTransfer.removeClass("transfer-disabled");
      this.setAddingAgentState(false);
    },
    fillAddAgentDetails: function (user_id) {
      var condition, object, template;
      condition = {field: "id", value: user_id };
      object = this.getUserTemplateParams(condition);
      
      template = $("#add-agent-info-template").clone();
      this.$addAgentInfo.html(template.tmpl(object));
      
    },
    getUserTemplateParams: function(condition){
      var targetObject, avatar, target, obj;
      targetObject  = freshfonesocket.agentList.get(condition.field, condition.value);
      if (targetObject != null) {
        target = targetObject.values();
        avatar = target.available_agents_avatar;
        obj = {
          user_name: target.available_agents_name,
          user_hover: avatar,
          is_receiver: this.freshfone_call.isAgentConference
        }
      }
      return obj;
    },
    initiateProgressBar: function() {
      var self = this;
      setTimeout(function() {
        self.$addAgentInfo.find('.add-agent-progress-bar').addClass("progress-bar-active");
      }, 2000);
    },
    setStatus: function(status) {
      this.$addAgentInfo.find('.add-agent-status div').hide();
      this.$addAgentInfo.find('.add-agent-status .'+status).show();
      this.$addAgentInfo.find('.add-agent-progress-bar').hide();
      this.busyProgressBar(status);
    },
    busyProgressBar: function(status) {
      if (status == 'busy' || status == 'no-answer') {
        this.$addAgentInfo.find('.add-agent-progress-bar')
                          .toggleClass("progress-bar-active progress-bar-busy")
                          .show();
      }
    },
    success: function () {
      var self = this;
      freshfonecalls.isAgentConferenceActive = true;
      this.unbindCancel();
      this.setStatus('connected');    
      setTimeout(function(){self.setStatus('in_call');},2000);
    },
    callCompleted: function(status) {
      var self = this;
      freshfonecalls.isAgentConferenceActive = false;
      this.setStatus(status);   
      this.unbindCancel();
      setTimeout(function() {
        self.$freshfoneAddAgentContainer.slideUp({duration: 500, easing: "easeInOutQuart"});
        self.$freshfoneAvailableAgentsList.toggleClass("adding_agent_state", false); 
        self.$ongoingTransfer.removeClass("active");
      }, 2000);
    },
    unbindCancel: function() {
      this.$addAgentInfo.toggleClass("adding_agent_state", false);
      this.$ongoingTransfer.removeClass("transfer-disabled");
    },
    cancelError: function() {
      this.setStatus('in_progress');
      this.$addAgentInfo.toggleClass("adding_agent_state", true);
    },
    bindCancel: function() {
       var self = this;
      $("#freshfone_add_agent").off('.add_agent');
      $("#freshfone_add_agent").on('click.add_agent', '.cancel_add_agent', function() {    
        self.setStatus('cancelling');
        self.$addAgentInfo.toggleClass("adding_agent_state", false);                                  
        self.cancelCall();       
      });
    },
    bindUnload: function() {
      $(window).on('unload', function(){
        $("#freshfone_add_agent").off('.add_agent');
        $(document).off('agent_conference');
      });      
    },
    setAddingAgentState: function(state) {
      this.$freshfoneAvailableAgentsList.toggleClass("adding_agent_state", state);
      this.$addAgentInfo.toggleClass("adding_agent_state", state);
    },
    cancelCall: function() {
      var self = this;
      $.ajax({
          type: 'POST',
          url: '/freshfone/agent_conference/cancel',
          data: { "call" : this.freshfone_call.callId },
          error: function () {
            self.cancelError();
          },
          success: function (data) {
            if (data.status == 'error') {
              self.cancelError();
              return;
            }
          }
      });
    },
    bindSocketEvents: function() {
      var self = this;
      $(document).on('agent_conference', function(ev, data){
        switch(data.event){
          case "success":
            self.success();
            break;
          case "unanswered":
            self.errorAddAgent();
            break;
          case "complete":
            self.callCompleted(data.status);
            break;
          case "connecting":
            self.cancelError();
            break;
        }
      });
    }
  };
}(jQuery));