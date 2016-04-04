window.App = window.App || {};
window.App.Report = window.App.Report || {};
(function ($) {
    "use strict";
    App.Report.Metrics = {
		recordIdentity: function(){
			if(typeof (_kmq) != 'undefined' ){
				_kmq.push(['identify', full_domain]);
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