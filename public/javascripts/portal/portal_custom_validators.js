/*
 * @description Support Custom jQuery validator methods are defined here
 */
(function($){

// Redactor validators
var validation_messages = validation_messages || '';
var requiredMessage=validation_messages ? validation_messages.required : "This field is required."; 
$.validator.addMethod("required_redactor", function(value, element, param) {
  if ($(element).data('redactor')){
  	return $(element).data('redactor').isNotEmpty();	
  }else{
  	return ($(element).val() != "");
  }
}, requiredMessage);
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
 }, "Select at least one option.");

$.validator.addClassRules("select_atleast_one", { select_atleast_one: ['.select_atleast_one'] });

$('body').on("change", "[data-select-one]", function(){
	var _form = this.form,
      _validator = jQuery(_form).data("validator"),
      _textarea = jQuery(this).parent().find(".select_atleast_one");

	_validator.element(_textarea);
});

$.validator.addMethod("two_decimal",function(value, element) {

    return (value.trim() == '') ||  /^\d*(\.\d{0,2})?$/i.test(value);
}, "Value cannot have more than 2 decimal digits");
$.validator.addClassRules("decimal", { number: true , two_decimal: true});


$.validator.addMethod("regex_validity", function(value, element) {
        var patternString = $(element).data('regex-pattern');
        var match = patternString.match(new RegExp('^/(.*?)/([gimy]*)$'));
        var regExp;
        if(match) {
          regExp = new RegExp(match[1], match[2]);
        }
        return this.optional(element) || regExp.test(value);
    }, "Invalid value");
$.validator.addClassRules("regex_validity", { regex_validity: true });

$.validator.addMethod("field_maxlength", $.validator.methods.maxlength, "Please enter less than 255 characters" );   
$.validator.addClassRules("field_maxlength", { field_maxlength: 255 });
})(jQuery);