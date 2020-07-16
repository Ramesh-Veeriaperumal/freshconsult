window.App = window.App || {};
window.App.Discussions = window.App.Discussions || {};

(function ($) {
  "use strict";

  window.App.Discussions.NewTopic = {
    firstEmail: '',
    fullConversation: '',

    onVisit: function() {
      if (App.namespace === "discussions/topics/new" || App.namespace === "discussions/topics/edit") {
        $('#sticky_redactor_toolbar').removeClass('hide');
        var $forumTopicDescription = $('#topic_forums_description');
        
        if($forumTopicDescription.data('newEditor')) {
          var editorType = $forumTopicDescription.attr('editor-type') || 'forum';
          invokeEditor('topic_forums_description', editorType);
        }
        else {
          invokeRedactor('topic_forums_description', 'forum');
        }
      }
      else {
        this.confirmBeforeLeavingUnsavedContent();
      }
      this.addListeners();
      this.setFirstEmail();
      this.formsave();
    },

    formsave: function(){
      $('#post-form').submit(function(){$(window).off('beforeunload.NewTopic');});
    },

    confirmBeforeLeavingUnsavedContent: function(){

      var $this = this;
      var msg = $this.STRINGS.unsavedContent
      $(window).on('beforeunload.NewTopic', function(e) {
          if (jQuery('#topic_body_html').data('redactor').isNotEmpty() || jQuery('#topic_title').val().length > 0)
          {
              if(!e)
              {
                e = window.event;
              }
              e.preventDefault();
              e.stopPropagation();  
              e.returnValue = true;
              return msg;     
          }
      });

      $(document).on('pjax:beforeSend.NewTopic',function(){
        if(jQuery('#topic_body_html').data('redactor').isNotEmpty() || jQuery('#topic_title').val().length > 0)
          if(!confirm($this.STRINGS.unsavedContent + " " + $this.STRINGS.leaveQuestion))
          {
            Fjax.resetLoading();
            return false;
          }
      });
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
        this.firstEmail = $('#topic_forums_description').text(); 
      }
    },

    setTopicBody: function(content) {
      var forum_topic_description = $('#topic_forums_description');
      if(forum_topic_description.data('newEditor')) {
        forum_topic_description.data('froala.editor').html.set(content)
      } else {
        forum_topic_description.setCode(content);
      }
    },

    removeAttachment: function() {
      $(this).parents('li').remove();
    },

    onLeave: function() {
      $('body').off('.NewTopic');
    }  
  };
}(window.jQuery));

