/*
 * @description Support Custom jQuery validator methods are defined here
 */
(function($){

// Redactor validators
$.validator.addMethod("required_redactor", function(value, element, param) {
  if ($(element).data('redactor')){
  	return $(element).data('redactor').isEmpty();	
  }else{
  	return ($(element).val() != "");
  }
}, "This field is required.")
$.validator.addClassRules("required_redactor", { required_redactor : true });

})(jQuery);