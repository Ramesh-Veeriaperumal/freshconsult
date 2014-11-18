/*
 * @description Support Custom jQuery validator methods are defined here
 */
(function($){

// Redactor validators
$.validator.addMethod("required_redactor", function(value, element, param) {
  if ($(element).data('redactor')){
  	return $(element).data('redactor').isNotEmpty();	
  }else{
  	return ($(element).val() != "");
  }
}, "This field is required.")
$.validator.addClassRules("required_redactor", { required_redactor : true });



//Validator to check whether the file is an image file
$.validator.addMethod("validate_image", function(value,element){
  if (window.FileReader){
    var newfile = jQuery(element)[0].files;
    if(newfile.length){
      var file = newfile[0]
      return /^image*/.test(file.type);
    }
  }
  return true;
},jQuery.validator.format("Invalid image format"));

$.validator.addClassRules("validate_image", { validate_image: true });

$.validator.addMethod("password_confirmation", function(value, element){
  return ($(element).val() == $("#password").val());
}, "Should be same as Password")

$.validator.addClassRules("password_confirmation", { password_confirmation : true });

$.validator.addMethod("select_atleast_one", function(value,element,options){
  return $('[data-select-one]:checked').length > 0 || $('textarea[data-select-one]').val().length > 0;
 }, "Select atleast one option.");

$.validator.addClassRules("select_atleast_one", { select_atleast_one: ['.select_atleast_one'] });

$('body').on("change", "[data-select-one]", function(){
	var _form = this.form,
      _validator = jQuery(_form).data("validator"),
      _textarea = jQuery(this).parent().find(".select_atleast_one");

	_validator.element(_textarea);
});

})(jQuery);