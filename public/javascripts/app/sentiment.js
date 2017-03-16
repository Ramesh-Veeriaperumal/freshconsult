window.App = window.App || {};
(function($) {
  App.Sentiment = {
    CONST: {
      timeout: 4000
    },
    
    feedback: {
      insert_markup: function() {
        var _this = this,
        feedback_node = "<div id=\"feedback_container\"></div>",
        $feedback_dom_node =  jQuery(feedback_node),
        customer_msges = jQuery('div[rel="customer_msg"]');

        if (jQuery('#feedback_container').length == 0) {
          if (sentiment.last_note.note_id == undefined) {
            var desc_box = customer_msges[0];
            predicted_sentiment = sentiment.ticket_sentiment;
            if (predicted_sentiment != undefined) {
              $feedback_dom_node.appendTo(desc_box);
              _this.show_sentiment();
            }
          } else {
            if (jQuery('#helpdesk_note_' + sentiment.last_note.note_id).length > 0) {
              var note_box = jQuery('#helpdesk_note_' + sentiment.last_note.note_id + ' .commentbox')[0];
              predicted_sentiment = sentiment.last_note.note_sentiment;
              if (predicted_sentiment != undefined) {
                $feedback_dom_node.appendTo(note_box);
                _this.show_sentiment();
              }
            }
          }
        }
      },
      
      show_sentiment: function() {
        var _this = this;
        sentiment_title = _this.get_sentiment_title_from_num(predicted_sentiment);
        var sentiment_new = JST["app/template/new_sentiment_template"]({
          'color_name': sentiment_title
        });
        jQuery('#feedback_container').append(sentiment_new);
      },
      
      change_sentiment: function(evt) {
        var $target = jQuery(evt.target).closest('.senti-option');
        var changed_senti = $target.children('.senti_text').html();
        var $sentiment_predicted_button = jQuery('.senti-main-container.senti-changable');
        $sentiment_predicted_button.children().first().removeClass().addClass(changed_senti);
        $sentiment_predicted_button.children(".senti_text").html(changed_senti);
        jQuery('.senti-option').removeClass('senti-selected');
        $target.addClass('senti-selected');
        this.post_feedback(changed_senti);
        if (sentiment.last_note.note_id == undefined) {
          this.update_ticket_sentiment(changed_senti);
        } else {
          this.update_note_sentiment(changed_senti);
        }
      },
      
      post_feedback: function(changed_senti) {
        var self = this;
        jQuery.ajax(self.get_params(changed_senti));
      },
      
      get_params: function(changed_senti) {
        var _this = this;
        var ticket_id = sentiment.ticket_id;
        var userInfo = jQuery('#LoggedOptions');
        var author = jQuery(userInfo).find('span')[0].textContent;
        var note_id = sentiment.last_note.note_id;
        if (note_id == undefined) { note_id = 0; }
        var json_data = {
            "data": {
              "account_id": window.current_account_id,
              "ticket_id": ticket_id,
              "note_id": note_id,
              "predicted_value": _this.get_sentiment_num(sentiment_title),
              "feedback": _this.get_sentiment_num(changed_senti),
              "user_id": window.current_user_id
            }
          }
            
        var xhr_req = {
          url: "/helpdesk/tickets/sentiment_feedback",
          type: 'POST',
          dataType: 'json',
          data: json_data,
          success: function(data) {   
          },
          error: function(data) {
            console.error('error in post');
          }
        }
        return xhr_req;
      },
      
      update_ticket_sentiment: function(changed_senti) {
        
        var ticket_id = sentiment.display_id;
        var userInfo = jQuery('#LoggedOptions');
        var author = jQuery(userInfo).find('span')[0].textContent;
        var senti = this.get_sentiment_num(changed_senti);
        var json_data = { 'helpdesk_ticket[sentiment]': senti };
        var xhr_req = {
          url: '/helpdesk/tickets/' + ticket_id + '/update_ticket_properties',
          type: 'PUT',
          dataType: 'json',
          data: json_data,
          success: function(data) {    
          },
          error: function(data) {
            console.error('error in put');
          }
        }
        jQuery.ajax(xhr_req);
      },
      
      update_note_sentiment: function(changed_senti) {
        var ticket_id = sentiment.display_id;
        var userInfo = jQuery('#LoggedOptions');
        var author = jQuery(userInfo).find('span')[0].textContent;
        var senti = this.get_sentiment_num(changed_senti);
        var json_data = { 'helpdesk_note[sentiment]': senti };
        var xhr_req = {
          url: '/helpdesk/tickets/' + ticket_id + '/notes/' + sentiment.last_note.note_id,
          type: 'PUT',
          dataType: 'json',
          data: json_data,
          success: function(data) {
          },   
          error: function(data) {
            console.error('error in put');
          }
        }
        jQuery.ajax(xhr_req);
      },
      
      //TODO: Convert following functions to Map Constants
      get_sentiment_num: function(sentiment) {
        const SAD = -1, HAPPY = 1, NEUTRAL = 0;
        if (sentiment == 'SAD') return SAD;
        if (sentiment == 'HAPPY') return HAPPY;
        if (sentiment == 'NEUTRAL') return NEUTRAL;
      },
      
      get_sentiment_title_from_num: function(sentiment) {
        if (sentiment == -1 || sentiment == -2) return 'SAD';
        if (sentiment == 1 || sentiment == 2) return 'HAPPY';
        if (sentiment == 0) return 'NEUTRAL';
      },
    
    },
    
    bindEvents: function() {
      //on ticket load identify 
      var self = this;
      var $document = jQuery(document);
      
      $document.ready(function() {
        self.feedback.insert_markup();
        jQuery('.senti-main-container.senti-changable').on('click.sentiment', function() {
          jQuery('.change-prediction-box').fadeToggle();
        });
      });
      $document.on('click.sentiment', '.senti-option', function(evt) {
        jQuery('.change-prediction-box').fadeOut();
        self.blinkBorderFunction();
        self.feedback.change_sentiment(evt);
      });
      $document.on('click.sentiment', '#show_more', function() {
        $document.ajaxComplete(function(event, xhr, settings) {
          self.feedback.insert_markup();
        });
      });
      $document.on('click.sentiment', '#cmi_survey_fdbk', function() {
        self.pushEventToKM("Sentiment_Feedback_Clicked", self.userProperties());
      });
      jQuery('body').on('click.sentiment', '#cmi_survey_hover', function() {
        self.pushEventToKM("Sentiment_Feedback_Clicked", self.userProperties());
      });
    },
    
    /*
     * pjax navigate away
     */
    flushEvents: function() {
      jQuery(".sentiment").off();
    },
    
    userProperties: function() {
      return {
        'account_id': current_account_id,
        'fields': current_account_id + '$$',
      }
    },
    
    pushEventToKM: function(eventName, prop) {
      this.push_event(eventName, prop);
    },
    
    push_event: function(event, property) {
      if (typeof(_kmq) !== undefined) {
        this.recordIdentity();
        _kmq.push(['record', event, property]);
      }
    },
    
    getIdentity: function() {
      return current_account_id;
    },
    
    recordIdentity: function() {
      if (typeof(_kmq) !== undefined) {
        _kmq.push(['identify', this.getIdentity()]);
      }
    },
    
    kissMetricTrackingCode: function(api_key) {
      var _kmq = _kmq || [];
      var _kmk = _kmk || api_key;

      function _kms(u) {
        setTimeout(function() {
          var d = document,
            f = d.getElementsByTagName('script')[0],
            s = d.createElement('script');
          s.type = 'text/javascript';
          s.async = true;
          s.onload = function() {
            trigger_event("script_loaded", {});
          };
          s.src = u;
          f.parentNode.insertBefore(s, f);
        }, 1);
      }
      _kms('//i.kissmetrics.com/i.js');
      _kms('//scripts.kissmetrics.com/' + _kmk + '.2.js');
    },
    
    blinkBorderFunction: function() {
      var $senti_container = jQuery('.senti-main-container.senti-changable'),
        blinker = setInterval(function() {
          $senti_container.toggleClass('blinking-border');
        }, 300);
      setTimeout(function() {
        $senti_container.removeClass('blinking-border');
        clearInterval(blinker)
      }, 3000);
    },

    init: function() {
      this.bindEvents();
      this.kissMetricTrackingCode(sentiment.key);
      
    }
  };
}(window.jQuery));
