var NewTicketDom = Class.create({
  initialize: function() {
    this.idMap = {
      "requester"     :  "#helpdesk_ticket_email",
      "add_requester" :  "#add_requester_btn",
      "status"        :  "#helpdesk_ticket_status",
      "priority"      :  "#helpdesk_ticket_priority"
    };
  },

  onRequesterChanged: function(callback) {
    var _that = this;
    jQuery(this.idMap['requester']).keyup(function(ev) {
      _that.executeCallback(callback, ev);
    });
  },

  onPriorityChanged: function(callback) {
    var _that = this;
    jQuery(this.idMap['priority']).on('change', function(ev) {
      _that.executeCallback(callback, ev);
    });
  },

  onStatusChanged: function(callback) {
    var _that = this;
    jQuery(this.idMap['status']).on('change', function(ev) {
      _that.executeCallback(callback, ev);
    });
  },

  setRequester: function(value) {
    jQuery(this.idMap['requester']).val(value);
  },

  disableRequesterField: function() {
    jQuery(this.idMap['requester']).addClass('disabled');
    jQuery(this.idMap['add_requester']).addClass('disabled');
  },

  setPriority: function(priorityId) {
    jQuery(this.idMap['priority']).val(priorityId).trigger('change');
  },

  setStatus: function(statusId) {
    jQuery(this.idMap['status']).val(statusId).trigger('change');
  },

  executeCallback: function(callback, ev) {
    if(callback) {
      callback(ev);
    }
  }
});

var newTicketDom = new NewTicketDom();
