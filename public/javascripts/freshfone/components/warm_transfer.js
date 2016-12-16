var FreshfoneWarmTransfer;
(function ($) {
  "use strict";
  FreshfoneWarmTransfer = function (freshfone_call, id) {
    this.freshfone_call = freshfone_call;
    this.targetId = id;
    this.$freshfoneAvailableAgents = $('#freshfone_available_agents');
    this.$ongoingWidget = $('.freshfone_widget').find('.ongoing');
    this.$freshfoneAvailableAgentsList = this.$freshfoneAvailableAgents.find('.available_agents_list');
    this.$freshfoneTransferContainer = $('#freshfone_transfer');
    this.$freshfoneContextContainer = $('.freshfone-context-container');
    this.$ongoingTransfer = this.$ongoingWidget.find('.transfer_call');
    this.$hold = this.$ongoingWidget.find('.hold');
    this.$transferInfo = this.$freshfoneTransferContainer.find('.transfer-info');
  };

  FreshfoneWarmTransfer.prototype = {
    init: function() {
      this.initiateWarmTransfer();
      this.showWidget();
      this.fillTransferDetails();
      this.initiateProgressBar();
      this.handleWarmTransferState();
      this.bindClickEvents();
      this.bindUnload();
    },
    initiateWarmTransfer: function() {
      var self = this;
      $.ajax({
        type: 'POST',
        url: "/freshfone/warm_transfer/initiate",
        data: { "CallSid" : this.freshfone_call.getCallSid(),
                "target": this.targetId,
                "outgoing": this.freshfone_call.isOutgoing()},
      })
       .done(function(data) {
          if (data.status == 'error') {
            self.errorWarmTransfer();
        }})
      .fail(function(){
        self.errorWarmTransfer();
      });
    },
    errorWarmTransfer: function() {
      this.removeTransferringState();
      this.callCompleted('no-answer');
      ffLogger.logIssue("Warm Transfer Failure",{
        'call_sid': this.freshfone_call.getCallSid(), 
        "outgoing": this.freshfone_call.isOutgoing() 
      });
    },
    warmTransferSuccess: function() {
      if (data.status == 'error') {
        self.errorWarmTransfer();
      }
    },
    removeTransferringState: function() {
      this.$transferInfo.toggleClass("transferring_state", false);
      this.$ongoingWidget.toggleClass("tools-disabled", false);
      this.$ongoingTransfer.removeClass("active");
    },
    showWidget: function() {
      this.$freshfoneAvailableAgents.hide();
      this.$freshfoneContextContainer.show();
      this.$freshfoneTransferContainer.show();
    },
    fillTransferDetails: function () {
      var condition, object, template;
      condition = { field: "id", value: this.targetId };
      object = this.getUserTemplateParams(condition);
      
      template = $("#transfer-context-template").clone();
      this.$transferInfo.html(template.tmpl(object));
      
    },
    getUserTemplateParams: function(condition){
      var targetObject, avatar, target, obj;
      targetObject  = freshfonesocket.agentList.get(condition.field, condition.value);
      if (!targetObject) {
        return obj = {
          user_name: condition.value,
          user_hover: "<div class='preview_pic external_number_pic'><i class='ficon-ff-group fsize-16'></i></div>",
          is_receiver: false
        }
      }
      target = targetObject.values();
      avatar = target.available_agents_avatar;
      return obj = {
        user_name: target.available_agents_name,
        user_hover: avatar,
        is_receiver: false
      }
    },
    initiateProgressBar: function() {
      var self = this;
      setTimeout(function() {
        self.$transferInfo.find('.transfer-progress-bar').addClass("progress-bar-active");
      }, 2000);
    },
    handleWarmTransferState: function() {
       this.$transferInfo.toggleClass("transferring_state", true);
       this.$ongoingWidget.toggleClass("tools-disabled", true);
       this.$transferInfo.toggleClass("resume_state", false);
       this.$ongoingTransfer.removeClass("active");
       this.$hold.removeClass("active");
    },
    setStatus: function(status) {
      this.$transferInfo.find('.transfer-status div').hide();
      this.$transferInfo.find('.transfer-status .'+status).show();
      this.$transferInfo.find('.transfer-progress-bar').hide();
      this.busyProgressBar(status);
    },
    busyProgressBar: function(status) {
      if (status == 'busy' || status == 'no-answer') {
        this.$transferInfo.find('.transfer-progress-bar')
                          .toggleClass("progress-bar-active progress-bar-busy")
                          .show();
        this.$transferInfo.addClass("resume_state");
      }
    },
    success: function () {
      var self = this;
      this.bindSuccessElements();
      this.setStatus('connected');
      this.freshfone_call.setIsWarmTransfer('receiver');    
      setTimeout(function(){self.setStatus('in_call');},2000);
    },
    callCompleted: function(status) {
      var self = this;
      this.removeTransferringState();
      this.setStatus(status);
      setTimeout(function() {
        self.$freshfoneTransferContainer.slideUp({duration: 500, easing: "easeInOutQuart"});
      }, 2000);
    },
    bindSuccessElements: function() {
      this.$transferInfo.removeClass("transferring_state");
      this.$ongoingWidget.toggleClass("tools-disabled", false)
                         .addClass("warm_transfer_call");
      this.$freshfoneContextContainer.find('#freshfone_add_notes').hide();
    },
    bindClickEvents: function() {
       var self = this;
      $('#freshfone_transfer_cancel').unbind().on('click.warm_transfer', '.cancel_transfer', function() {    
        self.setStatus('cancelling');
        self.$transferInfo.removeClass("transferring_state");
        self.cancelCall();       
      });
      $('#freshfone_transfer').unbind().on('click.warm_transfer', '.resume_call', function() {
        self.disableResumeWidget();
        self.resumeCall();
        self.loadHold();
        self.closeDesktopNotification();
      });
    },
    disableResumeWidget: function() {
      this.setStatus('resuming');
      this.$transferInfo.removeClass("resume_state");
    },
    loadHold: function() {
      this.$hold.removeClass("active");
      this.$hold.addClass("loading");
      this.freshfone_call.setIsHold(false);
      this.freshfone_call.setIsWarmTransferUnhold(null);
    },
    cancelCall: function() {
      var self = this;
      $.ajax({
          type: 'POST',
          url: '/freshfone/warm_transfer/cancel',
          data: { "CallSid" : self.freshfone_call.getCallSid() }
      })
      .done(function(data){
        if (data.status == 'error') {
            self.cancelError();
          }
      })
      .fail(function(){
        self.cancelError();
      })
    },
    cancelError: function() {
     this.$transferInfo.addClass("transferring_state"); 
     this.setStatus('in_progress');
    },
    resumeCall: function() {
      var self = this;
      this.disableResumeWidget();
      $.ajax({
          type: 'POST',
          url: '/freshfone/warm_transfer/resume',
          data: { "CallSid" : self.freshfone_call.getCallSid() }
      })
      .done(function(data){
        if (data.status == 'error') {
          self.resumeError();
        }
      })
      .fail(function(){
        self.resumeError();
      });
    },
    resumeError: function() {
      this.$transferInfo.addClass("resume_state");
    },
    joinCustomer: function() {
      this.$freshfoneContextContainer.find('#freshfone_add_notes').hide();
    },
    notAvailable: function(status, sid) {
      this.removeTransferringState();
      this.$ongoingTransfer.removeClass("active");
      this.handleHold(sid, 'resume');
      this.setStatus(status);
      this.createDesktopNotification();
    },
    createDesktopNotification: function() {
      if ( this.canCreateDesktopNotification() ) {
        try {
          this.notification = new FreshfoneDesktopNotification(this);
          this.notification.createTransferNotification(this.freshfone_call);
        }
        catch (e) {
          console.log(e);
        }
      }
    },
    canCreateDesktopNotification: function() {
      return freshfonewidget.isSupportWebNotification();
    },
    transfer_revert: function(sid, call_id) {
      this.freshfone_call.setIsWarmTransfer(null);
      this.freshfone_call.setCallId(call_id);
      this.callCompleted('completed');
      this.$ongoingWidget.removeClass("warm_transfer_call");
      this.$freshfoneContextContainer.find('#freshfone_add_notes').show();
      this.handleHold(sid, 'unhold');
    },
    handleHold: function(sid, status) {
      this.$hold.addClass("active");
      this.freshfone_call.registerCall(sid);
      this.freshfone_call.isHold = true;
      this.freshfone_call.setIsWarmTransferUnhold(status);
    },
    call_resume: function() {
      this.$transferInfo.removeClass("resume_state");
      this.callCompleted('resumed');
      this.$hold.removeClass("loading");
      this.freshfone_call.isHold = false;
      this.freshfone_call.setIsWarmTransferUnhold(null);
    },
    closeDesktopNotification: function(){
      if (typeof(this.notification) != "undefined") {
        this.notification.closeWebNotification();
      }
    },
    bindUnload: function() {
      $(window).unload(function(){
        $("#freshfone_transfer").off('.warm_transfer');
        $(document).off('warm_transfer');
      });      
    },
    unhold: function() {
      var self = this;
      $.ajax({
        dataType: "json",
        type: 'POST',
        data: { "CallSid": self.freshfone_call.getCallSid() },
        url: '/freshfone/warm_transfer/unhold'
      })
      .done(function() {
        self.freshfone_call.setIsWarmTransferUnhold(null);
      })
      .fail(function(){
        self.freshfone_call.resetHold();
      });
    },
    // receiver 
    receiverInit: function() {
      this.setOnCallStatus();
      this.showReceiverWidget();
      this.bindUnload();
    },
    setOnCallStatus: function() {
      this.freshfone_call.freshfoneUserInfo.warmTransferInfo();
      this.$transferInfo.find('.transfer-status div').hide();
      this.$transferInfo.find('.transfer-status .receiver-in-call').show();
    },
    showReceiverWidget: function() {
      this.$freshfoneTransferContainer.show();
      this.$ongoingWidget.addClass("warm_transfer_call");
      this.$freshfoneContextContainer.find('#freshfone_add_notes').hide();
    },
    parentCallCompleted: function(sid, call_id) {
      var self = this;
      this.freshfone_call.setIsWarmTransfer(null);
      this.freshfone_call.setCallId(call_id);
      this.freshfone_call.registerCall(sid);
      this.setReceiverStatus();
      this.$ongoingWidget.removeClass("warm_transfer_call");
      this.$freshfoneContextContainer.find('#freshfone_add_notes').show();
      setTimeout(function() {
        self.$freshfoneTransferContainer.slideUp({duration: 500, easing: "easeInOutQuart"});
      }, 2000);
      freshfonewidget.showAddTicketContext();
    },
    setReceiverStatus: function() {
      this.$transferInfo.find('.transfer-status div').hide();
      this.$transferInfo.find('.transfer-status .completed').show();
    }
  }
  $(document).ready(function() {
    var freshfone_socket_event = freshfonesocket.freshfone_socket_channel;
    freshfone_socket_event.on('parent_call_completed', function(data) {
      freshfonecalls.freshfoneWarmTransfer.parentCallCompleted(data.call_sid, data.call_id);
    });
    
    freshfone_socket_event.on('warm_transfer_success', function(data) {
      freshfonecalls.freshfoneWarmTransfer.success();
    });

    freshfone_socket_event.on(' warm_transfer_cancel_failed', function(data) {
      freshfonecalls.freshfoneWarmTransfer.cancelError();
    });

    freshfone_socket_event.on('warm_transfer_reverted', function(data) {
      freshfonecalls.freshfoneWarmTransfer.transfer_revert(data.call_sid, data.call_id);
    });

    freshfone_socket_event.on('warm_transfer_status', function(data) {
      freshfonecalls.freshfoneWarmTransfer.notAvailable(data.call_status, data.call_sid);
    });

    freshfone_socket_event.on('warm_transfer_cancel', function(data) {
      freshfonecalls.freshfoneWarmTransfer.callCompleted('canceled');
    });

    freshfone_socket_event.on('warm_transfer_resume', function(data) {
      freshfonecalls.freshfoneWarmTransfer.call_resume();
    });
  });

}(jQuery));