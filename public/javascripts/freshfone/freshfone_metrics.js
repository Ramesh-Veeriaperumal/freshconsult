window.App = window.App || {};
window.App.Phone = window.App.Phone || {};
(function ($) {
    "use strict";
    App.Phone.Metrics = {
		start: function (eventHash) {
			this.sourceHashKey=[];
			this.sourceHash = eventHash; 			
		},
		push_event: function () {
			if(this.sourceHashKey!== undefined ){
			  $.each(this.sourceHashKey.uniq(),jQuery.proxy(function(index,value)  {
		            if(this.sourceHash[value]!=undefined){
					App.Kissmetrics.push_event(this.sourceHash[value],this.userProperties);
					}	
         		},this));
			  this.resetSourceHashKeys();
			}
		},
		userProperties: function(){
			return {'user_name':freshfone.current_user_details.username,
					'id':freshfone.current_user_details.id,
					'account_id':freshfone.current_user_details.account_id,
					'email':freshfone.current_user_details.email
				    }
		},
		resetSourceHashKeys: function(){
			this.sourceHashKey=[];
		},
		recordSource: function(evCode){
			if(this.sourceHashKey!== undefined ){
				this.sourceHashKey.push(evCode);
			}
		}
		
	};
}(jQuery));