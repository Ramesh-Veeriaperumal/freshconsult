(function ($) {
	"use strict";
  $('body').on('click', '.freshcaller_signup_btn', function(){
  	$('.freshcaller-signup-request').addClass('hide');
    $('.freshcaller-signup-processing').removeClass('hide');
  });
}(jQuery));