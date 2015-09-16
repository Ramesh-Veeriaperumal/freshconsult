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
      this.bindFreshfonePlayer();
    },
    bindHandlers: function() {

    },
    bindFreshfonePlayer: function() {
      if ( Fjax.Assets.alreadyLoaded('360player', 'plugins') ) {
        freshfonePlayerSettings();  
      } else {
        Fjax.Assets.plugin('360player');
      }
    },
    onLeave: function (data) {
      this.CallLogs.leave();
      this.CallBlock.leave();
      this.CallFilter.leave();
    }
  };
})(jQuery);