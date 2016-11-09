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
          var $tracker_list = jQuery(".link_tracker_container .tracker_list");
          $tracker_list.empty();
          jQuery('.result_label').text(search_results);
          if(data.results.length > 0){
            window.App.Tickets.link_tracker.manage_data(data);
          }else {
            $tracker_list.removeClass("loading-block sloading loading-small");
            $tracker_list.html("<div class='list-noinfo'>"+no_trackers+"</div>");
          }

        }
      });
    }else {
      App.Tickets.link_tracker.fetch_recent_trackers();
    }
  },
  fetch_recent_trackers: function() {
    var $tracker_list = jQuery(".link_tracker_container .tracker_list");
    $tracker_list.empty();

    jQuery.ajax({
      url: "/search/ticket_associations/recent_trackers",
      type: 'POST',
      dataType: "json",
      success: function(data){
        $tracker_list.empty();
        jQuery('.result_label').text(recently_created);
        if(data.results.length > 0){
          window.App.Tickets.link_tracker.manage_data(data);
        }else {
          jQuery('#initial_loading').removeClass('loading-block sloading loading-small loading-align').addClass('hide');
          $tracker_list.removeClass("loading-block sloading loading-small");
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
    var $tracker_list = jQuery(".link_tracker_container .tracker_list");
    $tracker_list.removeClass("loading-block sloading loading-small");
    $tracker_list.html(dataHtml);
  },
  show_link_tracker_popup: function(popup_element){
    jQuery(popup_element).popover(link_options);
    if(!jQuery('.popover').is(':visible')){
      jQuery(popup_element).popover('toggle');
      App.Tickets.link_tracker.default_filter_type = jQuery('#SortTracker li.active a').data('filter');
      App.Tickets.link_tracker.fetch_recent_trackers();
    }else {
      jQuery(popup_element).popover('toggle');
    }
  },
  show_parent_child_popup: function(add_popup_element){
    link_popup = jQuery(add_popup_element).popover(add_options);
    if(!jQuery('.popover').is(':visible')){
      jQuery(add_popup_element).popover('toggle');
    }else {
      jQuery(add_popup_element).popover('toggle');
      App.Tickets.link_tracker.show_template_select();
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
  },
  fetch_parent_templates: function(){
    var recent_templates = App.Tickets.link_tracker.getRecentTemplate();
    var recent_templates_array = JSON.parse(recent_templates);
    var params = {'only_parent': 'only_parent'};
    if(recent_templates_array.length > 0){
      params.recent_ids = recent_templates;
    }
    var $recent = jQuery('.recent_templates');
    var $all_templates = jQuery('.all_templates');
    jQuery('.dark_dashed').show();
    $recent.show();
    jQuery('.result_label_container').show();
    jQuery('.result_label_container').text("Recently Used");

    jQuery.ajax({
      url: "/helpdesk/tickets/accessible_templates",
      data: params,
      success: function(data){
        if(data.all_acc_templates.length > 0 || data.recent_templates.length > 0){
          $recent.removeClass('loading-block sloading loading-small').html(App.Tickets.link_tracker.constructHtmlData(data.recent_templates));
          $all_templates.removeClass('loading-block sloading loading-small').html(App.Tickets.link_tracker.constructHtmlData(data.all_acc_templates));
        }else{
          $recent.removeClass('loading-block sloading loading-small');
          $all_templates.removeClass('loading-block sloading loading-small').html("<p class='no_parent'>"+no_parent_template+"</p>");
        }

        if(!data.recent_templates.length > 0){
          $recent.hide();
          jQuery('.dark_dashed').hide();
          jQuery('.result_label_container').hide();
        }
      }
    });
  },
  constructHtmlData: function(inputArray){
    var dataHtml = "";
    jQuery.each(inputArray, function(index, item){
      dataHtml += '<li class="" data-tracker-id="'+item.id+'">'+item.name+'</li>';
    });
    return dataHtml;
  },
  show_template_select: function(){
    jQuery('.selecet_template').removeClass('hide');
    jQuery('.existing_template_list').addClass('hide');
  },
  search_parent_templates: function(val){
    jQuery('.recent_templates').empty().hide();
    jQuery('.dark_dashed').hide();
    jQuery('.result_label_container').text("Search Results");

    jQuery.ajax({
      url: "/helpdesk/tickets/search_templates?search_string="+val+"&only_parent='only_parent'",
      type: 'GET',
      dataType: "json",
      success: function(data){
        if(data.all_acc_templates.length > 0){
          jQuery(".all_templates").removeClass('loading-block sloading loading-small').html(App.Tickets.link_tracker.constructHtmlData(data.all_acc_templates));
        }else{
          jQuery('.all_templates').removeClass('loading-block sloading loading-small').html("<p class='no_parents'>"+no_matching_template+"</p>");
        }
      }
    });
  },
  fetch_child_templates: function(val){
    jQuery.ajax({
      url: "/helpdesk/tickets/show_children?parent_templ_id="+val,
      type: 'GET',
      contentType: "application/text",
      success: function(data){
        if(parent_container && parent_container === 'tracker-label'){
          jQuery('.tracker_label').removeClass('.loading-block sloading loading-small');
          jQuery('.tracker_label').append(data);
        }else{
          jQuery('.link_tracker_box').removeClass('.loading-block sloading loading-small');
          jQuery('.link_tracker_box').append(data);
        }

        if(jQuery('#no_child_message').length > 0){
          setTimeout(function(){
            if(parent_container && parent_container === 'tracker-label'){
              jQuery('.tracker_label .tree').remove();
              jQuery('.tracker_label #add_child_tkt').show();
            }else{
              jQuery('.link_tracker_box .tree').remove();
              jQuery('.link_tracker_box .link_ticket_text').show();
            }
          }, 5000);
        }

      }
    });
  },
  create_bulk_children: function(child_tmpl_ids){
    var params = {};
    params.assoc_parent_id = jQuery('#add_child_tkt').data('ticket-id');
    params.parent_templ_id = jQuery('.parent_det').data('parent-template-id');
    params.child_ids = child_tmpl_ids;
    if(parent_container && parent_container === 'tracker-label'){
      jQuery('#link_tracker_box .row-fluid').hide();
    }else{
      jQuery('.link_tracker_box .link_ticket_text').hide();
    }
    jQuery('#link_tracker_box .tree').remove();
    jQuery('#link_tracker_box').addClass('linking').append("<div class='loader_div'><p>Creating child templates</p><div class='sloading loading-small loading-block'></div></div>");

    jQuery.ajax({
      url: "/helpdesk/tickets/bulk_child_tkt_create",
      type: 'POST',
      dataType: 'json',
      data: params,
      success: function(data){
        jQuery("#noticeajax").html(data.msg).show();
        closeableFlash('#noticeajax');
        jQuery(document).scrollTop(0);
        if(parent_container && parent_container === 'tracker-label'){
          jQuery('#link_tracker_box .row-fluid').show();
          jQuery('.link_tracker_box .tracker_label #add_child_tkt').show();
        }else{
          jQuery('.link_tracker_box .link_ticket_text').show();
        }
        jQuery('#link_tracker_box').removeClass('linking');
        jQuery('#link_tracker_box .loader_div').remove();
      }
    });
  },
  setSelectedParents: function(id){
    if(window.localStorage){
      var recent = localStorage.getItem('recent-parent-tmpl') ? JSON.parse(localStorage.getItem('recent-parent-tmpl')) : [],
      templateIndex = recent.indexOf(id);
      if(recent.length > 10){
        recent.pop();
      }
      if(templateIndex === -1){
        recent.unshift(id);
      }else{
        recent.splice(templateIndex, 1);
        recent.unshift(id);
      }
      localStorage.setItem('recent-parent-tmpl', Browser.stringify(recent));
    }
  },
  getRecentTemplate: function(){
    if(window.localStorage && localStorage.getItem('recent-parent-tmpl')){
      return localStorage.getItem('recent-parent-tmpl');
    }else{
      return "[]";
    }
  }
};


// ----------------- EVENTS ------------------------------------\
jQuery(document).ready(function(){
  function configureOptions(selector){
    options = {
      html: true,
      trigger: 'manual',
      placement: 'below',
      container:'body',
      content: function() {
          return jQuery(selector).html();
      }
    };

    return options;
  }

  link_options = configureOptions(".popover_content.link_tracker_data");
  add_options = configureOptions(".popover_content.add_child_data");


  var link_popup_element = '#lnk_tkt_tracker';
  var add_popup_element = '#add_child_tkt';

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
        url: '/helpdesk/tickets/'+jQuery(this).data('ticket-display-id')+'/associated_tickets',
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
      jQuery(link_popup_element).popover('hide');
      jQuery(add_popup_element).popover('hide');
    }
    jQuery('.recent_trackers_available').addClass('hide');
    jQuery('.recent_tracker_notavailable').addClass('hide');
    jQuery('.selecet_template').removeClass('hide');
    jQuery('.existing_template_list').addClass('hide');
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

  jQuery(link_popup_element).popover(link_options);
  jQuery(add_popup_element).popover(add_options);
  // show link tracker dialog box
  jQuery('body').off('click', '.link_tracker_box .lnk_tkt_tracker_show_dropdown');
  jQuery('body').on("click", '.link_tracker_box .lnk_tkt_tracker_show_dropdown', function(e) {
    e.preventDefault();
    e.stopPropagation();
    var action = jQuery(this).data('trigger');
    if(action === 'link_tracker'){
      jQuery(add_popup_element).popover('hide');
      App.Tickets.link_tracker.show_link_tracker_popup(link_popup_element);
    }else{
      jQuery(link_popup_element).popover('hide');
      parent_container = jQuery(this).data('parent');
      App.Tickets.link_tracker.show_parent_child_popup(add_popup_element);
    }
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
      jQuery(".link_tracker_container .tracker_list").empty().addClass("loading-block sloading loading-small");
      App.Tickets.link_tracker.tracker_tkt_search(jQuery('#tracker_filter').val());
    }
  });

  // realod link tracker results on changing filter search param
  jQuery("body").on("keyup", "#tracker_filter", function() {
    jQuery(".link_tracker_container .tracker_list").empty().addClass("loading-block sloading loading-small");
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

  jQuery('body').on('click', '.modal#related_tkts_view_freshdialog .close', function(e){
    console.log("sbfbnfb");
    if(window.location.hash === '#associated'){
      window.location.hash = "";
    }
  });

  // ----------------- PARENT_CHILD ------------------------------------\

  //init local storage
  var initarray = [];
  if(window.localStorage && !localStorage.getItem('recent-parent-tmpl')){
    localStorage.setItem('recent-parent-tmpl', Browser.stringify(initarray));
  }

  jQuery('body').on('change', '.select_child', function(e){
    jQuery(this).parent().toggleClass('active');
  });

  jQuery('body').on('click', '#create_child_templates', function(e){
    var selected_child_template_ids = [];
    jQuery('.child_template_items.active').each(function(){
      var id = jQuery(this).data('template-id');
      selected_child_template_ids.push(id);
    });
    App.Tickets.link_tracker.create_bulk_children(selected_child_template_ids);
  });

  jQuery('body').on('click', '.add_child_link', function(e){
    if(jQuery(this).data('trigger') === 'existing'){
      jQuery('.selecet_template').addClass('hide');
      jQuery('.existing_template_list').removeClass('hide');
      jQuery('.recent_templates, .all_templates').empty().addClass("loading-block sloading loading-small");
      App.Tickets.link_tracker.fetch_parent_templates();
    }else{
      window.location.href = jQuery(this).data('url');
    }
  });

  jQuery("body").on("keyup", "#template_search", function() {
    jQuery(".all_templates").empty();
    jQuery(".all_templates").addClass("loading-block sloading loading-small");
    if(jQuery(this).val() !== ""){
      App.Tickets.link_tracker.search_parent_templates(jQuery(this).val());
    }else{
      App.Tickets.link_tracker.fetch_parent_templates();
    }
  });

  jQuery('body').on('click', '.all_templates li , .recent_templates li', function(e){
    App.Tickets.link_tracker.setSelectedParents(jQuery(this).data('tracker-id'));
    jQuery(add_popup_element).popover('toggle');
    App.Tickets.link_tracker.show_template_select();
    if(parent_container && parent_container === 'tracker-label'){
      jQuery('.link_tracker_box .tracker_label #add_child_tkt').hide();
      jQuery('.tracker_label').addClass('.loading-block sloading loading-small');
    }else{
      jQuery('.link_tracker_box .link_ticket_text').hide();
      jQuery('.link_tracker_box').addClass('.loading-block sloading loading-small');
    }

    App.Tickets.link_tracker.fetch_child_templates(jQuery(this).data('tracker-id'));
  });

  jQuery('body').on('click', '#cancel_create_child', function(e){
    e.preventDefault();
    if(parent_container && parent_container === 'tracker-label'){
      jQuery('.tracker_label .tree').remove();
      jQuery('.tracker_label #add_child_tkt').show();
    }else{
      jQuery('.link_tracker_box .tree').remove();
      jQuery('.link_tracker_box .link_ticket_text').show();
    }
  });

  jQuery('body').on('mouseleave', '#related_tkts_view_freshdialog', function(e){
    jQuery('body').removeClass('preventscroll');
  });
});