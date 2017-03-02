window.App = window.App || {};

(function($) {

	App.Sentiment = {
		CONST : {
			timeout : 4000
		},
		feedback : {
			insert_markup : function() {

				var _this = this;
			    var sentiment_tmpl = JST["app/template/sentiment_feedback_template"]({
	            	'data': 'data'
	        	});

	        	var customer_msges = jQuery('div[rel="customer_msg"]');

			    if(jQuery('.cmi-plugin').length == 0){
				    if(sentiment.last_note.note_id == undefined){
				    	var desc_box = customer_msges[0];
				    	predicted_sentiment = sentiment.ticket_sentiment;

				    	if(predicted_sentiment != undefined){
				    		jQuery(sentiment_tmpl).appendTo(desc_box);
				    		_this.show_sentiment();	
				    	}
				    }
				    else{
				    	if ( jQuery('#helpdesk_note_'+sentiment.last_note.note_id).length > 0 ){

									var note_box = jQuery('#helpdesk_note_'+sentiment.last_note.note_id+' .commentbox')[0];
									predicted_sentiment = sentiment.last_note.note_sentiment;

									if(predicted_sentiment != undefined){
										jQuery(sentiment_tmpl).appendTo(note_box);
										_this.show_sentiment();
									}
						}
				    }
				}
			},
			show_sentiment : function() {
				console.log("In show sentiment");
				var _this = this;
				
				last_note_sentiment = _this.get_sentiment_from_num(predicted_sentiment);
				sentiment_title = _this.get_sentiment_title_from_num(predicted_sentiment);

				m = jQuery('.cmi-plugin .'+last_note_sentiment);
				m.closest('li').addClass('selected');

				jQuery('.cmi-fdbk span').html("Not "+sentiment_title+"? Click to change.");
				
			},
			change_sentiment : function(evt){
				var _this = this;
				var target = evt.target;

				var changed_senti = target.closest('a').classList[1];

				//change immediate parent sentiment temp fix
				var kk = jQuery('.sentiment').last()[0];

				kk.removeClassName(kk.classList[kk.classList.length-1]);
				kk.removeClassName(kk.classList[kk.classList.length-1]);
				kk.addClassName(_this.get_sentiment_num(changed_senti));
				kk.addClassName(_this.get_sentiment_class(_this.get_sentiment_num(changed_senti)));

				kk.setAttribute("data-original-title",_this.get_sentiment_title_from_num(_this.get_sentiment_num(changed_senti)))

				var m1 = jQuery('.cmi-plugin .note_mood');
				m1.closest('li').removeClass('selected');

				var m = jQuery('.cmi-plugin .'+changed_senti);
				m.closest('li').addClass('selected');

				jQuery('.cmi-fdbk span').html("Successfully changed!");

				this.post_feedback(changed_senti);

				if(sentiment.last_note.note_id == undefined){
					this.update_ticket_sentiment(changed_senti);
				} else {
					this.update_note_sentiment(changed_senti);
				}
			},
			post_feedback : function(changed_senti) {

				var self = this;
				jQuery.ajax(self.get_params(changed_senti));
			},
			get_params : function(changed_senti) {
				var _this = this;
				var ticket_id = sentiment.ticket_id;
				var userInfo = jQuery('#LoggedOptions');
				var author = jQuery(userInfo).find('span')[0].textContent;
				var note_id = sentiment.last_note.note_id;
				if(note_id == undefined){note_id=0;}

				var json_data = {
					"data": {
						"account_id": window.current_account_id,
						"ticket_id": ticket_id,
						"note_id": note_id,
						"predicted_value": _this.get_sentiment_num(last_note_sentiment),
						"feedback": _this.get_sentiment_num(changed_senti),
						"user_id": window.current_user_id
					}
				}
				console.log(json_data);
				var xhr_req = {
						url: "/helpdesk/tickets/sentiment_feedback",
			            type: 'POST',
			            dataType: 'json',
			            data: json_data,
			            success: function (data) {
			                console.log("Success: "+data);
			            },
			            error: function (data) {
			                console.log("Error: "+data);
			            }
				}

				return xhr_req;
			},
			update_ticket_sentiment : function(changed_senti){
				console.log("update_ticket_sentiment")
				var _this = this;
				var ticket_id = sentiment.display_id;
				var userInfo = jQuery('#LoggedOptions');
				var author = jQuery(userInfo).find('span')[0].textContent;
				var senti = _this.get_sentiment_num(changed_senti)

				var json_data = { 'helpdesk_ticket[sentiment]' : senti}

				console.log(json_data);
				var xhr_req = {
						url: '/helpdesk/tickets/'+ticket_id+'/update_ticket_properties',
			            type: 'PUT',
			            dataType: 'json',
			            data: json_data,
			            success: function (data) {
			                console.log("Success: "+data);
			            },
			            error: function (data) {
			                console.log("Error: "+data);
			            }
				}

				jQuery.ajax(xhr_req);
			},
			update_note_sentiment : function(changed_senti){
				console.log("update_note_sentiment")
				var _this = this;
				var ticket_id = sentiment.display_id;
				var userInfo = jQuery('#LoggedOptions');
				var author = jQuery(userInfo).find('span')[0].textContent;
				var senti = _this.get_sentiment_num(changed_senti)

				var json_data = { 'helpdesk_note[sentiment]' : senti}

				console.log(json_data);
				var xhr_req = {
						url: '/helpdesk/tickets/'+ticket_id+'/notes/'+sentiment.last_note.note_id,
			            type: 'PUT',
			            dataType: 'json',
			            data: json_data,
			            success: function (data) {
			                console.log("Success: "+data);
			            },
			            error: function (data) {
			                console.log("Error: "+data);
			            }
				}

				jQuery.ajax(xhr_req);
			},

			//TODO: Convert following functions to Map Constants
			get_sentiment_num : function(sentiment) {

				if(sentiment == 'sad') return -1;
				if(sentiment == 'angry') return -2;
				if(sentiment == 'happy') return 1;
				if(sentiment == 'veryHappy') return 2;
				if(sentiment == 'neutral') return 0;

			},
			get_sentiment_from_num : function(sentiment) {

				if(sentiment == -1) return 'sad';
				if(sentiment == -2) return 'angry';
				if(sentiment == 1) return 'happy';
				if(sentiment == 2) return 'veryHappy';
				if(sentiment == 0) return 'neutral';

			},
			get_sentiment_title_from_num : function(sentiment) {

				if(sentiment == -1) return 'Sad';
				if(sentiment == -2) return 'Angry';
				if(sentiment == 1) return 'Happy';
				if(sentiment == 2) return 'Very Happy';
				if(sentiment == 0) return 'Neutral';

			},
			get_sentiment_class : function(sentiment) {

				if (sentiment == -2)
			      return "symbols-emo-angry-20"
			    else if (sentiment == -1)
			      return "symbols-emo-sad-20"
			    else if (sentiment == 1)
			      return "symbols-emo-happy-20"
			    else if (sentiment == 2)
			      return "symbols-emo-veryHappy-20"
			    else 
			      return "symbols-emo-neutral-20"   
			}
		},

		bindEvents : function(){
			//on ticket load identify 
			var self = this;

			jQuery(document).ready(function(){
				self.feedback.insert_markup();
			});

			jQuery(document).on('click.sentiment','.note_mood',function(evt){
				self.feedback.change_sentiment(evt);
			});

			jQuery(document).on('click.sentiment','#show_more',function(){
				jQuery( document ).ajaxComplete(function( event, xhr, settings ) {
				  self.feedback.insert_markup();
				});
			});

			jQuery(document).on('click.sentiment','#cmi_survey_fdbk',function(){
				self.pushEventToKM("Sentiment_Feedback_Clicked",self.userProperties());
			});

			jQuery('body').on('click.sentiment','#cmi_survey_hover',function(){
				self.pushEventToKM("Sentiment_Feedback_Clicked",self.userProperties());
			});
		},
		/*
		* pjax navigate away
		*/
		flushEvents : function(){
			jQuery(".sentiment").off();
		},

		userProperties: function(){
            return {
                         'account_id': current_account_id,
                         'fields':current_account_id+'$$',
                    }
        },

        pushEventToKM: function(eventName,prop){
            this.push_event(eventName,prop);

        },

		push_event: function (event,property) {
            if(typeof (_kmq) !== undefined ){
                this.recordIdentity();
                _kmq.push(['record',event,property]);   
            }
            
        },

        getIdentity: function(){
            return current_account_id;
        },

        recordIdentity: function(){
            if(typeof (_kmq) !== undefined ){
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
                

        },

		init : function() {
			this.bindEvents();
			this.kissMetricTrackingCode(sentiment.key);
			console.log('in inits')
		}
	};
}(window.jQuery));