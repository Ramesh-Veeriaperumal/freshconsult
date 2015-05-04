/*
 * @description Custom jQuery validator methods are defined here
 */
(function($){

  // Tweet custom class
  $.validator.addMethod("facebook", $.validator.methods.maxlength, "Your Facebook reply was over 8000 characters. You'll have to be more clever." );   
  $.validator.addClassRules("facebook", { facebook: 8000 });
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

  $.validator.addMethod("tweet", function(value, element) {
    if($(element).data('tweet-count') >= 0){
      return true;
    }
  }, "Your Tweet was over 140 characters. You'll have to be more clever." );

  $.validator.addMethod("hours", function(value, element) {
     hours = normalizeHours(value);
     element.value = hours;       
     return /^([0-9]*):([0-5][0-9])(:[0-5][0-9])?$/.test(hours);
  }, 'Please enter a valid hours.');
  $.validator.addClassRules("hours", { hours: true });

  //Sla Validator
  $.validator.addMethod("only_digits", function(value, element) {
    if (/[0-9]+/.test(value)){
      jQuery('#text_'+element.id.match(/[0-9].+/)).removeClass('sla-error');
      return true;
    }
    else {
      jQuery('#text_'+element.id.match(/[0-9].+/)).addClass('sla-error');
      return false;
    }
  }, '');
  $.validator.addMethod("sla_min_time", function(value, element) {
    if (value>=900){
      jQuery('#text_'+element.id.match(/[0-9].+/)).removeClass('sla-error');
      return true;
    }
    else {
      jQuery('#text_'+element.id.match(/[0-9].+/)).addClass('sla-error');
      return false;
    }
  }, '');
  $.validator.addMethod("sla_max_time", function(value, element) {
    if (value<=31536000){
      jQuery('#text_'+element.id.match(/[0-9].+/)).removeClass('sla-error');
      return true;
    }
    else {
      jQuery('#text_'+element.id.match(/[0-9].+/)).addClass('sla-error');
      return false;
    }
  }, '');
  $.validator.addClassRules("sla_time", { only_digits:true, sla_min_time: true, sla_max_time: true });

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
      var domain_name = (element && $(element).data('domain')) || 'freshdesk.com',
      domian_restricted_regex = new RegExp("^(?!.*\\."+domain_name+"$)[/\\w\\.-]+$");
      value = trim(value)
      return this.optional(element) || (/^((https?|ftp):\/\/)?(((([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(%[\da-f]{2})|[!\$&'\(\)\*\+,;=]|:)*@)?(((\d|[1-9]\d|1\d\d|2[0-4]\d|25[0-5])\.(\d|[1-9]\d|1\d\d|2[0-4]\d|25[0-5])\.(\d|[1-9]\d|1\d\d|2[0-4]\d|25[0-5])\.(\d|[1-9]\d|1\d\d|2[0-4]\d|25[0-5]))|((([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])*([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])))\.)+(([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])*([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])))\.?)(:\d*)?)(\/((([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(%[\da-f]{2})|[!\$&'\(\)\*\+,;=]|:|@)+(\/(([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(%[\da-f]{2})|[!\$&'\(\)\*\+,;=]|:|@)*)*)?)?(\?((([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(%[\da-f]{2})|[!\$&'\(\)\*\+,;=]|:|@)|[\uE000-\uF8FF]|\/|\?)*)?(\#((([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(%[\da-f]{2})|[!\$&'\(\)\*\+,;=]|:|@)|\/|\?)*)?$/i.test(value) && domian_restricted_regex.test(value));
  }, "Please enter a valid URL");
  $.validator.addClassRules({
      url_without_protocol : { url_without_protocol : true }
  });

  // Valid Requester field check
  $.validator.addMethod("requester", function(value, element) {

    var _returnCondition = jQuery(element).data("requesterCheck"),
        _partial_list = jQuery(element).data("partialRequesterList") || []
        _user = jQuery(element).data("currentUser"), //for not editing add new requester
        _requester = jQuery(element).data("initialRequester"),
        _requesterId = jQuery(element).data("initialRequesterid")
;
    if (/(\b[-a-zA-Z0-9.'-_~!$&()*+;=:%+]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,15}\b)/.test(value)){
        _returnCondition = true
        jQuery('#helpdesk_ticket_requester_id').val('') 
    }
    
    if (value == _user) 
      _returnCondition = true

    if(value == _requester && jQuery("#helpdesk_ticket_requester_id") && jQuery("#helpdesk_ticket_requester_id").val() == _requesterId)
      _returnCondition = true

    _partial_list.each(function(item){  //check for item['choice']
      if(trim(value) == trim(item.details)) _returnCondition = true
    });
 
    return _returnCondition

 },jQuery.validator.format('We could not find any matching requester. Please check your query, or try adding a <a href="#" id="add_requester_btn_proxy">new requester.</a>'));

  $.validator.addClassRules("requester", { requester: true });


//Check if one of the two fields is filled 
$.validator.addMethod("require_from_group", function(value, element, options) {
  var numberRequired = options[0];
  var selector = options[1];
  var fields = $(selector, element.form);
  var filled_fields = fields.filter(function() {
    return $(this).val() != ""; 
  });
  var empty_fields = fields.not(filled_fields);
  if (filled_fields.length < numberRequired && empty_fields[0] == element) {
    return false;
  }
  return true;
}, jQuery.validator.format("Please enter a Email or Phone Number"));

$.validator.addClassRules("require_from_group" ,{require_from_group: [1, ".user_info"]});

// validator to verify the size of an upload
$.validator.addMethod("upload_size_validity", function(value,element){
  if (!!window.FileReader){
    var newfile = jQuery(element)[0].files;
    if(newfile.length){
      filesize = (newfile[0].size)/(1024*1024);
      return (filesize<15)
    }
  }
  return true;
},jQuery.validator.format("Upload exceeds the available 15MB limit"));

$.validator.addClassRules("upload_size_validity", { upload_size_validity: true });

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

// Agent role validation
// To check if atleast one role is present
$.validator.addMethod("at_least_one_item", function(value, element, options) {
  return($($(element).data("selector")).size() != 0)
}, jQuery.validator.format("At least one role is required for the agent"));

$.validator.addClassRules("at_least_one_item", { at_least_one_item: true});

// Time validator

$.validator.addMethod("hhmm_time_duration",function(value){
     return (/(^[0-9]*$)|(^[0-9]*:([0-5][0-9]{0,1}|[0-9])$)|(^[0-9]*\.{1}[0-9]+$)/).test(value);}, 
     "Please enter a valid time")
$.validator.addClassRules("hhmm_time_duration", {
     hhmm_time_duration: true
  });

//Email validation

$.validator.addMethod( //override email to sync ruby's email validation
    'email',
    function(value, element){
        return this.optional(element) || /^[a-zA-Z0-9.'-_~!$&()*+;=:%+]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$/.test( value );
    },
    'Please enter a valid email address.'
);

//UserEmail Validation
$.validator.addMethod( //override email to sync ruby's email validation
    'useremail',
    function(value, element){
        var result = this.optional(element) || /^[a-zA-Z0-9.'-_~!$&()*+;=:%+]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$/.test( value );
        if(!result)
          $(element).addClass("email-error");
        else
          $(element).removeClass("email-error");
        return result
    },
    'Please enter a valid email address.'
);


$.validator.addMethod("time_12", function(value, element){
  if( ! /^[0-9]{1,2}:[0-9]{1,2} [ap]m$/i.test(value) ) return false;  
  var t = value.split(' ');
  var hm = t[0].split(':'), meridian = t[1];
  var h = hm[0], m = hm[1];
  if(meridian!='am' && meridian!='pm') return false;
  if(h<1 || h>12) return false;
  if(m<0 || m>59) return false;
  return true;
}, 'Invalid time.');
$.validator.addClassRules("time-12", { time_12: true });

// Ajax remote validation with class rules
$.validator.addMethod("remotevalidate", function(value, element, param) {
      if ( this.optional(element) )
        return "dependency-mismatch";

      var $element = $(element),
          previous = this.previousValue(element);
      if (!this.settings.messages[element.name] )
        this.settings.messages[element.name] = {};
      
      previous.originalMessage = this.settings.messages[element.name].remotevalidate;
      this.settings.messages[element.name].remotevalidate = previous.message;

      param = typeof param == "string" && {url:param} || param;

      var url = $element.data("validateUrl") || param,
          d_name = $element.data("validateName") || element.name;

      if ( this.pending[element.name] ) {
        return "pending";
      }
      if ( previous.old === value ) {
        return previous.valid;
      }

      previous.old = value;
      var validator = this;
      this.startRequest(element);
      var data = {};
      data[d_name] = value;
      
      $.ajax($.extend(true, {
        url: url,
        mode: "abort",
        port: "validate" + element.name,
        dataType: "json",
        data: data,
        success: function(response) {
          validator.settings.messages[element.name].remotevalidate = previous.originalMessage;
          var valid = response["success"] === true;
          if ( valid ) {
            var submitted = validator.formSubmitted;
            validator.prepareElement(element);
            validator.formSubmitted = submitted;
            validator.successList.push(element);
            validator.showErrors();
          } else {
            var errors = {};
            var message = response["message"] || validator.defaultMessage( element, "remote" );
            errors[element.name] = previous.message = message;
            validator.showErrors(errors);
          }
          previous.valid = valid;
          validator.stopRequest(element, valid);
        }
      }, param));
      return "pending";
}, "Remote validation failed");

$.validator.addClassRules("remote-data", { remotevalidate: true });


$.validator.addMethod("trim_spaces", function(value, element){
  element.value = trim(element.value)
  return true;
}, "Auto trim of leading & trailing whitespace");
$.validator.addClassRules("trim_spaces", { trim_spaces: true });

// Redactor validator
$.validator.addMethod("required_redactor", function(value, element, param) {
  return $(element).data('redactor').isNotEmpty();
}, "This field is required.")
$.validator.addClassRules("required_redactor", { required_redactor : true });

  // Color hex validation rules
  $.validator.addMethod("color_field", function(hexcolor, element, param) {
    return /^#(?:[0-9a-fA-F]{3}){1,2}$/.test(hexcolor);
  }, "Please enter a valid hex color value.")
  $.validator.addClassRules("color_field", { color_field : true });

// validator to check the folder name presence in canned response

  $.validator.addMethod("presence_in_list", function(value, element) {
    return $(element).data("list").indexOf(value.toLowerCase()) == -1;
  }, "The name already exists.")
  $.validator.addClassRules("presence_in_list", { presence_in_list : true });

// validator to verify the size of an upload
$.validator.addMethod("zendesk_size_validity", function(value,element){
  var is_valid = true;
  if (!!window.FileReader){
    var newfile = jQuery(element)[0].files;

    if(newfile.length){
      is_valid = (newfile[0].size)/(1024*1024) <= 50;
    }
  }
  jQuery("#file_size_limit").toggle(!is_valid);
  return is_valid;
},jQuery.validator.format(''));

$.validator.addClassRules("zendesk_size_validity", { zendesk_size_validity: true });
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

$.validator.addMethod('validate_regexp', function(value, element) {
  var regExp = new RegExp('^/(.*?)/([gimy]*)$');
  var match = value.match(regExp);
  var is_valid = true;
  try {
      new RegExp(match[1], match[2]);
  }
  catch(err) {
    is_valid = false;
  }
  return is_valid;
}, "Invalid Regular Expression");

$.validator.addMethod("ca_same_folder_validity", function(value, element) {
  var is_valid = true;
  var current_folder = $(element).data('currentFolder');
  if(current_folder == value)
    is_valid = false;
  return is_valid;
}, "Cannot move to the same folder.");

$.validator.addClassRules("ca_same_folder_validity", { ca_same_folder_validity: true });

$.validator.addMethod("field_maxlength", $.validator.methods.maxlength, "Please enter less than 255 characters" );   
$.validator.addClassRules("field_maxlength", { field_maxlength: 255 });
$.validator.addClassRules("decimal", { number: true });

$.validator.addMethod("require_from_group", function(value, element, options) {
  var $fields = $(options[1], element.form),
    $fieldsFirst = $fields.eq(0),
    validator = $fieldsFirst.data("valid_req_grp") ? $fieldsFirst.data("valid_req_grp") : $.extend({}, this),
    isValid = $fields.filter(function() {
      return validator.elementValue(this);
    }).length >= options[0];

  // Store the cloned validator for future validation
  $fieldsFirst.data("valid_req_grp", validator);

  // If element isn't being validated, run each require_from_group field's validation rules
  if (!$(element).data("being_validated")) {
    $fields.data("being_validated", true);
    $fields.each(function() {
      validator.element(this);
    });
    $fields.data("being_validated", false);
  }
  return isValid;
}, $.validator.format("Please fill at least {0} of these fields."));

$.validator.addClassRules("fillone", {
    require_from_group: [1,".fillone"]
});

})(jQuery);
