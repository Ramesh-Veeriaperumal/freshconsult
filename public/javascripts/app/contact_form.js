function ContactFormInitializer(confirm_text, tags_options) {


  jQuery("#contact_customer").autocomplete({
      source: function(request, response) {
          jQuery.ajax({
              url: "/search/autocomplete/companies",
              data: {
                  q: request.term
              },
              success: function(data) {
                  response(jQuery.map(data.results,
                  function(item) {
                      return {
                          label: escapeHtml(item.value),
                          value: item.value
                      }
                  }));
              }
          });
      },
      select: function(event, ui) {
      			jQuery("#user_address").focus();
          },
      open: function() {
          jQuery(this).removeClass('ui-corner-all');
      }
  }).data("autocomplete")._renderItem = function(ul, item) {
      return jQuery("<li></li>")
      .data("item.autocomplete", item)
      .append("<a>" + item.label + "</a>")
      .appendTo(ul);
  };

  jQuery('body').on('click.contact_form', '#contact_submit', function(ev){
  	if(jQuery.trim(jQuery('#contact_customer').val()) == '')
 	  {
  		jQuery('#contact_role').removeAttr('checked');
   	}
	});

  jQuery("body").on('keyup.contact_form', '#contact_customer', function(ev) {
      var company = this.value.trim();
      if (company != "")
      {
          jQuery('#contact_role').removeAttr("disabled");
      }
      else
      {
          jQuery('#contact_role').removeAttr('checked');
          jQuery('#contact_role').prop("disabled", true);
      }
  });

	jQuery("input[name='user[tag_names]']").select2({
	  	tags: tags_options.split(","),
	  	tokenSeparators: [',']
	});

  jQuery('body').on('click.contact_form', ".ui-menu-item", function(ev){
  	jQuery("#user_address").focus();
	});

 jQuery('body').on('click.contact_form', '#add_new_mail', function(ev){
  ev.preventDefault();
  if(!jQuery(this).hasClass('disabled'))
  {
  	if(!jQuery('#emails_con .error').is(':visible'))
  	{
		  email = jQuery('#emails_con input[type=text]').length;
		  name="user[user_emails_attributes]["+email+"][email]";
		  jQuery('#emails_con').append('<li class="control-group"><div class="controls"><input type="text" class="email valid cont-new text input-xlarge" name = '+name+'><span id="cancel_email"></span></div></li>');
		}
	  jQuery(this).addClass('disabled');
	}
});

jQuery('body').on('click.contact_form', '.remove_image', function(){
	if(confirm(confirm_text))
	{
		jQuery('#emails_con').append('<input name="deleted[]" type="hidden" value='+jQuery(this).data("email")+'>');
		jQuery(this).parent().children("input[type=hidden]").val(1);
		jQuery(this).parent().next().hide(); //This is to remove the hidden id field
		jQuery(this).parent().hide();
	}
});

jQuery('.remove_image').each(function(rm, rv){
	if(jQuery(rv).parent().next().hasClass('fieldWithErrors'))
	{
		jQuery(rv).attr({id:'wrong_email', title:'Click to remove this email'});
		jQuery(rv).parent().attr('onclick', '');
	}
});

jQuery('body').on('click.contact_form', '#wrong_email', function(){
	jQuery(this).parent().next().remove();
	jQuery(this).parent().remove();
});

jQuery("body").on('click.contact_form', '#cancel_email', function(ev){
	ev.preventDefault();
	jQuery(this).parent().remove();
	if(!jQuery('#cancel_email').length)
		jQuery('#add_new_mail').removeClass('disabled')
	jQuery('.email').trigger('keyup');
});

jQuery('body').on('keyup.contact_form focusout.contact_form', '.email', function(){
		jQuery('#add_new_mail').toggleClass('disabled', !jQuery.trim(jQuery('#add_email').parent().parent().prev().find('input[type=text]').last().val()));
		if(jQuery('#cancel_email').length)
			jQuery('#add_new_mail').removeClass('disabled')
});

jQuery('.form_for_contact').submit(function(ev){
	var email = jQuery('#emails_con').find('input[type="text"]').val(),
			twitter = jQuery("#user_twitter_id").val().length,
			phone = jQuery('#phone_work').val().length,
			mobile = jQuery('#phone_mobile').val().length;

	if(!email && !twitter && !phone && !mobile)
	{
		ev.preventDefault();
		show_growl_flash("Please fill any one of the columns", 'error');
	}
});

//jQuery('.email').trigger('keyup');

}
