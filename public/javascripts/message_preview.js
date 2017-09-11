/*jslint browser: true */
/*global App */

window.App = window.App || {};
(function($){
  'use strict';

  App.EmailPreviews = {
    init: function(){
      // put initialization logic here  
      this.bindEvents();
    },
    bindEvents: function() {
      var _this = this;
      var $body = $("body");

      // unbind all events first
      $body.off('.email_previews');

      $body.on("click.email_previews", '#send-email-preview', function(ev){
        ev.preventDefault();
        var mail_body = $('#email-preview-container').html();
        var subject = $('#email-preview-subject').html().trim();
        _this.sendTestMail(mail_body, subject);
      });

		  $body.on("click.email_previews", '.email-preview', function(){
			  var preview_content = $('.redactor_editor').html();
        var notiBody        = $(this).closest(".notif_form").find('.redactor_editor').html();
        var notiSubject     = $(this).closest(".notif_form").find('.email-notification-subject').val();
        var rulesBody       = $(this).closest(".s_email").find('.redactor_editor').html();
        var rulesSubject    = $(this).closest(".s_email").find('input[name=email_subject]').val();
			  var subject 				= notiSubject || $('#subject_default').val() || rulesSubject || '';
        var body            = rulesBody || notiBody || preview_content || '';
        _this.generateMailPreview(body, subject);
		  });
    },
    generateMailPreview : function(preview_content, subject){
      var preview_holder        = $("#email-preview-container");
      var subject_holder        = $("#email-preview-subject");
      var subject_title_holder  = $("#email-preview-subject-holder");
      subject_holder.hide();
      subject_title_holder.hide();
      $.ajax({
        url: '/email_preview/generate_preview',
        type: 'POST',
        data: {notification_body: preview_content, subject: subject},
        success: function(data){
          if(data.success){
            preview_holder.html(data.preview);
            if(data.subject){
              subject_holder.html(data.subject);
              subject_holder.show();
              subject_title_holder.show();
            }

            var freshdialog_data = {
              targetId: '#email-preview',
              title: "Message Preview",
              width: "800",
              templateFooter: false,
              destroyOnClose: true
            };

            $.freshdialog(freshdialog_data);
          }
          else if(data.msg) {
            $("#noticeajax").html(data.msg).show();
            closeableFlash('#noticeajax');
          }
        },
        error: function(data){
          console.log(data.responseText);
        }
      });
    },
    sendTestMail: function(content, subject){
      $.ajax({
        url: '/email_preview/send_test_email',
        type: 'POST',
        data: {mail_body: content, subject: subject},
        success: function(data){
          $('#email-preview').modal('hide');
          if(data.success){
            $("#noticeajax").html(data.message).show();         
          }
          else{
            $("#noticeajax").html(data.msg).show();
          }
          closeableFlash('#noticeajax');
          $(document).scrollTop(0); 
        },
        error: function(data){
          console.log(data.responseText);
        }
      });
    }  
  };

}(window.jQuery));

jQuery(document).ready(function(){
  App.EmailPreviews.init();
});
