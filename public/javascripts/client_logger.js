var ClientLogger
(function ($){
  "use strict";
  ClientLogger = function () {
    this.init();
  };

  ClientLogger.prototype = {
    init: function () {
      if (typeof(Bugsnag) == 'undefined') { return;}
      Bugsnag.user = {
        name: CURRENT_USER.username,
        email: CURRENT_USER.email,
        id: "account_"+CURRENT_USER.account_id
      };
      Bugsnag.notifyReleaseStages = ["development", "staging", "production"];
      Bugsnag.releaseStage = APP_ENV;
    },
    notifier: function (issue, metaData, severity) {
      if (typeof(Bugsnag) == 'undefined') { return;}
      try {
        Bugsnag.refresh();
        Bugsnag.metaData = metaData;
        Bugsnag.notify(issue, Date().toString(),{}, severity || "info");
      } catch (e) {
        console.log('Error in Bugsnag notify '+ e);
      }
    },
    notifyException: function (exception) {
      Bugsnag.notifyException(exception);
    }
  }
}(jQuery));
jQuery(document).ready(function(){
  window.clientLogger = new ClientLogger();
});