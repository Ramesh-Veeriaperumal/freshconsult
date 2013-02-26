var global = {};

jQuery('.typed').live('click', function(){
 clearSearchField(jQuery(this));
 var type = jQuery('#search-type option:selected').val();
 jQuery('#'+type+'_results').hide();
});

jQuery('.search_merge').bind('keyup', function(){
  var type = jQuery('#search-type option:selected').val();
  jQuery('.merge_results').hide();
  if((jQuery(this).val() != "") && (jQuery(this).val().length >= 2))
    jQuery('#'+type+'_results').show();
  else
    jQuery('#'+type+'_results').hide();
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

jQuery('#search-type').focus(function () {
    previous = this.value;
    text = jQuery('.'+previous).find('.search_merge').val()
}).change(function() {
    jQuery('.searchticket').hide();
    jQuery('.merge_results').hide();
    type = jQuery('#search-type option:selected').val()
    jQuery('.searchticket').each(function(){
      if(jQuery(this).hasClass(type))
        jQuery(this).show();
      else
        jQuery(this).hide();
    });
    if( text != "")
    {
      var txt_box = jQuery('.'+type).find('.search_merge');
      var txt_box_id = txt_box.attr("id");
      txt_box.val(text).keyup();
      global[txt_box_id].onSearchFieldKeyDown(42);
    }
});

jQuery('.merge-cont:not(".cont-primary") #resp-icon').live("click",function(){
  id = jQuery(this).closest("#contact-area").find("#merge-ticket").data("id");
  jQuery('.contactdiv').find("[data-id = '"+id+"']").parent().find("#resp-icon").removeClass("clicked");
  jQuery(this).closest(".merge-cont").remove();
  enable_continue();
  change_ticket_count();
});

jQuery('.contactdiv').live("click",function(){
  if(!jQuery(this).find('#resp-icon').hasClass("clicked"))
  {
    element = jQuery(".cont-primary").clone();
    append_to_merge_list(element, jQuery(this));
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