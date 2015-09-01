var tktDetailDom = tktDetailDom || {};

(function(tdd){

  var id_map = {
    "reply" : "ReplyButton",
    "forward" : "FwdButton",
    "add-note" : "noteButton",
    "close" : "close_ticket_btn",
    "merge" : "ticket_merge_btn",
    "update": "helpdesk_ticket_submit_dup",
    "ticket-properties": "TicketProperties",
    "to-do": "ToDoList",
    "time-tracked": "TimesheetTab"
  }

  // Declare required dom manipulations for ticket details page.

  tdd.openReplyBox = function(options){
    jQuery('#ReplyButton').trigger("click");
    if(options.content) jQuery("#cnt-reply-body").insertHtml(options.content);
  }

  tdd.hideTicketDelete = function(){
    jQuery('#reply_options li:last').hide();
  }

  tdd.showTicketDelete = function(){
    jQuery('#reply_options li:last').show();
  }

  tdd.hideAttachments = function(){
    jQuery('.attachments-wrap').hide();
  }

  tdd.showAttachments = function(){
    jQuery('.attachments-wrap').show();
  }

  tdd.triggerClick = function(options){
    var id = id_map[options.element];
    if(typeof id == "string")
      jQuery('#'+id).trigger('click');
    else
      console.log('Invalid Element');
  }

  tdd.triggerReload = function(options){
    var id = id_map[options.element];
    if(typeof id == "string")
    {
      var reload_element = jQuery('#'+id);
      var reload_url;
      if(id == 'time-tracked')
      {
        reload_url = window.location.pathname +'/time_sheets';
      }
      else
      {
        reload_url = reload_element.find('div.content').attr('data-remote-url');
      }
      reload_element.find('.content').remove();
      reload_element.addClass('load_remote inactive').append('<div class="content" rel="remote" data-remote-url="'+ reload_url +'"></div>');
      reload_element.trigger('click');
    }
    else
      console.log('Invalid Element');
  }

  tdd.addOptionToMoreDropdown = function(options){
    if (options.anchor_tag){
      var markup = "<li>" + options.anchor_tag + "</li>";
      jQuery('ul#reply_options').append(markup);
    }
  }

  tdd.addCustomButton = function(options){
    if (options.anchor_tag){
      var a = jQuery(options.anchor_tag)
      a.addClass("btn");
      markup = '<li class="ticket-btns hide_on_collapse">' + a.prop('outerHTML') + '</li>';
      jQuery('div.ticket-actions ul').first().append(markup);
    }
  }

  tdd.appendToSidebar = function(options){
    options.markup && jQuery('div#ticket_details_sidebar').append(options.markup);
  }


})(tktDetailDom);
