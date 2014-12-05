window.App = window.App || {};
window.App.Freshfonecallhistory = window.App.Freshfonecallhistory || {};
(function ($) {
  "use strict";
  window.App.Freshfonecallhistory.CallLogs = {
    load: function () {
      this.initializeElements();
      this.setLocationIfUnknown();
      this.bindCreateTicket();
      this.bindChildCalls();
    },
    initializeElements: function () {
      this.$freshfoneCallHistory = $('.fresfone-call-history');
    },
    setLocationIfUnknown: function () {
      $(".location_unknown").each(function () {
        var country = countryForE164Number("+" + $(this).data('number'));
        $(this).html(country);
      });
    },
    bindChildCalls: function () {
      var self = this;
      this.$freshfoneCallHistory.on('click.freshfonecallhistory.calllogs', '.child_calls',
       function () {
        var parent = $(this).parents('tr'), 
          $currentNumber = App.Freshfonecallhistory.CallFilter.$currentNumber;

        if ($(this).data('fetch') === undefined) {
          $(this).data('fetch', true);
          parent
            .after("<tr rel='loadingtr'><td colspan='8'><div class='loading-box sloading loading-tiny'></div></td></tr>")
            .addClass('transfer_call');
          self.getChildCalls($(this), $currentNumber);
          
        } else {
          var children_class = parent.attr('id');
          parent.toggleClass('transfer_call');
          $('.' + children_class).toggle();
        }
      });
    },
    getChildCalls: function ($element, $currentNumber) {
      $.ajax({
        url: freshfone.CALL_HISTORY_CHILDREN_PATH,
        dataType: "script",
        data: {
          id : $element.data('id'),
          number_id : $currentNumber.val()
        },
        success: function (script) {
          $("[rel='loadingtr']").remove();
        },
        error: function (data) {
          $("[rel='loadingtr']").remove();
          $element.removeData('fetch');
        }
      });
    },
    bindCreateTicket: function () {
      this.$freshfoneCallHistory.on('click.freshfonecallhistory.calllogs', '.create_freshfone_ticket',
       function (ev) {
        ev.preventDefault();
        if (freshfoneendcall === undefined) { return false; }
        freshfoneendcall.id = $(this).data("id");
        freshfoneendcall.inCall = false;
        freshfoneendcall.callerId = $(this).data( "customer-id");
        freshfoneendcall.callerName = $(this).data("customer-name");
        freshfoneendcall.number = "+" + $(this).data("number");
        freshfoneendcall.date = $(this).data("date");
        freshfoneendcall.agent = $(this).data("responder-id");
        freshfoneendcall.showEndCallForm();
      });
    },
    leave: function() {
      $('body').off('.freshfonecallhistory.calllogs');
    }
  };
}(window.jQuery));