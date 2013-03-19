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


enable_continue = function(){
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
  var target = jQuery('#bulk_merge_tickets');
  jQuery(".merge-cont:not('.cont-primary')").each(function(){ 
    target.append(jQuery('<input />').attr({
      name: "source_tickets[]",
      type: 'hidden',
      value: jQuery(this).find("#merge-ticket").data("id"),
      'class': 'src'
    }));
  });
}

jQuery('#search-type').change(function () {
    jQuery('.searchticket').hide();
    jQuery('.merge_results').hide();
    var type = jQuery('#search-type option:selected').val()
    jQuery('.searchticket').each(function(){
      jQuery(this).toggle(jQuery(this).hasClass(type));
    });
    if(jQuery('.'+type).find('.search_merge').val() != "")
      jQuery('#'+type+'_results').show() 
});

jQuery('.merge-cont:not(".cont-primary") #resp-icon').live("click",function(){
  var id = jQuery(this).closest("#contact-area").find("#merge-ticket").data("id");
  var element = jQuery('.contactdiv').find("[data-id = '"+id+"']").parent();
  element.find("#resp-icon").removeClass("clicked").parents('li').removeClass("clicked");
  jQuery(this).closest(".merge-cont").remove();
  enable_continue();
  change_ticket_count();
});

jQuery('.contactdiv').live("click",function(){
  if(!jQuery(this).find('#resp-icon').hasClass("clicked"))
  {
    jQuery(this).parent().addClass("clicked");
    var element = jQuery(".cont-primary").clone();
    append_to_merge_list(element, jQuery(this));
    element.find('.primary-marker').attr('title','Mark as primary').addClass('tooltip');
    replace_element = element.find('.item_info');
    var title =  replace_element.attr('title');
    var ticket_id = element.find("#merge-ticket").data("id")
    var replace_html = "<a class='item_info' target='_blank' title='"+title+"' href='/helpdesk/tickets/"+ticket_id+"'>"
                                                                                      +replace_element.text()+"</a>"
    replace_element.replaceWith(replace_html);
    enable_continue();
    change_ticket_count();
  }
});


jQuery(document).ready(function(){
  var primary_ticket = jQuery('.merge-cont').first();
  primary_ticket.addClass('cont-primary');
  primary_ticket.find('.primary-marker').attr('title','Primary ticket');
  enable_continue();
  initialize_autocompleter();
  check_requester();
});

function initialize_autocompleter(){
  ContactsSearch = new Template(
      '<li><div class="contactdiv" data-id="#{display_id}">'+
      '<span id="resp-icon"></span>'+
      '<div id="merge-ticket" class="merge_element" data-id="#{display_id}">'+
      '<span class="item_info" title="#{title}">##{display_id} #{subject}</span>'+
      '<div class="info-data hideForList">'+
      '<span class="merge-ticket-info">#{info}</span>'+
      '</div></div></div></li>'
  );
  bind_autocompleter();
}

function bind_autocompleter(){
  var idcachedBackend,requestercachedBackend,subjectcachedBackend;
  var idcachedLookup,requestercachedLookup,subjectcachedLookup;

  var autocompleter_hash = {  id :  { cache : idcachedLookup, backend : idcachedBackend, 
                                      searchBox : 'select-id', searchResults : 'display_id_results',
                                      minChars : 1 },
                  requester :  {  cache : requestercachedLookup, backend : requestercachedBackend, 
                                  searchBox : 'select-requester', searchResults : 'requester_results',
                                  minChars : 2 },
                  subject :  {  cache : subjectcachedLookup, backend : subjectcachedBackend, 
                                searchBox : 'select-subject', searchResults : 'subject_results',
                                minChars : 2 }
              }

  var aftershow = function(){
    var x = jQuery('.contactdiv');
    x.each(function(){
      y = jQuery(this);
      jQuery('.merge-cont #merge-ticket').each( function(){
        
        if(jQuery(this).data('id') == y.data('id'))
        {
          y.children('#resp-icon').addClass('clicked');
          y.addClass('clicked').parents('li').addClass('clicked');
        }
      });
    });
  }

  jQuery.each(autocompleter_hash, function(){
    this.backend = new Autocompleter.Cache(lookup, {choices: 15});
    this.cache = this.backend.lookup.bind(this.backend);
    global[this.searchBox] = new Autocompleter.PanedSearch( this.searchBox, this.cache, ContactsSearch,
    this.searchResults, $A([]), {frequency: 0.1, acceptNewValues: true,
    afterPaneShow: aftershow, minChars: this.minChars, separatorRegEx:/;|,/});
  })
}

function lookup(searchString, callback) { 
  var type = jQuery('#search-type option:selected').val();
  var list =  jQuery('#'+type+'_results').find('ul');
  list.empty();
  jQuery('#'+type+'_results').addClass("loading-center");
  new Ajax.Request('/helpdesk/merge_tickets/merge_search',
                    { 
                      parameters: {
                        search_string: searchString,
                        key: jQuery('#search-type option:selected').val(),
                        search_method: "with_"+jQuery('#search-type option:selected').val(),
                        rand: (new Date()).getTime()
                      },
                      onSuccess: function(response) {       
                        jQuery('.merge_results:visible').removeClass("loading-center");
                        callback(response.responseJSON.results);
                      } 
                    });
}

function change_ticket_count(){
  var subtitle = jQuery('.merge-sub-title');
  var count = ""+jQuery('.merge-cont').length
  var txt = count+(( count == 1 ) ? subtitle.data('defaultText') : subtitle.data('pluralizedText') )
  jQuery('.merge-sub-title').text(txt);
}  