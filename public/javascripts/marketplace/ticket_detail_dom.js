var TktDetailDom = Class.create({
  initialize: function() {
    this.id_map = {
      "reply" : "ReplyButton",
      "forward" : "FwdButton",
      "add-note" : "noteButton",
      "close" : "close_ticket_btn",
      "update": "helpdesk_ticket_submit_dup",
      "ticket-properties": "TicketProperties",
      "to-do": "ToDoList",
      "time-tracked": "TimesheetTab"
    };
    
    jQuery(window).on("message.extn", this.receiveFAMessage.bindAsEventListener(this));

    var custom_events = [
      "time_entry_deleted",
      "time_entry_created",
      "time_entry_started",
      "time_entry_stopped",
      "time_entry_updated",
      "todo_created",
      "todo_completed",
      "note_created",
      "note_updated",
      "ticket_fields_updated",
      "scenario_executed",
      "ticket_show_more",
      "activities_toggle",
      "ticket_view_loaded",
      "ticket_view_unloaded",
      "sidebar_loaded",
      "watcher_added",
      "watcher_removed"
    ];

    for(var i=0; i < custom_events.length; i++){
      jQuery(document).on(custom_events[i], this.onDomCustomEvent.bindAsEventListener(this));
    }
  },

  onDomCustomEvent: function(event){
    var evt_name = event.type;
    var msg = {
      action: event.type,
      type: "FA_CUSTOM_EVENTS"
    }
    window.postMessage(msg, "*");
  },
  //for ticket details dom related page
  getTicketInfo: function(opt){
    if(opt){
      var msg_for_extn = {
        dom_helper_data: dom_helper_data,
        type: "FA_FROM_HK"
      }
      window.postMessage(msg_for_extn, "*");
    }
    else{
      return dom_helper_data;
    }
  },
  
  receiveFAMessage: function(event){
    var data = event.originalEvent.data;
    if(page_type == "ticket"){
      if(data.type == "FA_DOM_EVENTS") {
        method = data.action;
        this[method](data.txt);
      } 
      else if(data.type == "FA_TO_HK"){
        this.getTicketInfo(data.txt);
      }
    }
  },

  openReply: function(options){
    jQuery('#ReplyButton').trigger("click");
    if(options){
      jQuery("#cnt-reply-body").insertHtml(options);
    }
  },

  openNote: function(options){
    jQuery('#noteButton').trigger("click");
    if(options){
      jQuery("#cnt-note-body").insertHtml(options);
    }
  },

  expandConversations: function(){
    jQuery("#show_more").click();
  },

  hideTicketDelete: function(){
    this.getElement("ul#collapse-list", function() {
      jQuery('ul#collapse-list').find("a[data-method='delete']").hide();
    });
  },

  showTicketDelete: function(){
    this.getElement("ul#collapse-list", function() {
      jQuery('ul#collapse-list').find("a[data-method='delete']").show();
    });
  },

  hideAttachments: function(){
    jQuery('.attachments-wrap').hide();
  },
  
  showAttachments: function(){
    jQuery('.attachments-wrap').show();
  },

  //can be used for both tkt details n contact page
  triggerClick: function(options){
    var id = this.id_map[options];
    if(typeof id == "string")
      jQuery('#'+id).trigger('click');
    else
      console.log('Invalid Element');
  },

  triggerReload: function(options){
    var id = this.id_map[options];
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
  },

  addExtraOption: function(options){
    if (options){
      var markup = "<li>" + options + "</li>";
      this.getElement('ul#collapse-list', function() {
        jQuery('ul#collapse-list').append(markup);
      });
    }
  },

  addCustomButton: function(options){
    if (options){
      var a = jQuery(options)
      a.addClass("btn");
      markup = '<li class="ticket-btns hide_on_collapse">' + a.prop('outerHTML') + '</li>';
      jQuery('div.ticket-actions ul').first().append(markup);
    }
  },

  appendToSidebar: function(options){
    if(options) {
      jQuery('div#ticket_details_sidebar').append(options);
    }
  },

  getElement: function(selector, callback_fn) {
    var el = jQuery(selector);
    if(el) {
      callback_fn.call(this)
    } else {
      setTimeout(function(){
        callback_fn.call(this);
      }, 2000);
    }
  },

  destroy: function(){
    dom_helper_data = {};
    //need to clear all sorts of data manipulations when navigating away.
  }
});
var tktDetailDom = new TktDetailDom();