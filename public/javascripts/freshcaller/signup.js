(function ($) {
  
  "use strict";

  var signupRequest = $('.freshcaller-signup-request');
  var signupRequestProcessing = $('.freshcaller-signup-processing');
  var linkForm = $('.freshcaller-linking-form');
  var linkProcess = $('.freshcaller-linking-process');
  var linkProcessing = $('.freshcaller-linking-processing');
  var errorText = $('.error-text');
  var errorExplanation = $('.errorExplanation');

  
  $('body').on('click', '.freshcaller_signup_btn', function(){
  	signupRequest.addClass('hide');
    signupRequestProcessing.removeClass('hide');
  });
  
  $('body').on('click', '.freshcaller_linking_btn', function(){
  	showLinkPage();
  });
  
  $('body').on('click', '.freshcaller_link_btn', function(){
    var url = $('.url-field').val(); 
    var password = $('.password-field').val(); 
    var email = $('.email-field').val();
  	if(url &&  password && email){
  		setLinkingState();
  		hideServerErrors();
  		$.ajax({
	          type: 'POST',
	          url: '/admin/freshcaller/signup/link',
	          data: {url: url, password: password, email: email},
	          success:function(result){
	          	if(result['error'] === "Incorrect password"){
                resetLinkingState();
                showServerErrors(authenticationError);
              }else if(result['error'] === "No Access to link Account"){
                resetLinkingState();
                showServerErrors(accessError);
              }
              else if(result['error'] === "Not Found"){
                resetLinkingState();
                showServerErrors(apiError);
              }
              else{
	          	  window.location.assign('/admin/phone');
	          	}
	          }, 
	          error: function(data){	
	          	resetLinkingState();
	          	showServerErrors(apiError);
	          }
	    });
	    hideFieldValidationErrors();
  	}else{
	  	showFieldValidationErrors();
    }
  });
  
  $('body').on('click', '.freshcaller_cancel_btn', function(){
  	hideFieldValidationErrors();
  	hideServerErrors();
  	showSignupPage();
  });

  function setLinkingState() {
  	linkProcessing.removeClass('hide');
    linkForm.addClass('hide');
  }

  function resetLinkingState() {
  	linkProcessing.addClass('hide');
  	linkForm.removeClass('hide');
  }

  function showServerErrors(error) {
  	errorExplanation.removeClass('hide');
	  errorExplanation.text(error);
  }

  function showFieldValidationErrors() {
  	var fields = ['url', 'email', 'password'];
  	for (var i = 0; i < fields.length; i++) {
      if(!$('.'+fields[i]+'-field').val()){
      	$('#'+fields[i]+'-error').removeClass('hide');
      }
      else{
      	$('#'+fields[i]+'-error').addClass('hide');
      }
	}
  }

  function hideServerErrors() {
  	errorExplanation.addClass('hide');
   	errorExplanation.text('');
  }

  function hideFieldValidationErrors() {
  	errorText.addClass('hide');
  }

  function showSignupPage() {
  	linkProcess.addClass('hide');
  	signupRequest.removeClass('hide');
  }

  function showLinkPage() {
  	linkProcess.removeClass('hide');
  	signupRequest.addClass('hide');
    signupRequestProcessing.addClass('hide');
  }
  	
}(jQuery));