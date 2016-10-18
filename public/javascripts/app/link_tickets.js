window.App = window.App || {};
window.App.Tickets = window.App.Tickets || {};
// link tracker name space 
window.App.Tickets.link_tracker =  {
  default_filter_type: 'subject',
  tracker_tkt_search: function(val) {
    if(val && val != ""){
      var filter_type = this.default_filter_type;
      jQuery.ajax({
        url: "/search/ticket_associations/filter/"+filter_type,
        type: 'POST',
        data: {
          term: val
        },
        dataType: "json",
        success: function(data){
          jQuery(".link_tracker_container .tracker_list").empty();
          jQuery('.result_label').text(search_results);
          if(data.results.length > 0){
            window.App.Tickets.link_tracker.manage_data(data);
          }else {
            jQuery(".link_tracker_container .tracker_list").removeClass("loading-block sloading loading-small");
            jQuery(".link_tracker_container .tracker_list").html("<div class='list-noinfo'>"+no_trackers+"</div>");
          }
          
        }
      });
    }else {
      App.Tickets.link_tracker.fetch_recent_trackers();
    }
  },
  fetch_recent_trackers: function() {
    jQuery(".link_tracker_container .tracker_list").empty();
    
    jQuery.ajax({
      url: "/search/ticket_associations/recent_trackers",
      type: 'POST',
      dataType: "json",
      success: function(data){
        jQuery(".link_tracker_container .tracker_list").empty();
        jQuery('.result_label').text(recently_created);
        if(data.results.length > 0){
          window.App.Tickets.link_tracker.manage_data(data);
        }else {
          jQuery('#initial_loading').removeClass('loading-block sloading loading-small loading-align').addClass('hide');
          jQuery(".link_tracker_container .tracker_list").removeClass("loading-block sloading loading-small");
          jQuery('.recent_tracker_notavailable').removeClass('hide');
          //jQuery(".link_tracker_container .tracker_list").html("<div class='list-noinfo'>No Matching Results</div>");
        }
        
      }
    });
  },
  manage_data: function(data){
    jQuery('#initial_loading').removeClass('loading-block sloading loading-small loading-align').addClass('hide');
    jQuery('.recent_trackers_available').removeClass('hide');
    var dataHtml = "";
    jQuery.each(data.results, function(index, item){
      dataHtml += '<li class="tracker-link" data-tracker-id="'+item.display_id+'">'+
                  '<b><p ><span class="link_tracker_ticket ellipsis">'+item.subject+'</span><span class="ticket_id">&nbsp;#'+item.display_id+'</span></p></b>'+
                  '<div class="actions">'+
                  '<a href="'+item.ticket_path+'" class="ficon-open-in-new-window tooltip" target="_blank" data-remote="true" rel="nofollow" data-original-title="'+view_tracker+'" twipsy-content-set="true"></a>'+
                  '<a class="ficon-link tooltip" href="#" data-original-title="'+link_text+'" twipsy-content-set="true"></a>'+
                  '</div>'+
                  '<small class="block user_det ellipsis">'+item.ticket_info+'</small>'+
                  '<small class="block"><span class="status_lbl">'+statusLabel+':</span> '+ item.ticket_status +'</small>'+
                  '</li>';
    }); 
    jQuery('#tracker_filter').focus();
    jQuery(".link_tracker_container .tracker_list").removeClass("loading-block sloading loading-small");
    jQuery(".link_tracker_container .tracker_list").html(dataHtml);
  },
  show_link_tracker_popup: function(popup_element){
    jQuery(popup_element).popover(options);
    if(!jQuery('.popover').is(':visible')){
      jQuery(popup_element).popover('toggle');
      App.Tickets.link_tracker.default_filter_type = jQuery('#SortTracker li.active a').data('filter');
      App.Tickets.link_tracker.fetch_recent_trackers();
    }else {
      jQuery(popup_element).popover('toggle');
    }
  },
  tracker_ticket_actions: function(item_id, title){
    if(jQuery('#related_tkts_view_freshdialog li[id^=related]:visible').length === 1){
      window.location.hash = "";
      jQuery('#related_tkts_view_freshdialog .close').trigger('click');
    } else {
      jQuery('#' + item_id).addClass('inline-flash');
      setTimeout(function(){
        jQuery('#' + item_id).fadeOut(500);
      }, 1000);
      jQuery('.modal-title').html(title);
    }
  },
  tracker_flash_widget: function(){
    jQuery('#link_tracker_box').addClass('inline-flash');
    setTimeout(function(){
      jQuery('#link_tracker_box').removeClass('inline-flash');
    }, 1000);
  }
};


// ----------------- EVENTS ------------------------------------\
jQuery(document).ready(function(){
  options = {
    html: true,
    trigger: 'manual',
    placement: 'below',
    container:'body',
    content: function() {
        return jQuery(".popover_content").html();
    }
  };

  var popup_element = '.lnk_tkt_tracker_show_dropdown';

  jQuery("body").on('click', 'li.tracker-link .ficon-link', function(e){
    e.preventDefault();
    
    var action = App.namespace === "helpdesk/tickets/index" ? "multiple" : jQuery('#lnk_tkt_tracker').data('ticket-id');
    var url = "/helpdesk/tickets/" + action + "/link";
    if(jQuery(e.target).is('a.link_tracker_ticket')){
      return;
    }
    if (App.namespace === "helpdesk/tickets/index") {
      helpdesk_submit(url, "put", [{name: 'tracker_id' ,  value: jQuery(this).closest('li').data('tracker-id')}])
    } else {
      jQuery('#lnk_tkt_tracker').popover('hide');
      jQuery('#link_tracker_box').addClass('linking').html("<p>"+linking_to_tracker+"</p><div class='sloading loading-small loading-block'></div>");
      jQuery.ajax({
        url: url,
        type:'PUT',
        dataType: "script",
        data: {
          "tracker_id" : jQuery(this).closest('li').data('tracker-id'),
          "id" : jQuery('#lnk_tkt_tracker').data('ticket-id')
        }
     });
    }
  });

  jQuery('body').on('click', '#related_ticket_dialog', function(e){
      jQuery('#related_tkts_view_freshdialog-content div').html("<div class='sloading loading-small loading-block'></div>");
      jQuery.ajax({
        url: '/helpdesk/tickets/'+jQuery(this).data('ticket-display-id')+'/related_tickets',
        type:'GET',
        contentType: "application/text",
        success: function(data){
          jQuery('#related_tkts_view_freshdialog-content div').html(data);
          var script = jQuery('#related_tkts_view_freshdialog-content script').text();
          eval(script);
        }
      });
  });

  jQuery('body').on('mousemove', '.tracker-link', function(e){
    var user_details = jQuery(this).children('.user_det');
    jQuery(user_details).addClass('truncate_line');
  });

  jQuery('body').on('mouseleave', '.tracker-link', function(e){
    var user_details = jQuery(this).children('.user_det');
    jQuery(user_details).removeClass('truncate_line');
  });

  //close popover when clicked on body
  jQuery(document).on('click', function(e){
    if(jQuery('.popover.bottomLeft').is(':visible')){
      jQuery(popup_element).popover('toggle');
    }
    jQuery('.recent_trackers_available').addClass('hide');
    jQuery('.recent_tracker_notavailable').addClass('hide');
  });

  //do not hide popover when clicked inside the popover container
  jQuery('body').on('click', '.popover', function(e){
    e.stopPropagation();
    if(jQuery('#SortTracker').is(':visible')){
      jQuery('#SortTracker').css('display', 'none');
    }
  });

  jQuery('body').on('click', '.popover .nav-trigger', function(e){
    if(!jQuery("#SortTracker li.active").length > 0){
      jQuery("#SortTracker li.active").removeClass("active");
      jQuery('#SortTracker li span').removeClass('icon ticksymbol');
      jQuery("#SortTracker li:first-child").addClass("active");
      jQuery('#SortTracker li:first-child span').addClass('icon ticksymbol');
    }
    e.stopPropagation();
  });
  
  jQuery(popup_element).popover(options);
  // show link tracker dialog box
  jQuery('body').off('click', '.link_tracker_box .lnk_tkt_tracker_show_dropdown');
  jQuery('body').on("click", '.link_tracker_box .lnk_tkt_tracker_show_dropdown', function(e) {
    e.preventDefault();
    e.stopPropagation();
    App.Tickets.link_tracker.show_link_tracker_popup(popup_element);
  });

  // realod link tracker results on changing filter
  jQuery("body").on("click", '#SortTracker li a', function(e) {
    e.preventDefault();
    e.stopPropagation();
    jQuery("#SortTracker li.active").removeClass("active");
    jQuery('#SortTracker li span').removeClass('icon ticksymbol');
    jQuery(this).parent().addClass('active');
    jQuery('#SortTracker li.active span').addClass('icon ticksymbol');
    jQuery(this).closest('#SortTracker').css('display', 'none');
    var placeholderText = search_label+" "+jQuery(this).text().trim().toLowerCase();
    jQuery('#tracker_filter').attr('placeholder', placeholderText);
    App.Tickets.link_tracker.default_filter_type = jQuery(this).data('filter');
    if(jQuery('#tracker_filter').val() && jQuery('#tracker_filter').val() != ""){
      jQuery(".link_tracker_container .tracker_list").empty();
      jQuery(".link_tracker_container .tracker_list").addClass("loading-block sloading loading-small");
      App.Tickets.link_tracker.tracker_tkt_search(jQuery('#tracker_filter').val());
    }
  });

  // realod link tracker results on changing filter search param
  jQuery("body").on("keyup", "#tracker_filter", function() {
    jQuery(".link_tracker_container .tracker_list").empty();
    jQuery(".link_tracker_container .tracker_list").addClass("loading-block sloading loading-small");
    App.Tickets.link_tracker.default_filter_type = jQuery('#SortTracker li.active a').data('filter');
    if(jQuery(this).val() != ""){
      jQuery('.clear_search').css('visibility', 'visible');
    }else{
      jQuery('.clear_search').css('visibility', 'hidden');
    }
    App.Tickets.link_tracker.tracker_tkt_search(jQuery(this).val());
  });

  jQuery('body').on('click', '.clear_search', function(e){
    jQuery('#tracker_filter').val("");
    jQuery('.clear_search').css('visibility', 'hidden');
    App.Tickets.link_tracker.tracker_tkt_search(jQuery('#tracker_filter').val());
  });

  //unlink function
  jQuery("body").on("click", '#confirm_unlink_ticket', function(e){
    e.preventDefault();
    jQuery('[id^=unlink_from_tracker]').modal('hide');
    jQuery('#link_tracker_box').addClass('linking').html("<p>"+unlinking_from_tracker+"</p><div class='sloading loading-small loading-block'></div>");
    jQuery.ajax({
      url: '/helpdesk/tickets/'+jQuery(this).val()+'/unlink',
      type:'PUT',
      dataType: "script",
      data: {"tracker_id" : jQuery(this).data('tracker-id'),
      "tracker" : jQuery(this).data('tracker')}
    });
  });



  //close unlink confirm dialog on cancel
  jQuery('body').on("click", "#cancel_unlink", function(e){
    e.preventDefault();
    e.stopPropagation();
    jQuery('[id^=unlink_from_tracker]').modal('hide');
  });

  jQuery('body').on('mousemove', '#related_tkts_view_freshdialog', function(e){
    jQuery('body').addClass('preventscroll');
  });

  jQuery('body').on('mouseleave', '#related_tkts_view_freshdialog', function(e){
    jQuery('body').removeClass('preventscroll');
  });
});