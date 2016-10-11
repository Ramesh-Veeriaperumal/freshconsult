
App.Sentiment = {
	CONST : {
		timeout : 4000,
		endpoint : 'http://sentimentelb-866010645.us-east-1.elb.amazonaws.com/api/v1/feedback/'
	},
	feedback : {
		insert_markup : function() {

			console.log("Inside insert markup.. ")
			
			var _this = this;
		    var sentiment_tmpl = JST["app/template/sentiment_feedback_template"]({
            	'data': 'data'
        	});

		    last_customer_box = jQuery('div[rel="customer_msg"]').last();
		    jQuery(sentiment_tmpl).appendTo(last_customer_box);

		    this.show_sentiment();
        
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
		show_sentiment : function() {
			console.log("In show sentiment")

			sentiment_title = jQuery('.sentiment').last()[0].getAttribute('data-original-title');
			last_note_sentiment = this.get_sentiment_from_title(sentiment_title);

			m = jQuery('.cmi-plugin .'+last_note_sentiment);
			m.closest('li').addClass('selected');

			jQuery('.cmi-fdbk').html("Not "+sentiment_title+"? Click to change.");
		},
		change_sentiment : function(evt){
			var target = evt.target;

			var sentiment = target.closest('a').classList[1];

			m1 = jQuery('.cmi-plugin .note_mood');
			m1.closest('li').removeClass('selected');

			m = jQuery('.cmi-plugin .'+sentiment);
			m.closest('li').addClass('selected');

			jQuery('.cmi-fdbk').html("Successfully changed!");

			this.post_feedback();
		},
		post_feedback : function(sentiment) {

			var self = this;
			jQuery.ajax(self.getParams(sentiment));
		},
		getParams : function(sentiment) {
			var _this = this;

			var json_data = {
				var ticket_id = jQuery('#ticket-display-id')[0].innerHTML.split('#')[1];
				var userInfo = jQuery('#LoggedOptions');
				var author = jQuery(userInfo).find('span')[0].textContent;

				"data": {
					"account_id": window.current_account_id,
					"ticket_id": window.current_user_id,
					"note_id": 0,
					"predicted_value": get_sentiment_num(last_note_sentiment),
					"feedback": get_sentiment_num(sentiment),
					"user_id": author
				}
			}
			var xhr_req = {
					url: "http://sentimentelb-866010645.us-east-1.elb.amazonaws.com/api/v1/feedback/",
		            type: 'POST',
		            crossDomain: true,
		            dataType: 'json',
		            data: Browser.stringify(json_data),
		            success: function (data) {
		                console.log("Success: "+data);
		            },
		            error: function (data) {
		                console.log("Error: "+data);
		            }
			}

			return xhr_req;
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