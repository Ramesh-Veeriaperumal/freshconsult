var TktDetailDom = Class.create({
  initialize: function() {
    this.id_map = {
      "reply" : "reply-button",
      "forward" : "fwd-button",
      "add-note" : "note-button",
      "close" : "ticket-close-btn",
      "update": "ticket-properties-update-dup",
      "ticket-properties": "ticket-properties",
      "to-do": "todo-list",
      "time-tracked": "timesheet-tab"
    };
  },

  getTicketInfo: function(){
    return dom_helper_data;
  },

  getContactInfo: function() {
      return requester;
  },

  getCustomField: function() {
    return dom_helper_data.helpdesk_ticket.custom_field;
  },

  openReply: function(options){
    if(jQuery("[data-domhelper-name='reply-button']").length){
      jQuery("[data-domhelper-name='reply-button']").trigger("click");  
      if(options){
        var tktInfo = domHelper.ticket.getTicketInfo().helpdesk_ticket;
        switch(tktInfo.source_name) {
          case "Twitter":
          case "Facebook":
          case "Ecommerce":
          case "MobiHelp":
            jQuery("[data-domhelper-name='content-body']").val(jQuery("[data-domhelper-name='content-body']").val() + options);
            break;
          default:
            jQuery("[data-domhelper-name='cnt-reply-body']").insertHtml(options);
        }
      }
    }
  },

  openNote: function(options){
    jQuery("[data-domhelper-name='note-button']").trigger("click");
    if(options){
      jQuery("[data-domhelper-name='cnt-note-body']").insertHtml(options);
    }
  },

  expandConversations: function(){
    jQuery("[data-domhelper-name='show-more']").click();
  },

  hideTicketDelete: function(){
    this.getElement("more-collapse-list", function() {
      jQuery("[data-domhelper-name='ticket-delete-btn']").hide();
    });
  },

  showTicketDelete: function(){
    this.getElement("more-collapse-list", function() {
      jQuery("[data-domhelper-name='ticket-delete-btn']").show();
    });
  },

  hideAttachments: function(){
    jQuery("[data-domhelper-name='attachments-wrap']").hide();
  },

  showAttachments: function(){
    jQuery("[data-domhelper-name='attachments-wrap']").show();
  },

  //can be used for both tkt details n contact page
  triggerClick: function(options){
    var id = this.id_map[options];
    if(typeof id == "string")
      jQuery("[data-domhelper-name='" + id + "']").trigger('click');
    else
      console.error(domHelperValidator.errorMessageMap["invalidElement"], options, "triggerClick");
  },

  triggerReload: function(options){
    var id = this.id_map[options];
    if(typeof id == "string")
    {
      var reload_element = jQuery("[data-domhelper-name='" + id + "']");
      var reload_url;
      if(id == 'timesheet-tab')
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
      console.error(domHelperValidator.errorMessageMap["invalidElement"], options, "triggerReload");
  },

  addExtraOption: function(options){
    if (options){
      var markup = "<li>" + options + "</li>";
      this.getElement('collapse-list', function() {
        jQuery("[data-domhelper-name='more-collapse-list']").append(markup);
      });
    }
  },

  addCustomButton: function(options){
    if (options){
      var a = jQuery(options)
      a.addClass("btn");
      markup = '<li class="ticket-btns hide_on_collapse">' + a.prop('outerHTML') + '</li>';
      jQuery("[data-domhelper-name='ticket-action-options']").append(markup);
    }
  },

  appendToSidebar: function(options){
    if(options) {
      jQuery("[data-domhelper-name='ticket-details-sidebar']").append(options);
    }
  },

  getElement: function(domhelperName, callback_fn) {
    var el = jQuery("[data-domhelper-name='" + domhelperName + "']");
    if(el) {
      callback_fn.call(this)
    } else {
      setTimeout(function(){
        callback_fn.call(this);
      }, 2000);
    }
  },

  onReplyClick: function(callback) {
    // error in phone type -- without reply
    var _that = this;
    jQuery("[data-domhelper-name='reply-button'], [data-domhelper-name='reply-sticky-button']").on('click.ticket_details', function(e) {
      _that.executeCallback(callback, e);
    });
  },

  onFwdClick: function(callback) {
    // error in phone type -- without reply
    var _that = this;
    jQuery("[data-domhelper-name='fwd-button'], [data-domhelper-name='fwd-sticky-button']").on('click.ticket_details', function(e) {
      _that.executeCallback(callback, e);
    });
  },

  onAddNoteClick: function(callback) {
    var _that = this;
    jQuery("[data-domhelper-name='note-button'], [data-domhelper-name='note-sticky-button']").on('click.ticket_details', function(e) {
      _that.executeCallback(callback, e);
    });
  },

  onSubmitClick: function(callback, what) {
    var $this = this;
    jQuery.each( what, function( index, value ) {
      switch (value) {
        case "reply":
          $this.onReplySubmit(callback);
          break;
        case "forward":
          $this.onFwdSubmit(callback);
          break;
        case "note":
          $this.onNoteSubmit(callback);
          break;
        default:
          console.error(domHelperValidator.errorMessageMap["invalidArgumentValue"],value, "onSubmitClick");
          break;
      }
    });
  },

  showConfirm: function(evt, title, msg, ok_label, cancel_label, success_cb, failure_cb){
    var _that = this,
        copy = jQuery.extend(true, {}, evt);
    evt.preventDefault();
    evt.stopPropagation();

    jQuery('body').append('<div id="dataConfirmModal" class="modal" role="dialog" aria-labelledby="dataConfirmLabel" aria-hidden="true"><div class="modal-header"><button type="button" class="close" data-dismiss="modal" aria-hidden="true"></button><h3 id="dataConfirmLabel">'+ title +'</h3></div><div class="modal-body">'+msg+'</div><div class="modal-footer"><button class="btn" data-dismiss="modal" aria-hidden="true" id="dataConfirmCancel">'+cancel_label+'</button><a class="btn btn-primary" id="dataConfirmOK">'+ok_label+'</a></div></div>');
    jQuery('#dataConfirmModal').modal({show:true});

    jQuery('#dataConfirmCancel').on('click', function (e) {
      jQuery('#dataConfirmModal').modal('hide');
      _that.executeCallback(failure_cb, e);
      //return false;
    });

    jQuery("#dataConfirmOK").on("click", function (e){
      jQuery(copy.target.parentNode).trigger(copy);
      _that.executeCallback(success_cb, e);
      jQuery('#dataConfirmModal').modal('hide');
    });

    jQuery('#dataConfirmModal').on('hidden', function (e) {
      jQuery('#dataConfirmModal').remove();
      return false;
    });
  },

  showModal: function(evt, title, msg, ok_label, success_cb){
    var _that = this,
        copy = jQuery.extend(true, {}, evt);
    evt.preventDefault();
    evt.stopPropagation();

    jQuery('body').append('<div id="dataConfirmModal" class="modal" role="dialog" aria-labelledby="dataConfirmLabel" aria-hidden="true"><div class="modal-header"><h3 id="dataConfirmLabel">'+ title +'</h3></div><div class="modal-body">'+msg+'</div><div class="modal-footer"><a class="btn btn-primary" id="dataConfirmOK">'+ok_label+'</a></div></div>');
    jQuery('#dataConfirmModal').modal({show:true});

    jQuery("#dataConfirmOK").on("click", function(e){
      jQuery(copy.target.parentNode).trigger(copy);
      _that.executeCallback(success_cb, e);
      jQuery('#dataConfirmModal').modal('hide');
    });

    jQuery('#dataConfirmModal').on('hidden', function (e) {
      jQuery('#dataConfirmModal').remove();
      return false;
    });
  },

  onReplySubmit: function(callback) {
    var _that = this;
    // error in phone type -- without reply
    var tktInfo = domHelper.ticket.getTicketInfo().helpdesk_ticket;
      switch(tktInfo.source_name) {
        case "Twitter":
        case "Facebook":
        case "Ecommerce":
        case "MobiHelp":
          jQuery("[data-domhelper-name='cnt-reply-form']").on("submit", function(ev) {
            _that.executeCallback(callback, ev);
          });
          break;
        default:
          jQuery("[data-domhelper-name='cnt-reply']").on("submit", function(ev) {
            _that.executeCallback(callback, ev);
          });
      }
    
  },

  onFwdSubmit: function(callback) {
    var _that = this;
    jQuery("[data-domhelper-name='cnt-fwd']").on("submit", function(ev) {
      _that.executeCallback(callback, ev);
    });
  },

  onNoteSubmit: function(callback) {
    var _that = this;
    jQuery("[data-domhelper-name='cnt-note']").on("submit", function(ev) {
      _that.executeCallback(callback, ev);
    });
  },

  onTicketCloseClick: function(callback) {
    var _that = this;
    jQuery("[data-domhelper-name='ticket-close-btn']").on("click.ticket_details", function(ev) {
      _that.executeCallback(callback, ev);
    });
  },

  onNextTicketClick: function(callback) {
    var _that = this;
    jQuery("[data-domhelper-name='next-page']").on('click.ticket_details', function(ev) {
      _that.executeCallback(callback, ev);
    });
  },

  onPrevTicketClick: function(callback) {
    var _that = this;
    jQuery("[data-domhelper-name='prev-page']").on('click.ticket_details', function(ev) {
      _that.executeCallback(callback, ev);
    });
  },

  onPriorityChanged: function(callback) {
    var _that = this;
    jQuery("[data-domhelper-name='ticket-properties-priority']").on('change.ticket_details', function(ev) {
      _that.executeCallback(callback, ev);
    });
  },

  onStatusChanged: function(callback) {
    var _that = this;
    jQuery("[data-domhelper-name='ticket-properties-status']").on('change.ticket_details', function(ev) {
      _that.executeCallback(callback, ev);
    });
  },

  onSourceChanged: function(callback) {
    var _that = this;
    jQuery("[data-domhelper-name='ticket-properties-source']").on('change.ticket_details', function(ev) {
      _that.executeCallback(callback, ev);
    });
  },

  onGroupChanged: function(callback) {
    var _that = this;
    jQuery("[data-domhelper-name='ticket-properties-group_id']").on('change.ticket_details', function(ev) {
      _that.executeCallback(callback, ev);
    });
  },

  onAgentChanged: function(callback) {
    var _that = this;
    jQuery("[data-domhelper-name='ticket-properties-responder_id']").on('change.ticket_details', function(ev) {
      _that.executeCallback(callback, ev);
    });
  },

  onTypeChanged: function(callback) {
    var _that = this;
    jQuery("[data-domhelper-name='ticket-properties-ticket_type']").on('change.ticket_details', function(ev) {
      _that.executeCallback(callback, ev);
    });
  },

  onTicketPropertiesUpdated: function(callback) {
    var _that = this;
    jQuery("[data-domhelper-name='ticket-properties-update'], [data-domhelper-name='ticket-properties-update-dup']").on('click.ticket_details', function(ev) {
      _that.executeCallback(callback, ev);
    });
  },

  executeCallback: function(callback, evt) {
    if(callback) {
      callback(evt);
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
