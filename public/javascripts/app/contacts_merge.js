function ContactsMergeInitializer(){

  jQuery('body').on('keyup.merge_contacts', '#select-user', function(){
    jQuery('#match_results').toggle(jQuery(this).val().length >= 2);
    jQuery('.searchicon').toggleClass('typed', jQuery(this).val()!="");
  });

  jQuery('body').on('click.merge_contacts', '.typed', function(){
    clearSearchField(jQuery(this));
    jQuery('#match_results').hide();
  });

  jQuery('body').on('click.merge_contacts', '#new_merge_confirm', function(){
    jQuery(this).button("loading");
  });

  jQuery('body').on('click.merge_contacts', '#back-user-merge', function(){
    jQuery('#new_merge_confirm').button('reset');
    jQuery('#new_merge_confirm').val('Continue');
  });

  jQuery('body').on('click.merge_contacts', '.contactdiv', function(){
    var in_element = jQuery("<input type='hidden' name='ids[]' id='ids[]' />").val(jQuery(this).data('id'));
    // var in_element = "<input type='hidden' name='ids[]' id='ids[]' value="+jQuery(this).data('id')+" />";
    if(!jQuery(this).children('#resp-icon').hasClass('clicked'))
    {
      jQuery('#inputs').append(in_element);
      var element = jQuery('.cont-primary').clone();
      append_to_merge_list(element, jQuery(this));
      var item_info = element.find('.item_info');
      item_info.attr('href', '/contacts/'+element.find('#user-contact').data('uid'));
      item_info.attr('target', '_blank');
      ContactsMergeAfterShow();
    }
  });

  jQuery('body').on('click.merge_contacts', '.primary-marker', function(){
    jQuery('input[type="hidden"]#parent_user_id').attr({name:'ids[]', id:false});
    jQuery('input[value='+jQuery(this).siblings('#contact-area').children('#user-contact').data('uid')+']').attr({id:"parent_user_id", name:"parent_user"});
    mark_primary(jQuery(this).parent());
  });

  jQuery('body').on('click.merge_contacts', '#resp-icon', function(){
    var icons = jQuery(this), chosen_contact = icons.parent(), contact_cover = chosen_contact.parent();
    if(!contact_cover.hasClass('present-contact') && !chosen_contact.hasClass('contactdiv'))
    {
      if(!contact_cover.hasClass('cont-primary'))
      {
        jQuery('#inputs').children().each(function(){
          if(jQuery(this).val() == chosen_contact.children('#user-contact').data('uid'))
          {
            jQuery(this).remove();
          }
        });
        contact_cover.remove();
        jQuery('.contactdiv').children('#resp-icon').removeClass('clicked');
        jQuery('.contactdiv').children().find('.info_contact_data, .item_info').removeClass('added-contact');
        ContactsMergeAfterShow();
      }
    } 
  });

}

  var ContactsMergeAfterShow = function(){
    contact_divs = jQuery('.contactdiv');
    contact_divs.each(function(){
      contact_part = jQuery(this);
      jQuery('#inputs').children('input').each( function(){
        if(jQuery(this).val() == contact_part.data('id'))
        {
          contact_part.children('#resp-icon').addClass('clicked');
          contact_part.find('.item_info, .info_contact_data').addClass('added-contact');
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


function ContactsMergeDestructor(){
  // $.off()
}