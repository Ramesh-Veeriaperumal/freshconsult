var FreshfoneCallTransfer
(function ($) {
  "use strict";
  FreshfoneCallTransfer = function (freshfone_call, id, group_id, external_number) {
    this.freshfone_call = freshfone_call;
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
      if (!this.freshfone_call.tConn || isNaN(id)) { return false; }
      this.$transferList.hide();
      this.$transferAgent.show();
        ffLogger.log({
            'action': "Call Transfere initiate", 
            'params': this.freshfone_call.tConn.parameters
          });
      $.ajax({
        type: 'POST',
        dataType: "json",
        url: '/freshfone/call_transfer/initiate',
        data: { "call_sid": this.freshfone_call.getCallSid(),
                "id": id,
                "group_id": group_id,
                "external_number": external_number,
                "outgoing": this.freshfone_call.isOutgoing() },
        error: function () {
          self.freshfone_call.transfered = false;
          freshfonewidget.resetTransferMenuList();
          freshfonewidget.toggleWidgetInactive(false);
          self.$transferList.show();
          ffLogger.logIssue("Call Transfer Failure",{
            'call_sid': this.freshfone_call.getCallSid(), 
            "outgoing": this.freshfone_call.isOutgoing() 
          });
        },
        success: function () {
           $(".transfer_call").trigger("click");
          self.$transferList.show();
          freshfonewidget.toggleWidgetInactive(true);
          freshfonewidget.resetTransferMenuList();
        }
      });
    },

    $transferAgent: $('#freshfone_available_agents .transfering_call'),
    $transferList: $('#freshfone_available_agents .transfer-call-header'),

    transferSuccessFlash: function () {
      if (!this.freshfone_call.transfered) { return false; }
      $("#noticeajax").html("<div>Call transfered successfully.</div>").show();
      closeableFlash('#noticeajax');
    },

    successTransferCall: function (transfer_success) {
      if (transfer_success == 'true') { this.transferSuccessFlash(); }
      freshfoneuser.resetStatusAfterCall();
      freshfoneuser.updatePresence();
      freshfonewidget.resetToDefaultState();
    }
  } 
}(jQuery));