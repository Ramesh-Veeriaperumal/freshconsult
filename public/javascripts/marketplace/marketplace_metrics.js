window.App = window.App || {};
window.App.Marketplace = window.App.Marketplace || {};
(function ($) {
    "use strict";
    App.Marketplace.Metrics = {
    recordIdentity: function(){
      if(typeof (_kmq) != 'undefined' ){
        _kmq.push(['identify', mktplace_domain]);
      }
    },
    push_event: function (event,property) {
      if(typeof (_kmq) != 'undefined' ){
        this.recordIdentity();
          _kmq.push(['record',event,property]); 
      }
    }
  };
}(jQuery));