var global = {};

jQuery('.typed').live('click', function(){
 clearSearchField(jQuery(this));
 var type = jQuery('#search-type option:selected').val();
 jQuery('#'+type+'_results').hide();
});

jQuery('.search_merge').bind('keyup', function(){
  var search_type = jQuery('#search-type option:selected').val();
  var minChars = ( search_type == "display_id" ) ? 1 : 2
  jQuery('.merge_results').hide();
  if((jQuery(this).val() != "") && (jQuery(this).val().length >= minChars))
    jQuery('#'+search_type+'_results').show();
  else
    jQuery('#'+search_type+'_results').hide();
  jQuery(this).closest('.searchicon').toggleClass('typed', jQuery(this).val()!="");
})

function check_requester(){
  var requester = jQuery('.requester_name').html();
  var same = true;
  jQuery('.requester_name').each(function(index){
    if(jQuery(this).html() != requester)
    {
      same = false;
      return false;
    }
  });
  if(same){
    jQuery('#select-requester').val(requester).keyup();
    global['select-requester'].onSearchFieldKeyDown(42);
  }
}


function enable_continue(){
  if( (jQuery('.merge-cont').hasClass('cont-primary')) && (jQuery('.merge-cont').length > 1) )
    jQuery("#bulk_merge").attr("disabled", false );
  else
    jQuery("#bulk_merge").attr("disabled", true );
}

jQuery('.primary-marker').live('click', function(){
  mark_primary(jQuery(this));
  jQuery('.twipsy').hide();
  jQuery('.primary-marker').attr('data-original-title','Mark as primary')
  jQuery(this).attr('data-original-title','Primary ticket').trigger('mouseover')
  enable_continue();
});

function bulk_merge_submit(){
  jQuery('#bulk_merge').button("loading");
  jQuery('#cancel').attr("disabled", true).addClass("disabled");
  jQuery("#target_ticket").val(jQuery('.cont-primary #merge-ticket').data("id"));
  var source_tickets = [];
  var target = jQuery('#target_ticket');
  jQuery(".merge-cont:not('.cont-primary')").each(function(){ 
    target.append(jQuery('<input />').attr({name: "source_tickets[]", value: jQuery(this).find("#merge-ticket").data("id"), class: "src"}));
  });
}

jQuery('#search-type').change(function () {
    jQuery('.searchticket').hide();
    jQuery('.merge_results').hide();
    type = jQuery('#search-type option:selected').val()
    jQuery('.searchticket').each(function(){
      if(jQuery(this).hasClass(type))
        jQuery(this).show();
      else
        jQuery(this).hide();
    });
    if(jQuery('.'+type).find('.search_merge').val() != "")
      jQuery('#'+type+'_results').show() 
});

jQuery('.merge-cont:not(".cont-primary") #resp-icon').live("click",function(){
  id = jQuery(this).closest("#contact-area").find("#merge-ticket").data("id");
  element = jQuery('.contactdiv').find("[data-id = '"+id+"']").parent();
  element.find("#resp-icon").removeClass("clicked").parents('li').removeClass("clicked");
  jQuery(this).closest(".merge-cont").remove();
  enable_continue();
  change_ticket_count();
});

jQuery('.contactdiv').live("click",function(){
  if(!jQuery(this).find('#resp-icon').hasClass("clicked"))
  {
    jQuery(this).parent().addClass("clicked");
    element = jQuery(".cont-primary").clone();
    append_to_merge_list(element, jQuery(this));
    element.find('.primary-marker').attr('title','Mark as primary').addClass('tooltip');
    replace_element = element.find('.item_info');
    title =  replace_element.attr('title');
    ticket_id = element.find("#merge-ticket").data("id")
    replace_html = "<a class='item_info' target='_blank' title='"+title+"' href='/helpdesk/tickets/"+ticket_id+"'>"
                                                                                      +replace_element.text()+"</a>"
    replace_element.replaceWith(replace_html);
    enable_continue();
    change_ticket_count();
  }
});