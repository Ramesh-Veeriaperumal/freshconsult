window.App = window.App || {};
(function ($){
  "user strict";
  App.Freshfonecallhistory = {
    onFirstVisit: function (data) {
      this.onVisit(data);
    },
    onVisit: function (data) {
      this.CallLogs.load();
      this.CallBlock.start();
      this.CallFilter.start();
    },
    bindHandlers: function() {

    },
    onLeave: function (data) {
      this.CallLogs.leave();
      this.CallBlock.leave();
      this.CallFilter.leave();
    }
  };
})(jQuery);