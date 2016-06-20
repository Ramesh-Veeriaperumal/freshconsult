/*jslint browser: true, devel: true */
/*global  App */

(function ($) { 

  var footer_feedback_form = $("#footer_feedback_form");
  var feedback_submit_btn = $('#footer_feedback_submit');
  var feedback_subject = $('#helpdesk_ticket_ticket_body_attributes_description_html');
  var feedback_thanks = $('.footer-feedback-thanks');
  var feedback_form_validator = footer_feedback_form.validate(
    {
     debug: false,
     rules: {
        "helpdesk_ticket[ticket_body_attributes][description_html]" : { required: true },
     },
     messages: {
      "helpdesk_ticket[ticket_body_attributes][description_html]": {
        required: window.feedback_subject_required_error
       }
    },
    submitHandler: function(form, btn) {
      feedback_submit_btn.button("loading");
      // Referrer needs to be filled
      $('#meta_referrer').val(window.location.href);    
      var appended_val = '<div>' + feedback_subject.val() + '</div>' + '<br/><br/><p>' + 'Account URL: ' + window.current_account_full_domain + '</p><p>' +  'Admin: ' +  window.is_current_user_admin + '</p>';
      feedback_subject.val(appended_val);
      $(form).ajaxSubmit({
        crossDomain: true,
        dataType: 'jsonp',                       
        success: function(response, status){
          // Resetting the submit button to its default state          
          feedback_submit_btn.button("reset");          
          if(response.success === true){                
            //show thank you?
            resetFormSize();
            footer_feedback_form.fadeOut(500, function(){
              feedback_thanks.fadeIn(500);
              feedback_subject.val("");
            });
          }else {             
            //show error?
          }          
        },
        error:function(err){
          console.log(err);
          feedback_submit_btn.button("reset");
        }
      });
    }
  });

  //Reset form 
  $(document).on('pjax:end', function(){
    resetFormSize();
    feedback_thanks.fadeOut(100, function(){
      footer_feedback_form.fadeIn(500);
    });
  }); 

  $('body').on('focus.feedback_subject', '#helpdesk_ticket_ticket_body_attributes_description_html', function(){
    if(feedback_subject.val() !== ''){
      expandForm();
    }
  });

  $('body').on('keyup.feedback_subject', '#helpdesk_ticket_ticket_body_attributes_description_html', function(){
    if(feedback_subject.val() === ''){
      feedback_form_validator.resetForm();        
      resetFormSize();
    }else{
      expandForm();
    }
  });
     

  function expandForm(){
    feedback_submit_btn.fadeIn(500);
    feedback_subject.animate({ rows: "5"}, 100, function(){
        //scroll page to the bottom
        $("html, body").animate({ scrollTop:  $(document).height()-$(window).height() });
      });
  }   

  function resetFormSize(){
    feedback_submit_btn.fadeOut(200);
    feedback_subject.animate({ rows: "1"}, 100);
  }  

}(window.jQuery));
