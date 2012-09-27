/*
 * @description Custom jQuery validator methods are defined here
 */
(function($){

  // Tweet custom class
  $.validator.addMethod("tweet", $.validator.methods.maxlength, "Your Tweet was over 140 characters. You'll have to be more clever." );   
  $.validator.addMethod("facebook", $.validator.methods.maxlength, "Your Facebook reply was over 8000 characters. You'll have to be more clever." );   
  $.validator.addClassRules("tweet", { tweet: 140 });
  $.validator.addClassRules("facebook", { tweet: 8000 });
  $.validator.addMethod("notEqual", function(value, element, param) {
    return ((this.optional(element) || value).strip().toLowerCase() != $(param).val().strip().toLowerCase());
  }, "This element should not be equal to");

  $.validator.addMethod("multiemail", function(value, element) {
     if (this.optional(element)) // return true on optional element
       return true;
     var emails = value.split( new RegExp( "\\s*,\\s*", "gi" ) );
     valid = true;
     $.each(emails, function(i, email){            
        valid=/^((([a-z]|\d|[!#\$%&'\*\+\-\/=\?\^_`{\|}~]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])+(\.([a-z]|\d|[!#\$%&'\*\+\-\/=\?\^_`{\|}~]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])+)*)|((\x22)((((\x20|\x09)*(\x0d\x0a))?(\x20|\x09)+)?(([\x01-\x08\x0b\x0c\x0e-\x1f\x7f]|\x21|[\x23-\x5b]|[\x5d-\x7e]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(\\([\x01-\x09\x0b\x0c\x0d-\x7f]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF]))))*(((\x20|\x09)*(\x0d\x0a))?(\x20|\x09)+)?(\x22)))@((([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])*([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])))\.)+(([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])*([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])))\.?$/i.test(email);                     
        if(!valid) return false
     });
     return valid;
  }, 'One or more email addresses are invalid.');
  $.validator.addClassRules("multiemail", { multiemail: true });

  $.validator.addMethod("hours", function(value, element) {
     hours = normalizeHours(value);
     element.value = hours;       
     return /^([0-9]*):([0-5][0-9])(:[0-5][0-9])?$/.test(hours);
  }, 'Please enter a valid hours.');
  $.validator.addClassRules("hours", { hours: true });


  //Domain Name Validator 
  $.validator.addMethod("domain_validator", function(value, element) {
     if (this.optional(element)) // return true on optional element
       return true;
      if (value.length == 0) { return true; }       
    if(/((http|https|ftp):\/\/)\w+/.test(value))
    valid = false;
    else if(/\w+[\-]\w+/.test(value))
    valid = true;
      else if((/\W\w*/.test(value))) {
      valid = false;
      }
      else valid = true;
      if(/_+\w*/.test(value))
      valid = false;               
     return valid;
  }, 'Invalid URL format');
  $.validator.addClassRules("domain_validator", { domain_validator: true });

  //URL Validator
  $.validator.addClassRules("url_validator", { url : true });

  //URL Validator without protocol
  $.validator.addMethod("url_without_protocol", function(value, element) {
      return this.optional(element) || /^((https?|ftp):\/\/)?(((([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(%[\da-f]{2})|[!\$&'\(\)\*\+,;=]|:)*@)?(((\d|[1-9]\d|1\d\d|2[0-4]\d|25[0-5])\.(\d|[1-9]\d|1\d\d|2[0-4]\d|25[0-5])\.(\d|[1-9]\d|1\d\d|2[0-4]\d|25[0-5])\.(\d|[1-9]\d|1\d\d|2[0-4]\d|25[0-5]))|((([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])*([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])))\.)+(([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])*([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])))\.?)(:\d*)?)(\/((([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(%[\da-f]{2})|[!\$&'\(\)\*\+,;=]|:|@)+(\/(([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(%[\da-f]{2})|[!\$&'\(\)\*\+,;=]|:|@)*)*)?)?(\?((([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(%[\da-f]{2})|[!\$&'\(\)\*\+,;=]|:|@)|[\uE000-\uF8FF]|\/|\?)*)?(\#((([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(%[\da-f]{2})|[!\$&'\(\)\*\+,;=]|:|@)|\/|\?)*)?$/i.test(value);
  }, "Please enter a valid URL");
  $.validator.addClassRules({
      url_without_protocol : { url_without_protocol : true }
  });

})(jQuery);