/*
 * @description Custom jQuery validator methods are defined here
 */
(function($){

  /*  Added default values to ensure default values 
    for some layouts which doesn't include I18n js values. */
  var validationDefaults = {
    required: "This field is required.",
    remote: "Please fix this field.",
    email: "Please enter a valid email address.",
    url: "Please enter a valid URL.",
    date: "Please enter a valid date.",
    dateISO: "Please enter a valid date ( ISO ).",
    number: "Please enter a valid number.",
    digits: "Please enter only digits.",
    creditcard: "Please enter a valid credit card number.",
    equalTo: "Please enter the same value again.",
    maxlength: "Please enter no more than {0} characters.",
    minlength: "Please enter at least {0} characters.",
    rangelength: "Please enter a value between {0} and {1} characters long.",
    range: "Please enter a value between {0} and {1}.",
    max: "Please enter a value less than or equal to {0}.",
    min: "Please enter a value greater than or equal to {0}.",
    select_atleast_one: "Select at least one option.",
    select2_maximum_limit_jq: "You can only select {0} {1}",
    messenger_limit_exceeded: "Oops! You have exceeded Messenger Platform's character limit. Please modify your response.",
    password_does_not_match: "The passwords don't match. Please try again.",
    not_equal_to: "This element should not be equal to",
    email_address_invalid: 'One or more email addresses are invalid.',
    twitter_limit_exceed: "Oops! You have exceeded Twitter's character limit. You'll have to modify your response.",
    valid_hours: "Please enter a valid hours.",
    requester_validation: 'Please enter a valid requester details or <a href="#" id="add_requester_btn_proxy">add new requester.</a>',
    email_or_phone: "Please enter a Email or Phone Number",
    invalid_image: "Invalid image format",
    time: "Please enter a valid time",
    remote_fail: "Remote validation failed",
    trim_spaces: "Auto trim of leading & trailing whitespace",
    hex_color_invalid: "Please enter a valid hex color value.",
    name_duplication: "The name already exists.",
    invalid_regex: "Invalid Regular Expression",
    same_folder: "Cannot move to the same folder.",
    maxlength_255: "Please enter less than 255 characters",
    decimal_digit_valid: "Value cannot have more than 2 decimal digits",
    facebook_limit_exceed: "Your Facebook reply was over 8000 characters. You'll have to be more clever.",
    reply_limit_exceed: "Your reply was over 2000 characters. You'll have to be more clever.",
    url_format: "Invalid URL format",
    url_without_slash: "Please enter a valid URL without '/'",
    link_back_url: "Please enter a valid linkback URL",
    agent_validation: "Please enter valid agent details",
    upload_mb_limit: "Upload exceeds the available 15MB limit",
    atleast_one_role: "At least one role is required for the agent",
    invalid_time: 'Invalid time.',
    invalid_value: "Invalid value",
    atleast_one_field: "Please fill at least {0} of these fields.",
    atleast_one_portal: 'Select atleast one portal.',
    custom_header: "Please type custom header in the format -  header : value"
  };

  // Moving this to on ready to ensure that the I18n Locale has been set in the head.
  $(document).on('ready', function() {
    $.extend( $.validator.messages, {
      required: I18n.t('validation.required', { defaultValue: validationDefaults.required }),
      remote: I18n.t('validation.remote', { defaultValue: validationDefaults.remote }),
      email: I18n.t('validation.email', { defaultValue: validationDefaults.email }),
      url: I18n.t('validation.url', { defaultValue: validationDefaults.url }),
      date: I18n.t('validation.date', { defaultValue: validationDefaults.date }),
      dateISO: I18n.t('validation.dateISO', { defaultValue: validationDefaults.dateISO }),
      number: I18n.t('validation.number', { defaultValue: validationDefaults.number }),
      digits: I18n.t('validation.digits', { defaultValue: validationDefaults.digits }),
      creditcard: I18n.t('validation.creditcard', { defaultValue: validationDefaults.creditcard }),
      equalTo: I18n.t('validation.equalTo', { defaultValue: validationDefaults.equalTo }),
      maxlength: $.validator.format(I18n.t('validation.maxlength', { defaultValue: validationDefaults.maxlength })),
      minlength: $.validator.format(I18n.t('validation.minlength', { defaultValue: validationDefaults.minlength })),
      rangelength: $.validator.format(I18n.t('validation.rangelength', { defaultValue: validationDefaults.rangelength })),
      range: $.validator.format(I18n.t('validation.range', { defaultValue: validationDefaults.range })),
      max: $.validator.format(I18n.t('validation.max', { defaultValue: validationDefaults.max })),
      min: $.validator.format(I18n.t('validation.min', { defaultValue: validationDefaults.min })),
      select_atleast_one: I18n.t('validation.select_atleast_one', { defaultValue: validationDefaults.select_atleast_one }),
      select2_maximum_limit: $.validator.format(I18n.t('validation.select2_maximum_limit_jq', { defaultValue: validationDefaults.select2_maximum_limit_jq })),
    });
    // Tweet custom class

    $.validator.addMethod("facebook", $.validator.methods.maxlength, I18n.t('validation.facebook_limit_exceed', { defaultValue: validationDefaults.facebook_limit_exceed }));
    $.validator.addClassRules("facebook", { facebook: 8000 });
    $.validator.addMethod("facebook-realtime", function(value, element) {
      if($(element).data('reply-count') >= 0){
        return true;
      }
    }, I18n.t('validation.messenger_limit_exceeded', { defaultValue: validationDefaults.messenger_limit_exceeded }));

    $.validator.addMethod("notEqual", function(value, element, param) {
      return ((this.optional(element) || value).strip().toLowerCase() != $(param).val().strip().toLowerCase());
    }, I18n.t('validation.not_equal_to', { defaultValue: validationDefaults.not_equal_to }));

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
    }, I18n.t('validation.email_address_invalid', { defaultValue: validationDefaults.email_address_invalid }));
    $.validator.addClassRules("multiemail", { multiemail: true });

    $.validator.addMethod("tweet", function(value, element) {
      if($(element).data('tweet-count') >= 0){
        return true;
      }
    }, I18n.t('validation.twitter_limit_exceed', { defaultValue: validationDefaults.twitter_limit_exceed }));


    $.validator.addMethod("password_confirmation", function(value, element){
      return ($(element).val() == $("#password").val());
    }, I18n.t('validation.password_does_not_match', { defaultValue: validationDefaults.password_does_not_match }));

    $.validator.addClassRules("password_confirmation", { password_confirmation : true });

    $.validator.addMethod("hours", function(value, element) {
       hours = normalizeHours(value);
       element.value = hours;
       return /^([0-9]*):([0-5][0-9])(:[0-5][0-9])?$/.test(hours);
    }, I18n.t('validation.valid_hours', { defaultValue: validationDefaults.valid_hours }));
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
    $.validator.addMethod("ecommerce", function(value, element) {
      if($(element).data('ecommerce-count') >= 0){
        return true;
      }
    }, I18n.t('validation.reply_limit_exceed', { defaultValue: validationDefaults.reply_limit_exceed }));
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
    }, I18n.t('validation.url_format', { defaultValue: validationDefaults.url_format }));
    $.validator.addClassRules("domain_validator", { domain_validator: true });

    //URL Validator
    $.validator.addClassRules("url_validator", { url : true });

    //URL Validator without protocol
    $.validator.addMethod("url_without_protocol", function(value, element) {
        var domain_name = (element && $(element).data('domain')) || 'freshdesk.com',
        domian_restricted_regex = new RegExp("^(?!.*\\."+domain_name+"$)[/\\w\\.-]+$"),
        COLON_AND_SLASHES = "://";
        value = trim(value)
        if($(element).data('source') === 'portal' && value.indexOf(COLON_AND_SLASHES) !== -1){
          value = value.substring(value.indexOf(COLON_AND_SLASHES) + COLON_AND_SLASHES.length)
        }
        return this.optional(element) || (/^((https?|ftp):\/\/)?(((([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(%[\da-f]{2})|[!\$&'\(\)\*\+,;=]|:)*@)?(((\d|[1-9]\d|1\d\d|2[0-4]\d|25[0-5])\.(\d|[1-9]\d|1\d\d|2[0-4]\d|25[0-5])\.(\d|[1-9]\d|1\d\d|2[0-4]\d|25[0-5])\.(\d|[1-9]\d|1\d\d|2[0-4]\d|25[0-5]))|((([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])*([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])))\.)+(([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])*([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])))\.?)(:\d*)?)(\/((([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(%[\da-f]{2})|[!\$&'\(\)\*\+,;=]|:|@)+(\/(([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(%[\da-f]{2})|[!\$&'\(\)\*\+,;=]|:|@)*)*)?)?(\?((([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(%[\da-f]{2})|[!\$&'\(\)\*\+,;=]|:|@)|[\uE000-\uF8FF]|\/|\?)*)?(\#((([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(%[\da-f]{2})|[!\$&'\(\)\*\+,;=]|:|@)|\/|\?)*)?$/i.test(value) && domian_restricted_regex.test(value));
    }, I18n.t('validation.url', { defaultValue: validationDefaults.url }));
    $.validator.addClassRules({
        url_without_protocol : { url_without_protocol : true }
    });


     //domain name validator
    $.validator.addMethod("domain_name_validator", function(value, element) {
      var COLON_AND_SLASHES = "://";
      if($(element).data('source') === 'portal' && value.indexOf(COLON_AND_SLASHES) !== -1){
        value = value.substring(value.indexOf(COLON_AND_SLASHES) + COLON_AND_SLASHES.length)
      }
      return (value.indexOf('/') === -1)
    }, I18n.t('validation.url_without_slash', { defaultValue: validationDefaults.url_without_slash }));
    $.validator.addClassRules({
        domain_name_validator : { domain_name_validator : true }
    });

    //validating linkback url to avoid xss content
    $.validator.addMethod("linkback_url_valid", function(value, element) {
        value = trim(value)
        //validates the given Irl matches the standard given in https://www.ietf.org/rfc/rfc3492.txt (Accepts puny code and non-english chars) - complied from UriParser::WEB_IRL_REGEX
        return this.optional(element) || /^(^(http|https|ftp):\/\/)(?:(?:(?:%\h\h|[!$&-.0-;=A-Z_a-z~])*)@)?(?:(([a-zA-Z0-9\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF]([a-zA-Z0-9\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF\-]{0,61}[a-zA-Z0-9\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF]){0,1}\.)+[a-zA-Z\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF]{2,63}|((25[0-5]|2[0-4][0-9]|[0-1][0-9]{2}|[1-9][0-9]|[1-9])\.(25[0-5]|2[0-4][0-9]|[0-1][0-9]{2}|[1-9][0-9]|[1-9]|0)\.(25[0-5]|2[0-4][0-9]|[0-1][0-9]{2}|[1-9][0-9]|[1-9]|0)\.(25[0-5]|2[0-4][0-9]|[0-1][0-9]{2}|[1-9][0-9]|[0-9]))))(?:(:\d{1,5})?)(\/\S*)?$/i.test(value);
      }, I18n.t('validation.link_back_url', { defaultValue: validationDefaults.link_back_url }));
    $.validator.addClassRules({
        linkback_url_valid : { linkback_url_valid : true }
    });

    function requesterValidate(value, element) {

      var _returnCondition = jQuery(element).data("requesterCheck"),
          _partial_list = jQuery(element).data("partialRequesterList") || []
          _user = jQuery(element).data("currentUser"), //for not editing add new requester
          _requester = jQuery(element).data("initialRequester"),
          _requesterId = jQuery(element).data("initialRequesterid");
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

    }

    // Valid Requester field check
    $.validator.addMethod("requester", function(value, element) {
      return requesterValidate(value, element);
   },jQuery.validator.format(I18n.t('validation.requester_validation', { defaultValue: validationDefaults.requester_validation })));

    $.validator.addClassRules("requester", { requester: true });

    $.validator.addMethod("agent_requester", function(value, element) {

      var _returnCondition = requesterValidate(value, element);
      if(_results_array.length === 0) { _returnCondition = false }
      return _returnCondition

   },jQuery.validator.format(I18n.t('validation.agent_validation', { defaultValue: validationDefaults.agent_validation })));

    $.validator.addClassRules("agent_requester", { agent_requester: true });

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
  }, jQuery.validator.format(I18n.t('validation.email_or_phone', { defaultValue: validationDefaults.email_or_phone })));

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
  },jQuery.validator.format(I18n.t('validation.upload_mb_limit', { defaultValue: validationDefaults.upload_mb_limit })));

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
  },jQuery.validator.format(I18n.t('validation.invalid_image', { defaultValue: validationDefaults.invalid_image })));

  $.validator.addClassRules("validate_image", { validate_image: true });

  // Agent role validation
  // To check if atleast one role is present
  $.validator.addMethod("at_least_one_item", function(value, element, options) {
    if(!($("#agent_agent_type_field_agent").prop('checked'))){
    return($($(element).data("selector")).length != 0)
  } else {
    return true
  }
  }, jQuery.validator.format(I18n.t('validation.atleast_one_role', { defaultValue: validationDefaults.atleast_one_role })));

  $.validator.addClassRules("at_least_one_item", { at_least_one_item: true});

  // Time validator

  $.validator.addMethod("hhmm_time_duration",function(value){
       return (/(^[0-9]*$)|(^[0-9]*:([0-5][0-9]{0,1}|[0-9])$)|(^[0-9]*\.{1}[0-9]+$)/).test(value);},
       I18n.t('validation.time', { defaultValue: validationDefaults.time }))
  $.validator.addClassRules("hhmm_time_duration", {
       hhmm_time_duration: true
    });

  //Email validation

  $.validator.addMethod( //override email to sync ruby's email validation
      'email',
      function(value, element){
          return this.optional(element) || /^[a-zA-Z0-9.!#$%&'*+\/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*(\.\w{2,})+$/.test( value );
      },
      I18n.t('validation.email', { defaultValue: validationDefaults.email })
  );

  //UserEmail Validation
  $.validator.addMethod( //override email to sync ruby's email validation
      'useremail',
      function(value, element){
          var result = this.optional(element) || /^[a-zA-Z0-9.!#$%&'*+\/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*(\.\w{2,})+$/.test( value );
          if(!result)
            $(element).addClass("email-error");
          else
            $(element).removeClass("email-error");
          return result
      },
      I18n.t('validation.email', { defaultValue: validationDefaults.email })
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
  }, I18n.t('validation.invalid_time', { defaultValue: validationDefaults.invalid_time }));
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
  }, I18n.t('validation.remote_fail', { defaultValue: validationDefaults.remote_fail }));

  $.validator.addClassRules("remote-data", { remotevalidate: true });


  $.validator.addMethod("trim_spaces", function(value, element){
    element.value = trim(element.value)
    return true;
  }, I18n.t('validation.trim_spaces', { defaultValue: validationDefaults.trim_spaces }));
  $.validator.addClassRules("trim_spaces", { trim_spaces: true });

  // Redactor validator
  $.validator.addMethod("required_redactor", function(value, element, param) {
    //redactor is enabled for desktop browsers for others check for value and return accordingly
    if(jQuery.browser.desktop) {
      var isEmpty = false;

      if ($(element).data('redactor')) {
        isEmpty = $(element).data('redactor').isNotEmpty();
      } else if($(element).data('froala.editor')){
        isEmpty = !jQuery('.required_redactor').data('froala.editor').core.isEmpty();
      }

      return isEmpty;
    } else {
      var is_valid = true;

      if(value == null || value == ""){
        is_valid = false;
      }

      return is_valid;
    }
  }, $.validator.messages.required)

  $.validator.addClassRules("required_redactor", { required_redactor : true });

    // Color hex validation rules
    $.validator.addMethod("color_field", function(hexcolor, element, param) {
      return /^#(?:[0-9a-fA-F]{3}){1,2}$/.test(hexcolor);
    }, I18n.t('validation.hex_color_invalid', { defaultValue: validationDefaults.hex_color_invalid }))
    $.validator.addClassRules("color_field", { color_field : true });

  // validator to check the folder name presence in canned response

    $.validator.addMethod("presence_in_list", function(value, element) {
      return $(element).data("list").indexOf(value.toLowerCase()) == -1;
    }, I18n.t('validation.name_duplication', { defaultValue: validationDefaults.name_duplication }))
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
      }, I18n.t('validation.invalid_value', { defaultValue: validationDefaults.invalid_value }));
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
  }, I18n.t('validation.invalid_regex', { defaultValue: validationDefaults.invalid_regex }));

  $.validator.addMethod("ca_same_folder_validity", function(value, element) {
    var is_valid = true;
    var current_folder = $(element).data('currentFolder');
    if(current_folder == value)
      is_valid = false;
    return is_valid;
  }, I18n.t('validation.same_folder', { defaultValue: validationDefaults.same_folder }));

  $.validator.addClassRules("ca_same_folder_validity", { ca_same_folder_validity: true });

  $.validator.addMethod("field_maxlength", $.validator.methods.maxlength, I18n.t('validation.maxlength_255', { defaultValue: validationDefaults.maxlength_255 }));
  $.validator.addClassRules("field_maxlength", { field_maxlength: 255 });
  // For validation to the decimal fields so that only two decimal are accepted

  $.validator.addMethod("two_decimal",function(value, element) {

      return /^-?\d*(\.\d{0,2})?$/i.test(value);
  }, I18n.t('validation.decimal_digit_valid', { defaultValue: validationDefaults.decimal_digit_valid }));
  $.validator.addClassRules("decimal", { number: true , two_decimal: true});

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
  }, $.validator.format(I18n.t('validation.atleast_one_field', { defaultValue: validationDefaults.atleast_one_field })));

  $.validator.addClassRules("fillone", {
      require_from_group: [1,".fillone"]
  });

  $.validator.addMethod("portal_visibility_required", function(value, element) {
    return value != undefined;
  }, $.validator.format(I18n.t('validation.atleast_one_portal', { defaultValue: validationDefaults.atleast_one_portal })));

  $.validator.addClassRules("portal_visibility_required", { portal_visibility_required: true });

  $.validator.addMethod("valid_custom_headers", function(value, element) {
    return value.split('\n').filter(Boolean).every(function(elem) {return elem.includes(":")});
  }, $.validator.format(I18n.t('validation.custom_header', { defaultValue: validationDefaults.custom_header })));
  $.validator.addClassRules("valid_custom_headers", { valid_custom_headers: true });

  // requester company field validation
  $.validator.addMethod("compare_required",function(value, element){
    var $companyField=jQuery("#company_name"),
      status =true;
    if($companyField && $companyField.length>0){  // text company field exist
      if($companyField.val()){   //company field value exist
        status = value ? true : false
      }else{
        if(!value)
          status = true
      }
    }
    else{ // label company field exist
      status = value ? true : false
    }
    return status
  },$.validator.messages.required);
  $.validator.addClassRules("compare-required", { compare_required: true });

  // requester company name field validation
  $.validator.addMethod("company_required",function(value, element){
    return ($('#add-company').is(':checked') && value) ? true : false;
  },$.validator.messages.required);
  $.validator.addClassRules("company-required", { company_required: true });

  // ticket schedule email recipient validation
  $.validator.addMethod("email_recipient_required",function(value, element){
    var selectedValue = $('input[name="scheduled_export[schedule_details][delivery_type]"]:checked').val();
    var valid = ( selectedValue === '1' && value) || (selectedValue === '2');
    return ( valid ? true : false);
  },$.validator.messages.required);
  $.validator.addClassRules("email-recipient-required", { email_recipient_required: true });


  // ticket schedule checkbox required validation
  $.validator.addMethod("schedule_checkbox_required",function(value, element){
    var length = $('.'+ $(element).data('field') + '-item input:checkbox:checked:not(.select-all)').length;
    return ((length > 0) ? true : false);
  },$.validator.messages.select_atleast_one);
  $.validator.addClassRules("schedule-checkbox-required", { schedule_checkbox_required: true });

  // ticket schedule checkbox maximum validation
  $.validator.addMethod("schedule_checkbox_maximum",function(value, element){
    var length = $('.'+ $(element).data('field') + '-item input:checkbox:checked:not(.select-all)').length;
    return ((length <= 150) ? true : false);
  },$.validator.messages.select2_maximum_limit);
  $.validator.addClassRules("schedule-checkbox-maxlength", { schedule_checkbox_maximum: [150,'fields'] });

});

})(jQuery);
