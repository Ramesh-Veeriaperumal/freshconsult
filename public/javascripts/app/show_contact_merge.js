jQuery('#select-user').bind('keyup', function(){
  jQuery('#match_results').toggle(jQuery(this).val().length >= 2);
  jQuery('.searchicon').toggleClass('typed', jQuery(this).val()!="");
});

jQuery('.typed').on('click', function(){
  clearSearchField(jQuery(this));
  jQuery('#match_results').hide();
});

jQuery('#new_merge_confirm').on('click', function(){
  jQuery(this).button("loading");
});

jQuery('#back-user-merge').on('click', function(){
  jQuery('#new_merge_confirm').button('loaded');
  jQuery('#new_merge_confirm').val('Continue');
});

jQuery('.contactdiv').on('click', function(){
  var in_element = "<input type='hidden' name='ids[]' id='ids[]' value="+jQuery(this).data('id')+" />";
  if(!jQuery(this).children('#resp-icon').hasClass('clicked'))
  {
    jQuery('#inputs').append(in_element);
    var element = jQuery('.cont-primary').clone();
    append_to_merge_list(element, jQuery(this));
    var item_info = element.find('.item_info');
    item_info.attr('href', '/contacts/'+element.find('#user-contact').data('uid'));
    item_info.attr('target', '_blank');
    aftershow();
  }
});

jQuery('.primary-marker').on('click', function(){
  jQuery('#parent_user_id').attr('name', 'ids[]');
  jQuery('#parent_user_id').attr('id', 'ids[]');
  jQuery('input[value='+jQuery(this).siblings('#contact-area').children('#user-contact').data('uid')+']').attr('id', 'parent_user_id');
  jQuery('input[value='+jQuery(this).siblings('#contact-area').children('#user-contact').data('uid')+']').attr('name', 'parent_user');
  mark_primary(jQuery(this))
});

jQuery('#resp-icon').on('click', function(){
  if(!jQuery(this).parent().parent().hasClass('present-contact') && !jQuery(this).parent().hasClass('contactdiv'))
  {
    var chose = jQuery(this).parent();
    if(!chose.parent().hasClass('cont-primary'))
    {
      jQuery('#inputs').children().each(function(){
        if(jQuery(this).val() == chose.children('#user-contact').data('uid'))
        {
          jQuery(this).remove();
        }
      });
      chose.parent().remove();
      jQuery('.contactdiv').children('#resp-icon').removeClass('clicked');
      jQuery('.contactdiv').children().find('.info_contact_data, .item_info').removeClass('added-contact');
      aftershow();
    }
  } 
});

var aftershow = function(){
  x = jQuery('.contactdiv');
  x.each(function(){
    y = jQuery(this);
    jQuery('#inputs').children('input').each( function(){
      if(jQuery(this).val() == y.data('id'))
      {
        y.children('#resp-icon').addClass('clicked');
        y.find('.item_info, .info_contact_data').addClass('added-contact');
      }
    });
  });
  if(jQuery('#inputs').children('[name="ids[]"]').length>0)
  {
    jQuery('#new_merge_confirm').removeAttr('disabled').removeClass('disabled');
  }
  else
  {
    jQuery('#new_merge_confirm').attr('disabled','disabled').addClass('disabled');
  }
}