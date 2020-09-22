window.App = window.App || {};
(function ($) {
    "use strict";
	App.Kissmetrics = {
		push_event: function (event,property) {
			if(typeof (_kmq) !== 'undefined' ){
				this.recordIdentity();
    			_kmq.push(['record',event,property]);	
			}
			
		},
		getIdentity: function(){
			return freshfone.full_domain;
		},
		recordIdentity: function(){
			if(typeof (_kmq) !== 'undefined' ){
				_kmq.push(['identify', this.getIdentity()]);
			}
		},
		kissMetricTrackingCode: function(api_key){
				var _kmq = _kmq || [];
				var _kmk = _kmk || api_key;
				function _kms(u){
				  setTimeout(function(){
				    var d = document, f = d.getElementsByTagName('script')[0],
				    s = d.createElement('script');
				    s.type = 'text/javascript'; s.async = true;
				    s.onload = function() {
						trigger_event("script_loaded",{});
					};
				    s.src = u;
				    f.parentNode.insertBefore(s, f);
				  }, 1);
				}
				_kms('//i.kissmetrics.com/i.js');
				_kms('//scripts.kissmetrics.com/' + _kmk + '.2.js');
				

		}
	};
}(jQuery));

