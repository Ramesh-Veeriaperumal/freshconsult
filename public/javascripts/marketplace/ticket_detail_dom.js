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
  },

  getTicketInfo: function(){
    return dom_helper_data;
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

  onReplyClick: function(callback) {
    var _that = this;
    jQuery('body').on('click.ticket_details', '[data-note-type="reply"]', function() {
      _that.executeCallback(callback);
    });
  },

  onFwdClick: function(callback) {
    var _that = this;
    jQuery('body').on('click.ticket_details', '[data-note-type="fwd"]', function() {
      _that.executeCallback(callback);
    });
  },

  onAddNoteClick: function(callback) {
    var _that = this;
    jQuery('body').on('click.ticket_details', '[data-note-type="note"]', function() {
      _that.executeCallback(callback);
    });
  },

  onSubmitClick: function(callback) {
    var _that = this;
    jQuery('body').on('submit', '.request_panel:visible form', function(ev){
      _that.executeCallback(callback);
    });
  },

  onTicketCloseClick: function(callback) {
    var _that = this;
    jQuery('body').on('click.ticket_details', '#close_ticket_btn', function() {
      _that.executeCallback(callback);
    });
  },

  onNextTicketClick: function(callback) {
    var _that = this;
    jQuery('body').on('click.ticket_details', '.next_page', function() {
      _that.executeCallback(callback);
    });
  },

  onPrevTicketClick: function(callback) {
    var _that = this;
    jQuery('body').on('click.ticket_details', '.prev_page', function() {
      _that.executeCallback(callback);
    });
  },

  onPriorityChanged: function(callback) {
    var _that = this;
    jQuery('body').on('change.ticket_details', "#helpdesk_ticket_priority", function() {
      _that.executeCallback(callback);
    });
  },

  onStatusChanged: function(callback) {
    var _that = this;
    jQuery('body').on('change.ticket_details', "#helpdesk_ticket_status", function() {
      _that.executeCallback(callback);
    });
  },

  onSourceChanged: function(callback) {
    var _that = this;
    jQuery('body').on('change.ticket_details', "#helpdesk_ticket_source", function() {
      _that.executeCallback(callback);
    });
  },

  onGroupChanged: function(callback) {
    var _that = this;
    jQuery('body').on('change.ticket_details', "#helpdesk_ticket_group_id", function() {
      _that.executeCallback(callback);
    });
  },

  onAgentChanged: function(callback) {
    var _that = this;
    jQuery('body').on('change.ticket_details', "#helpdesk_ticket_responder_id", function() {
      _that.executeCallback(callback);
    });
  },

  onTypeChanged: function(callback) {
    var _that = this;
    jQuery('body').on('change.ticket_details', "#helpdesk_ticket_ticket_type", function() {
      _that.executeCallback(callback);
    });
  },

  onTicketPropertiesUpdated: function(callback) {
    var _that = this;
    jQuery('body').on('click.ticket_details', '#helpdesk_ticket_submit, #helpdesk_ticket_submit_dup', function() {
      _that.executeCallback(callback);
    });
  },

  executeCallback: function(callback) {
    if(callback) {
      callback.call();
    }
  },

  destroy: function(){
    dom_helper_data = {};
    jQuery(document, 'body').off("click submit");
    jQuery(document, 'body').off(".ticket_details");
    //need to clear all sorts of data manipulations when navigating away.
  }
});
var tktDetailDom = new TktDetailDom();