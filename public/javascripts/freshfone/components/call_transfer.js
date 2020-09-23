var FreshfoneCallTransfer
(function ($) {
  "use strict";
  FreshfoneCallTransfer = function (freshfone_call, id, group_id, external_number) {
    this.freshfone_call = freshfone_call;
    this.$transferAgent = $('#freshfone_available_agents .transferring_call');
    this.$failedTransferWidget = $("#freshfone_available_agents .transfer_failed");
    this.init(id, group_id, external_number);
  }; 

  FreshfoneCallTransfer.prototype = {
    init: function (id, group_id, external_number) {
      var self = this;
      id = parseInt(id, 10);
      if (group_id) {
        group_id = parseInt(group_id, 10);
      }
      if (external_number) {
        external_number = encodeURIComponent("+"+parseInt(external_number, 10));//Adding + to number temp:TODO
      }
      this.resumed = false;
      this.cancelled = false;
      this.cleanUpTimer();
      this.$transferList.hide();
      $('#freshfone_transfer').hide();
      this.showTransferDetails(id, group_id, external_number);
      this.disableAllOtherControlles();
      var ringingTime = (freshfone.ringingTime || 30 )* 1000; // sec to milisec 
      this.initiateProgressBar(ringingTime, "286px");
      this.freshfone_call.transferSuccess = false;// this is set to true on receive transfer success event.
      if (!this.freshfone_call.tConn || isNaN(id)) { return false; }
        ffLogger.log({
            'action': "Call Transfere initiate", 
            'params': this.freshfone_call.tConn.parameters
          });

      // this.bindWarmTransferButton();
      
      $.ajax({
        type: 'GET',
        dataType: "json",
        url: self.transferURL(),
        data: { "CallSid": this.freshfone_call.getCallSid(),
                "target": id,
                "group_id": group_id,
                "external_number": external_number,
                "outgoing": this.freshfone_call.isOutgoing(),
                "type": this.getTransferType() },
        error: function () {
          self.errorTransfer();
        },
        success: function (data) {
          if((freshfone.isConferenceMode && data.status == 'error') || data.call == 'failure')
            return self.errorTransfer();
          self.freshfone_call.transfered = true;
          var ringingTime = (freshfone.ringingTime || 30 )* 1000; // sec to milisec 
          self.resumeFallback = setTimeout(function(){ 
            self.enableResume();
          }, ringingTime+(5000)); //adding 5 secs for fallback timeout
        }
      });
    },
    enableResume: function(){
      if(freshfonecalls.tConn && !this.resumed){
        console.log('Inside Resume Fallback Timer');
        this.enableTransferResume(); 
      }
    },
    $transferAgent: $('#freshfone_available_agents .transferring_call'),
    $transferList: $('#freshfone_available_agents .transfer-call-header'),

    disconnectAgent: function(call_sid){//used for disconnecting the source agent.
       $.ajax({
        type: 'GET',
        dataType: "json",
        url: '/freshfone/conference_transfer/disconnect_agent',
        data: { "CallSid": call_sid },
        success: function(data){
          if(data.status == "error"){
            if(freshfonecalls.tConn){
              freshfonecalls.tConn.disconnect();
            }
          }
        },
        error: function(data){
          if(freshfonecalls.tConn){
            freshfonecalls.tConn.disconnect();
          }
        }
      });
    },

    successTransferCall: function (transfer_success) {
      if (transfer_success == 'true') { 
        freshfonewidget.closeRecentTickets();
        freshfonewidget.closeNotesTextArea();
        if(this.resumeFallback){
          clearTimeout(this.resumeFallback);
        }
        freshfonecalls.transferSuccess = true;
        freshfonecalls.transfered = false;
        freshfoneuser.resetStatusAfterCall();
        freshfoneuser.updatePresence();
        setTimeout(function(){ freshfonewidget.resetToDefaultState();}, 3000);
        this.updateTransferStatus("connected","close");
        this.restoreAllControlles();
        $(".ongoing .transfer_call").removeClass("transferring_state");
      } else {
        if (!freshfone.isConferenceMode) {
          this.resetTransferState();
          freshfonewidget.resetToDefaultState();
        }
      }
    },

    transferURL: function () {
      return freshfone.isConferenceMode  ? 
              "/freshfone/conference_transfer/initiate_transfer" : "/freshfone/call_transfer/initiate"
    },
    getTransferType: function () {
      return "normal";
    },
    isWarmTransfer: function () {
      return $("#transfer_type_true").is(":checked");
    },
    bindWarmTransferButton: function () {
      var self = this;
      $("#completeWarmTransfer").on('click', function(){
        self.completeWarmTransfer();
        self.successTransferCall();
      });
    },
    completeWarmTransfer: function () {
      var self = this;
      $.ajax({
        dataType: "json",
        data: { "CallSid": self.freshfone_call.call },
        url: '/freshfone/conference_transfer/complete_transfer',
        success: function(data) {
          self.transferResponseFlash("Warm Call transfer was successful!");
        },
        failure: function (data) {
          self.transferResponseFlash("Warm Call transfer failed!");
        }
      });
    },
    showTransferDetails: function (user_id, group_id, external_number) {
      this.fillTransferDetails(user_id, group_id, external_number);
      $('#freshfone_available_agents .agent_list').hide();
      $(".ongoing .transfer_call").addClass("transferring_state");
      this.$failedTransferWidget.hide();
      this.disableAllOtherControlles();
      this.$transferAgent.show();
    },
    fillTransferDetails: function (user_id, group_id, external_number) {
      var condition, obj, temp;
      if (external_number) { 
        obj = this.getNumberTemplateParams(external_number) ;
      } else {
        condition = (user_id==0) ? {field: "group_id", value: group_id } :  {field: "id", value: user_id };
        obj = this.getUserTemplateParams(condition);
      }
      temp = $("#transfer-info-template").clone();
      this.$transferAgent.html(temp.tmpl(obj));
      this.bindTransferAcion("cancel");
    },
    getUserTemplateParams: function(condition){
      var targetObject, avatar, target, obj;
      targetObject  = freshfonesocket.agentList.get(condition.field, condition.value);
      if (targetObject != null) {
        target = targetObject.values();
        avatar = target.available_agents_avatar;
        obj = {
          name: target.available_agents_name,
          agentsCount: target.agents_count,
          avatar: this.getAvatar(avatar)
        }
      }
      return obj;
    },
    getAvatar: function(avatar) {
      if (avatar.indexOf("small") >= 0) {
        return avatar.replace("small","thumb");
      }
      var length =  avatar.indexOf("preview_pic") + 11;
      var image_div = avatar.slice(0,length) + " thumb" + avatar.slice(length);
      return image_div;
    },
    getNumberTemplateParams: function (number) {
      var params = {
        name: decodeURIComponent(number),
        avatar: "<div class='external_no preview_pic'><i class='ficon-ff-group fsize-30 ff-icon'></i></div>"
      }
      return params;
    },
    showReconnectWidget: function () {
      //This method will be called from node when no agents pick the tranfered call
      this.$transferAgent.hide();
      this.$failedTransferWidget.show();
      this.restoreAllControlles(); // should be reset the widget once reconnected to caller
    },
    disableAllOtherControlles: function () {
      var self = this;
      $(document).on('click', self.bindClickEventForTransfer);
      freshfonewidget.ongoingControl().addClass('disabled inactive');
    },
    bindClickEventForTransfer: function(){
      $('.freshfone_content_container').show();
      $('#freshfone_available_agents').show();
      $('.freshfone-context-container').hide();
    },
    restoreAllControlles: function () {
      var self = this;
      $(document).off('click', self.bindClickEventForTransfer);
      freshfonewidget.ongoingControl().removeClass('disabled inactive');
    },
    bindAbortTransfer: function () {
      var self = this;
      $("#transfer-action-cancel").bind('click', function () {
        // Method to handle abort the transfer process
        self.restoreAllControlles(); // should be reset the widget once reconnected to caller
      })
    },
    initiateProgressBar: function (time, width) {
      $(".transfer-progress-bar").css("transition", "all "+time+"ms ease");
      setTimeout(function(){ $(".transfer-progress-bar").css("width", width);}, 1000);
    },
    updateTransferStatus: function (status, action) { // This method should invoke from socket transfer event
      $(".transfer-status div").hide();
      $('.transfer-status .'+status).show();
      $(".transfer-action").hide();
      $("#transfer-action-"+action).show();
      $(".transfer-progress-bar").hide();
      this.bindTransferAcion(action);
    }, 
    bindTransferAcion: function (action) {
      var self = this;
      $("#transfer-action-"+action).off("click");
      $("#transfer-action-"+action).on("click", function(){
        if(action =='close') { self.handleEndAction(); return; }
        if(action === 'resume') {
          self.closeDesktopNotification();
          self.resumed = true;
          clearTimeout(self.resumeTimeout);
        }
        self.toggleActionButtonText(action);
        $.ajax({
          type: 'POST',
          dataType: "json",
          data: {
           "CallSid": self.freshfone_call.getCallSid(),
           "outgoing": self.freshfone_call.isOutgoing()
         },
          url: "/freshfone/conference_transfer/"+action+"_transfer",
          success: function (data) {
            if(data.status == 'error'){
              self.toggleActionButtonText(action);  
            } else {
              if(action == 'cancel' || action == 'resume'){ 
              self.freshfone_call.isHold = 0;
              self.freshfone_call.resetHoldUI();
              clearTimeout(self.resumeFallback); 
              }
              if(action == 'cancel'){ self.cancelled = true ; }
            }
          },
          error: function (data) {
            self.toggleActionButtonText(action);
          }
        });
      });
    },
    handleEndAction: function() {
      $('.ongoing .end_call').trigger('click');
    },
    resetTransferState: function() {
      this.freshfone_call.transfered = false;
      this.restoreAllControlles();
      freshfonewidget.hideTransfer();
      $(".ongoing .transfer_call").removeClass("transferring_state");
      freshfonewidget.resetTransferMenuList();
    },
    toggleActionButtonText: function(action){
      var $action = $("#transfer-action-"+action);
        var text = $action.data('toggletext');
      $action.data('toggletext', $action.text());
      $action.text(text);
      $action.hasClass('disabled') ? $action.removeClass('disabled') : $action.addClass('disabled');
    },
    enableTransferResume: function() {
      if(this.cancelled){ return ; }
      var self = this;
      this.updateTransferStatus("no_answer","resume");
      $(".transfer-progress-bar").show();
      var ringingTime = (freshfone.ringingTime || 30 )* 1000; // sec to milisec 
      this.initiateProgressBar(ringingTime, "286px");
      if(this.resumeFallback){
        clearTimeout(this.resumeFallback);
      }
      this.resumeTimeout = setTimeout(function(){ 
          if(freshfonecalls.tConn && !self.resumed){
            console.log('Inside Resume Timer');
            self.resetTransferState(); 
            self.handleEndAction();
          }
        }, ringingTime);
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
    closeDesktopNotification: function(){
      if (typeof(this.notification) != "undefined") {
        this.notification.closeWebNotification();
      }
    },
    cleanUpTimer: function() {
      clearTimeout(this.resumeFallback);
      clearTimeout(this.resumeTimeout);
      this.resumeFallback = undefined;
      this.resumeTimeout = undefined;
    },
    errorTransfer: function(){
      this.resetTransferState();
      freshfonewidget.toggleWidgetInactive(false);
      this.$transferList.show();
      // self.transferResponseFlash("Call transfer was failed!");
      ffLogger.logIssue("Call Transfer Failure",{
        'call_sid': this.freshfone_call.getCallSid(), 
        "outgoing": this.freshfone_call.isOutgoing() 
      });
      //this.disableAllOtherControlles();
    }

  }; 
}(jQuery));