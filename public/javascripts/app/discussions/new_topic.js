window.App = window.App || {};
window.App.Discussions = window.App.Discussions || {};

(function ($) {
  "use strict";

  window.App.Discussions.NewTopic = {
    firstEmail: '',
    fullConversation: '',

    onVisit: function() {
      this.addListeners();
      this.setFirstEmail();
    },

    addListeners: function() {
      $('body').on('change.NewTopic', '.topic-ticket-option input', this.afterOptionSelection.bind(this));
      $('body').on('click.NewTopic', '.remove-attachment', this.removeAttachment);
    },

    afterOptionSelection: function() {
      var selectedOption = $('input[name=topic-options]:checked', '.topic-ticket-option').val();
      if (selectedOption == "first-email" ) {
        this.setTopicBody(this.firstEmail);
      } else if (selectedOption == "full-conversation") {
        this.setFullConversation();
      }  
    },

    setFullConversation: function() {
      if (this.fullConversation.empty()){
        var $this = this;
        var ticketId = $('#topic_display_id').val();
        $.ajax( {
          type: 'GET',
          url:  "/helpdesk/tickets/"+ticketId+"/notes/public_conversation",
          dataType: 'html',
          success: function (fullConversation) {
            $this.fullConversation =fullConversation;
            $this.setTopicBody($this.fullConversation);
          },
          error: function(){
            console.log('fetching full conversation failed');
          }
        } );
      } else {
        this.setTopicBody(this.fullConversation);
      }
    },

    setFirstEmail: function() {
      if (this.firstEmail.empty()) {
        this.firstEmail = $('#topic_body_html').text(); 
      }
    },

    setTopicBody: function(content) {
      $('#topic_body_html').setCode(content);
    },

    removeAttachment: function() {
      $(this).parents('li').remove();
    },

    onLeave: function() {
      $('body').off('.NewTopic');
    }  
  };
}(window.jQuery));

