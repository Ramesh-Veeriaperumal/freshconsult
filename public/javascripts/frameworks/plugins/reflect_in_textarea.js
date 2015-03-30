(function($){
  "use strict";

  var ReflectInTextarea = function(element, options){
    this.element = element;
    this.options = $.extend({}, $.fn.reflectInTextarea.defaults, options, $(element).data());
    this.reference_id;
    this.init();
  }

  ReflectInTextarea.prototype = {
    init: function(){
      this.reference_id = $(this.element).data('targetScript');
      var content_html = $(this.reference_id).html();
      var temp_div = $("<div />").html(content_html)
          temp_div.children().attr('rel',this.reference_id);
    	$(this.element).after(temp_div.html());
    	this.bind_input();
    },
    bind_input: function(){
    	var self = this;
    	$(this.element).find('input').bind("change keyup", function(ev){
  			var reply_email = this.value;

  			if(this.value != ''){
  			  reply_email = self.construct_reply_url(this.value, $(self.element).data('fullDomain'));
  			}
        console.log($('[rel="' + self.reference_id + '"]'))
  			$('[rel="' + self.reference_id + '"]').find('.codetextarea').val(reply_email);
  		}).trigger("change");
    },
    construct_reply_url: function(to_email, account_full_domain){
		var email_split  = to_email.split("@");
		var email_name   = email_split[0]||'';
		var email_domain = email_split[1]||'';

		account_full_domain = account_full_domain.toLowerCase();
		var reply_email  = "@"+account_full_domain;

		if(email_domain.toLowerCase() == account_full_domain){
		  reply_email = email_name + reply_email;
		}
		else{
		  reply_email = email_domain.replace(/\./g,'') + email_name + reply_email;
		}
		return reply_email;
	}
  }

  $.fn.reflectInTextarea = function(option) {
    return this.each(function() {
      var $this = $(this),
      data    = $this.data("reflectInTextarea"),
      options   = typeof option == "object" && option
      if (!data) $this.data("reflectInTextarea", (data = new ReflectInTextarea(this,options)))
    });
  }

  $.fn.reflectInTextarea.defaults = {
    appendInTextarea : true,
    fullDomain: '',
    targetScript: ''
  }

})(jQuery);
