window.App = window.App || {};
window.App.Phone = window.App.Phone || {};
(function ($) {
    "use strict";
    App.Phone.Metrics = {
		start: function (eventHash) {
			this.eventsTriggered();
			this.sourceHashKey=[];
			this.sourceHash = eventHash;
			this.direction = undefined;			
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
		},
		setCallDirection: function(value){
			this.direction = value;
		},
		resetCallDirection: function(){
			this.direction = null;
		},
		eventsTriggered: function(){
			var self=this;
			$('.call_notes').keypress(function(ev){
				var mini_notes= self.isIncoming() ? "IN_NOTES_ON_CALL" : "OUT_NOTES_ON_CALL";
					self.recordSource(mini_notes);
			});
			$('.final_call_notes').keypress(function(ev){
				self.resetSourceHashKeys();
				if( $('.call_notes').val() != ""){
					var common_notes= self.isIncoming() ? "IN_NOTES_ALL" : "OUT_NOTES_ALL";
					self.recordSource(common_notes);
				}
				else{
					var end_call_form_notes= self.isIncoming() ? "IN_NOTES_AFTER_CALL" : "OUT_NOTES_AFTER_CALL";
					self.recordSource(end_call_form_notes);
				}
			});
		},
		isIncoming : function() {
			return this.direction == "incoming";
		}
		
	};
}(jQuery));