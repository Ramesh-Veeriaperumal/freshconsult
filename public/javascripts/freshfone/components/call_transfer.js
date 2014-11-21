var FreshfoneCallTransfer
(function ($) {
  "use strict";
  FreshfoneCallTransfer = function (freshfone_call, id) {
    this.freshfone_call = freshfone_call;
    this.init(id);
  }; 

  FreshfoneCallTransfer.prototype = {
    init: function (id) {
      var self = this;
      id = parseInt(id, 10);
      if (!this.freshfone_call.tConn || isNaN(id)) { return false; }
      this.$transferAgent.show();

      $.ajax({
        type: 'POST',
        dataType: "json",
        url: '/freshfone/call_transfer/initiate',
        data: { "call_sid": this.freshfone_call.getCallSid(),
                "id": id,
                "outgoing": this.freshfone_call.isOutgoing() },
        error: function () { self.freshfone_call.transfered = false; freshfonewidget.toggleWidgetInactive(false);},
        success: function () {
           $(".transfer_call").trigger("click");
          freshfonewidget.toggleWidgetInactive(true);
        }
      });
    },

    $transferAgent: $('#freshfone_available_agents .transfering_call'),

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