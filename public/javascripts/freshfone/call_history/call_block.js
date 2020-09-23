window.App = window.App || {};
window.App.Freshfonecallhistory = window.App.Freshfonecallhistory || {};
(function ($) {
  "use strict";
  window.App.Freshfonecallhistory.CallBlock = { 
    start: function () {
      this.$add_to_blacklist = $('.add_to_blacklist');
      this.$freshfoneCallHistory = $('.fresfone-call-history');
      this.bindBlacklistElements();
    },
    blockNumber: function (id) {
      this.$freshfoneCallHistory.find('.blacklist[data-caller_id="' + id + '"]')
        .removeClass('blacklist')
        .addClass('blacklisted')
        .attr('title', freshfone.unblockNumberText);
    },

    bindBlacklistElements: function () {
      this.bindBlockButton();
      this.bindUnblockButton();
    },
    bindBlockButton: function () {
      var self = this;
      this.$freshfoneCallHistory.on('click.freshfonecallhistory.callblacklist', '.blacklist',
       function (ev) {
        $('#open-blacklist-confirmation').trigger('click');
        $(this).addClass('disabled');
        $('#blacklist-confirmation .number')
          .text($(this).data('number'));
        $('#caller_number').val($(this).data('number'));
        $('#caller_id').val($(this).data('caller_id'));
      });
    },
    bindUnblockButton: function () {
      var self = this;
      this.$freshfoneCallHistory.on('click.freshfonecallhistory.callblacklist', '.blacklisted',
       function (ev) {
        var number = $(this).data('number'),
        caller_id = $(this).data('caller_id');
        self.$freshfoneCallHistory.find('.blacklisted[data-number="' + number + '"]')
          .removeClass('blacklisted')
          .addClass('blacklisting sloading loading-tiny');
        $.ajax({
          url: '/freshfone/caller/unblock',
          data: { caller : {id : caller_id} },
          type: 'post',
          async: true,
          success: function (data) {self.unblockSuccess(data, number)},
          error: function (data) {self.unblockError(data, number)}
        });
      });
    },
    unblockSuccess: function (data, number) {
      this.$freshfoneCallHistory
        .find('.blacklist-toggle.blacklisting[data-number="' + number + '"]')
        .addClass('blacklist')
        .removeClass('sloading loading-tiny blacklisting')
        .attr('title', freshfone.blockNumberText);
    },
    unblockError:  function (data, number) {
      this.$freshfoneCallHistory
        .find('.blacklist[data-number="' + number + '"]')
        .addClass('blacklisted')
        .removeClass('blacklist')
        .removeClass('sloading loading-tiny');
    },
    leave: function () {
      $('body').off('.freshfonecallhistory.callblacklist');
    }
  };
}(window.jQuery));