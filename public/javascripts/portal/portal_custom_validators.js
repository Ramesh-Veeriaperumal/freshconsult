/*
 * @description Support Custom jQuery validator methods are defined here
 */
(function($){

// Redactor validator
$.validator.addMethod("required_redactor", function(value, element, param) {
  return $(element).data('redactor').isEmpty();
}, "This field is required.")
$.validator.addClassRules("required_redactor", { required_redactor : true });

})(jQuery);