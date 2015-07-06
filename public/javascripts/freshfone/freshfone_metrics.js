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
			this.order_type="";	
			this.order_sort_type="";	
			this.convertedToTicket=false;	
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
					'email':freshfone.current_user_details.email,
					'role': freshfone.isAdmin ? "Admin" : "Normal User"

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
		setConvertedToTicket: function(){
			this.convertedToTicket=true;
		},
		resetConvertedToTicket: function(){
			this.convertedToTicket=false;
		},
		isIncoming : function() {
			return this.direction == "incoming";
		},

		eventsTriggered: function(){
			var self=this;
			$('.call_notes').keypress(function(ev){
				var during_call= self.isIncoming() ? "IN_NOTES_ON_CALL" : "OUT_NOTES_ON_CALL";
					self.recordSource(during_call);
				
			});
			$('.final_call_notes').keypress(function(ev){
				if(!self.convertedToTicket){
					self.resetSourceHashKeys();
					if( $('.call_notes').val() != ""){
						var during_after_call= self.isIncoming() ? "IN_NOTES_ALL" : "OUT_NOTES_ALL";
						self.recordSource(during_after_call);
					}
					else{
						var after_call= self.isIncoming() ? "IN_NOTES_AFTER_CALL" : "OUT_NOTES_AFTER_CALL";
						self.recordSource(after_call);
					}
				}	
			});
			
			$(".call-history-metrics , .reports-metrics").on("click",function(ev){
				if(ev.hasOwnProperty('originalEvent')){
					if($(this).hasClass("call-history-metrics")){
						self.recordSource("CALL_HISTORY_EDIT");
						self.push_event();
					}
					if($(this).hasClass("reports-metrics")){
						self.recordSource("REPORTS_EDIT");
						self.push_event();
					}
				}
			});

			$("#export_as_csv").on("click",function(){
					self.recordSource("REPORTS_CSV");
					self.push_event();
			});

			$(document).on("click",".sm2-360btn",function(ev){ 
    		if(jQuery(this).parent().hasClass("sm2_playing")){
    			App.Phone.Metrics.recordSource("RECORDING");
    			App.Phone.Metrics.push_event();
    		}
    	});

    	$(document).on("saveticket", function (ev, data) {
    			if(self.convertedToTicket){
						self.recordSource("CALL_TO_TICKET");
						self.push_event(); 
					}
    	});

		},

		recordDateState: function(index,name_space){
			switch(index){
					case 0:
						App.Phone.Metrics.recordSource(name_space+"_DATE_TODAY");
					  break;
					case 1:
						App.Phone.Metrics.recordSource(name_space+"_DATE_YESTERDAY");
					  break;
					case 2:
						App.Phone.Metrics.recordSource(name_space+"_DATE_7DAYS");
					  break;
					case 3:
						App.Phone.Metrics.recordSource(name_space+"_DATE_30DAYS");
					  break;
			}
			if(name_space=="callhistory"){
				if(index==4){
					App.Phone.Metrics.recordSource(name_space+"_DATE_RANGE");
				}
			}
			if(name_space=="reports"){
				if(index==4){
					App.Phone.Metrics.recordSource(name_space+"_DATE_90DAYS");
				}
				if(index==5){
					App.Phone.Metrics.recordSource(name_space+"_DATE_RANGE");
				}
			}

		},

		recordCallHistoryFilterState: function(){
			var numberState= $("#ff_number").select2("data").id==0? "CALL_HISTORY_ALL_NUMBER" : "CALL_HISTORY_SINGLE_NUMBER";
			this.recordSource(numberState);
			
			var callTypeState = $("#ff_call_status").data("value")=="All Calls"? "AllCalls" : "callhistory"+$("#ff_call_status").data("value");
			this.recordSource(callTypeState);
			
			var agentState = $(".call-history-metric :selected").text()==""? "ALL_AGENTS" : "PARTICULAR_AGENT";						
			this.recordSource(agentState);
			
			var callerNameState = $("#callerName_choices").data("value")==""? "ALL_CALLERS" : "SINGLE_CALLER";
			this.recordSource(callerNameState);
			
			var groupNameState = $(".groupName").select2("data")==null ? "CALL_HISTORY_ALL_GROUPS" : "CALL_HISTORY_SINGLE_GROUP";
			this.recordSource(groupNameState);
			
			this.recordDateState($(".ui-widget-content li.ui-state-active").index(),"callhistory");

			this.push_event();
		},

		recordReportsFilterState: function(){
			var numberState = $("#freshfone_number").select2("data").id==0? "REPORTS_ALL_NUMBER" : "REPORTS_SINGLE_NUMBER";
			this.recordSource(numberState);
			
			var groupNameState = $("#group_id").select2("data")==null? "REPORTS_ALL_GROUPS" : "REPORTS_SINGLE_GROUP";
			this.recordSource(groupNameState);
			
			var callTypeState = "reports"+$(".report-metric :selected").text(); 
			this.recordSource(callTypeState);
			
			this.recordDateState($(".ui-widget-content li.ui-state-active").index(),"reports");

			this.push_event();

		}
		
	};
}(jQuery));