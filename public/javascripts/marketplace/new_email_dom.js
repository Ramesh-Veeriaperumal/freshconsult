var NewEmailDom = Class.create({
  initialize: function() {
    this.idMap = {
      "requester"  :  "#helpdesk_ticket_email",
      "from_email" :  "#helpdesk_ticket_email_config_id",
      "status"     :  "#helpdesk_ticket_status",
      "priority"   :  "#helpdesk_ticket_priority"
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

  setPriority: function(priorityId) {
    jQuery(this.idMap['priority']).val(priorityId).trigger('change');
  },

  setStatus: function(statusId) {
    jQuery(this.idMap['status']).val(statusId).trigger('change');
  },

  setRequester: function(value) {
    jQuery(this.idMap['requester']).val(value);
  },

  disableFromEmail: function() {
    jQuery(this.idMap['from_email']).addClass('disabled');
  },

  enableFromEmail: function() {
    jQuery(this.idMap['from_email']).removeClass('disabled');
  },

  setFromEmail: function(input_email) {
    var email_field = jQuery(this.idMap["from_email"] + ' option');
    for (i = 1; i < email_field.length; i++) {
      if(email_field[i].textContent.split('<')[1].split('>')[0] == input_email) {
        jQuery(this.idMap['from_email']).val(email_field[i].value).trigger('change');
        break;
      }
    }
  },

  executeCallback: function(callback, ev) {
    if(callback) {
      callback(ev);
    }
  }
});

var newEmailDom = new NewEmailDom();
