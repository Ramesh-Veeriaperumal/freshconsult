
App.Sentiment = {
	CONST : {
		timeout : 4000,
		endpoint : 'http://sentimentelb-866010645.us-east-1.elb.amazonaws.com/api/v1/feedback/'
	},
	feedback : {
		insert_markup : function() {

			console.log("Inside insert markup.. ");
			console.log("Ticket Id: "+sentiment.ticket_id);
			console.log("Note Id: "+sentiment.last_note.note_id);
			console.log("Ticket sentiment: "+sentiment.ticket_sentiment);
			console.log("Note sentiment: "+sentiment.last_note.note_sentiment);

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

			jQuery('.cmi-fdbk').html("Not "+sentiment_title+"? Click to change.");
			
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

			jQuery('.cmi-fdbk').html("Successfully changed!");

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
		get_sentiment_from_title : function(sentiment) {

			if(sentiment == 'Sad') return 'sad';
			if(sentiment == 'Angry') return 'angry';
			if(sentiment == 'Happy') return 'happy';
			if(sentiment == 'Very Happy') return 'veryHappy';
			if(sentiment == 'Neutral') return 'neutral';

		},
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
		get_source : function(sentiment) {

			if (sentiment == -2)
		      return "http://imgh.us/emo-angry.svg"
		    else if (sentiment == -1)
		      return "http://imgh.us/emo-sad.svg"
		    else if (sentiment == 1)
		      return "http://imgh.us/emo-happy.svg"
		    else if (sentiment == 2)
		      return "http://imgh.us/emo-veryhappy.svg"
		    else 
		      return "http://imgh.us/emo-neutral.svg"   
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
	},
	/*
	* pjax navigate away
	*/
	flushEvents : function(){
		jQuery(".sentiment").off();
	},
	init : function() {
		this.bindEvents();
		console.log('in inits')
	}
}