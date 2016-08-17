var ScreenPop;
(function ($) {
  "use strict";
  
  ScreenPop = function () {
    this.$ctiContentContainer = $('.cti-content-container');
    this.$contextContainerWrap = $(".context-container-wrap");
    this.$callNote = $('#call_notes');
    this.$addNoteText = $('.add-call-note').find(".add-note-text");
    this.$recentTicketsContent = $('.recent-tickets-content');
    this.$ticketsLoading = $('.tickets-loading');
    this.$callerContextDetails = $('.cti-caller-context');
    this.$ctiPhoneSelect = $(".cti-phone-select");
    this.$ctiPhoneStatus = $(".cti-phone-status");
    this.$ticketRequester = $("#ticket_requester");
    this.$ticketSubject = $("#ticket_subject");
    this.requester_id = null;
    this.ticket_id = null;
    this.call_id = null;
    this.new_ticket = false;
    this.callOngoing = false;
    this.ctiCallNumber = null;
    this.requesterName = null;
    this.ctiCallOldNumber = null;
    this.init();
  };

  ScreenPop.prototype = {
    init: function () {
      this.resetForm();
      this.attachEventListener();
      this.populatePhoneSelectInput();
      this.getOngoingCall();
    },
    getOngoingCall: function() {
      var self = this;
      $.ajax({
        url: '/integrations/cti/screen_pop/ongoing_call',
        type: "GET",
        dataType: "json",
        success: function (data) {
          self.resetValues();
          self.requester_id = data.requester_id;
          self.ticket_id = data.ticket_id;
          self.call_id = data.id;
          self.new_ticket = data.new_ticket;
          self.loadContext();
          self.showLinkToExisting();
        }
      });
    },
    linkToExisting: function() {
      var self = this;
      var ticket_id = TICKET_DETAILS_DATA.displayId;
      var note = escapeHtml($('#call_notes').val());
      $(".cti-action-loading").addClass('sloading');
      self.showCallActionForm();
      $.ajax({
        url: '/integrations/cti/screen_pop/link_to_existing',
        type: "POST",
        dataType: "json",
        data: {ticket_id : ticket_id, note_body: note, call_id: this.call_id},
        success: function (data) {
          self.callActionEnd();
          $.pjax({url: data.ticket_path, container: '#body-container', timeout: -1});
        }
      });
    },
    linkToNew: function() {
      var self = this;
      var note = escapeHtml($('#call_notes').val());
      var requesterName = $("#ticket_requester").val();
      $(".cti-action-loading").addClass('sloading');
      self.showCallActionForm();
      $.ajax({
        url: '/integrations/cti/screen_pop/link_to_new',
        type: "POST",
        dataType: "json",
        data: {note_body: note, call_id: this.call_id,requester_name: requesterName, subject: self.$ticketSubject.val()},
        success: function (data) {
          self.callActionEnd();
          $.pjax({url: data.ticket_path, container: '#body-container', timeout: -1});
        }
      });
    },
    addNoteToNew: function() {
      var self = this;
      var note = $('#call_notes').val();
      $(".cti-action-loading").addClass('sloading');
      self.showCallActionForm();
      $.ajax({
        url: '/integrations/cti/screen_pop/add_note_to_new',
        type: "POST",
        dataType: "json",
        data: {note_body: note, call_id: this.call_id},
        success: function (data) {
          self.callActionEnd();
          $.pjax({url: data.ticket_path, container: '#body-container', timeout: -1});
        }
      });
    },
    showLinkToExisting: function() {
      if (!this.callOngoing) return;
      if(this.new_ticket) return;

      if( this.inTicketDetailsPage() ) {
        $("#cti_action_existing").show();
        var subject = $.trim($("#original_request .subject").text());
        $(".link-ticket-subject").text(subject);
        $(".cti-existing-id").html('#' + TICKET_DETAILS_DATA.displayId);
        this.showCallActionForm('.link-call-index');
      } else {
        $('#cti_action_existing').hide();
      }
    },
    inTicketDetailsPage: function(){
      var TICKET_PAGE_REGEX = /\/helpdesk\/tickets\/\d+/;
      return !!TICKET_PAGE_REGEX.exec(location.pathname);
    },
    inContactDetailsPage: function(){
      var CONTACT_PAGE_REGEX  = /\/(users|contacts)\/.*/;
      return !!CONTACT_PAGE_REGEX.exec(location.pathname);
    },
    ticketSubject: function () {
      this.generateTicketSubject();
    },
    resetForm: function () {
      this.$recentTicketsContent.empty();
      this.$callerContextDetails.empty();
      this.$ticketRequester.val("");
      this.$ticketSubject.val("");
      var $callNote = $("#cti_add_notes").find("#call_notes");
      $callNote.val("");
      this.callOngoing = false;
      this.showNoCallPopup();
      this.$contextContainerWrap.hide();
      $('#cti_action_existing').hide();
      $(".cti-call-reference").hide();
      $(".cti-action-loading").removeClass('sloading');
      $('#cti_pop_icon_tooltip').removeClass('call-active');
      $('#cti_pop_icon').removeClass('cti-call-ongoing');
      if ($('.call_notes').css('display') == "inline-block") {
        this.toggleCallNotes();
      }
      this.closePop();
    },
    showCallActionForm: function(selector){
      $('.link-call-index , .link-call-ticket , .link-new-call-note').hide();
      if(selector){
        $(selector).show();
      }
    },
    loadContext: function () {
      this.resetForm();
      this.$contextContainerWrap.show();
      this.$ctiPhoneSelect.hide();
      this.fetchUserDetails();
      this.callOngoing = true;
      this.getRecentTickets();
      this.makeCallOngoing();
      this.makeCallActionActive();  
      $('#cti_pop_icon').removeClass("disabled");
      if (this.ticket_id && !this.new_ticket) {
        $(".call-reference-ticket-id").text("#"+this.ticket_id);
        $(".call-reference-ticket-id").attr("href","/helpdesk/tickets/"+this.ticket_id);
        $(".cti-call-reference").show();

        if(this.inTicketDetailsPage() && this.ticket_id == TICKET_DETAILS_DATA.displayId) {
          this.showLinkToExisting();
        }
      }
      if (this.new_ticket) {
        this.showCallActionForm('.link-new-call-note');
        $('#cti_new_call_id').text('#'+this.ticket_id);
        $('#cti_new_call_id').attr('href','/helpdesk/tickets/'+this.ticket_id);
      } else {
        this.showCallActionForm('.link-call-index');
      }
    },
    showPop: function () {
      var $target = $("#cti_pop_icon");
      $('.cti-widget').data('popupbox').show($target);
    },
    closePop: function () {
      if(this.$ctiContentContainer.is(":visible")){
        var $target = $("#cti_pop_icon");
        $('.cti-widget').data('popupbox').toggleTarget($target, true);
      }
    },
    fetchUserDetails: function () {
      var self = this;
      $.ajax({
        url: '/integrations/cti/screen_pop/contact_details',
        data: {requester_id : this.requester_id},
        success: function (data) {
          if (data) {
            $('.cti-caller-context').html(data);
            self.requesterName = $('.caller-name').find('a').text();
            self.$ticketRequester.val(self.requesterName);
            self.$ticketSubject.val(self.generateTicketSubject());
            if ($('.cti-caller-more-details').length) {
              $('.cti-caller-more-details-toggle').show();
            } else {
              $('.cti-caller-more-details-toggle').hide();
            }
          }
        }
      });
    },
    showContactDetails: function() {
      $('.cti-caller-more-details').slideDown('fast','swing');
      $('.cti-caller-more-details-toggle').hide();
      $('.cti-caller-context').addClass('details-more');
    },
    hideContactDetails: function() {
      $('.cti-caller-more-details').hide()
      $('.cti-caller-more-details-toggle').show();
      $('.cti-caller-context').removeClass('details-more');
    },
    generateTicketSubject: function () {
      return 'Call with ' +    "(" + this.requesterName + ")" +
            ' on ' + Date().toString('ddd, MMM d @ h:mm:ss tt').replace(/\@/, 'at');
    },
    getRecentTickets: function(){
      var self = this;
      self.$recentTicketsContent.empty();
      self.$ticketsLoading.addClass('sloading');
      var url = '/integrations/cti/screen_pop/recent_tickets';
      jQuery.ajax({
        type: 'GET',
        dataType: 'html',
        url: url,
        data: {requester_id:this.requester_id},
        success: function(data){
          self.$ticketsLoading.removeClass('sloading');
          self.$recentTicketsContent.empty().append(data);
          self.showPop();
          $('#cti_pop_icon_tooltip').addClass('call-active');
          if($(".ticket-content").length) {
            $("#cti_recent_tickets_link").removeClass('disabled');
          }
          else {
            $("#cti_recent_tickets_link").addClass('disabled');
          }
        }
      });
    },
    attachEventListener: function(){
      var self = this;
      $('.cti-phone-select button').on('click', function(ev){
        $('#phone_list_loading').addClass('sloading');
        self.$ctiPhoneSelect.hide();
        var url = '/integrations/cti/screen_pop/set_phone_number';
        var cti_phone_id = $("#cti_phone_numbers").val();
        jQuery.ajax({
          type: 'POST',
          dataType: 'html',
          url: url,
          data: {id : cti_phone_id},
          success: function(data){
            $('#phone_list_loading').removeClass('sloading');
            $("#cti-phone-status").show();
          }
        });
      });

      $(document).on('ready pjax:end', self.showLinkToExisting.bind(self));
      $('.add-notes-header').on('click', self.toggleCallNotes);
      $('.cti-minimize').on('click', self.closePop.bind(self));
      $('.status-btn').on('click', self.resetForm.bind(self));
      $('#cti_action_existing').on('click', self.linkToExisting.bind(self));
      $('#cti_link_new').on('click', self.linkToNew.bind(self));
      $('#cti_new_call_link').on('click', self.addNoteToNew.bind(self));
      $('#cti_cancel').on('click', self.showCallActionForm.bind(self,'.link-call-index'));
      $('#cti_action_ignore, #cti_new_call_ignore').on('click',self.ignoreCall.bind(self));
      $('.cti-caller-context').on('mouseenter', '.cti-caller-more-details-toggle', self.showContactDetails);
      $('.cti-caller-context').on('mouseleave', '.cti-caller-more-details', self.hideContactDetails);
      $("#cti_action_new").on('click',function(ev){
        $(".link-call-index").hide();
        $(".link-call-ticket").show();
      });
    },
    toggleCallNotes: function() {
      $('.add-notes-header .header-text-closed').toggle();
      $('.add-notes-header .header-text-opened').toggle();
      $('.call_notes').toggle();
      if ($('.call_notes').css('display') == "inline-block") {
        $('.call_notes').focus();
      }
      $('.cti-add-notes').toggleClass('edit-note')

    },
    showNoCallPopup: function(){
      this.$contextContainerWrap.hide();
      this.$ctiPhoneStatus.hide();
      this.showPhoneSelectForm();
    },
    showPhoneSelectForm: function() {
      if(this.$ctiPhoneSelect.find('select')[0].options.length){
        this.$ctiPhoneSelect.show();
        $('#cti_pop_icon').removeClass("disabled");
      } else {
        $('#cti_pop_icon').addClass("disabled");
      }
    },
    makeCallActionActive: function() {
      $('[href="#cti_call_action"]').parent().addClass('active');
      $('[href="#cti_recent_tickets"]').parent().removeClass('active');
      $('#cti_recent_tickets').removeClass('active');
      $('#cti_call_action').addClass('active');
    },
    ignoreCall: function() {
      var self = this;
      $(".cti-action-loading").addClass('sloading');
      self.showCallActionForm();
      $.ajax({
        url: '/integrations/cti/screen_pop/ignore_call',
        dataType: "json",
        data: {call_id: self.call_id},
        type: 'POST',
        success: self.callActionEnd.bind(self),
        error: function (data) {
          console.log("unable to ignore call");
        }
      });
    },
    populatePhoneSelectInput: function(){
      var url = '/integrations/cti/screen_pop/phone_numbers';
      var self = this;
      self.$contextContainerWrap.hide();
      jQuery.ajax({
        type: 'GET',
        dataType: 'html',
        url: url,
        success: function(data){
          data = JSON.parse(data);
          UIUtil.constructDropDown(data, "json", "cti_phone_numbers", null, "id", ["phone"], null, "");
          if(data.length > 0) {
            $("#cti_phone_numbers").select2("val", self.ctiCallNumber || self.ctiCallOldNumber || data[0].id);
          }
          if (!!data.length && !self.ctiCallNumber) {
            self.showPop();
          }
          if (!self.callOngoing){
            self.showPhoneSelectForm();
          }
        }
      });
    },
    makeCallOngoing: function () {
      this.callOngoing = true;
      $.ajax({
        url: '/integrations/cti/screen_pop/set_pop_open',
        dataType: "json",
        data: {call_id: this.call_id},
        type: 'POST',
        error: function (data) {
          console.log("unable to set pop state to open");
        }
      });
      $('#cti_pop_icon').addClass('cti-call-ongoing');
    },
    click_to_dial: function (){
      //this object belongs to the .can_make_calls div
      var requester_number = $(this).data('phoneNumber').toString();
      var ticketId;
      var requesterId;
      if( screenPop.inTicketDetailsPage() ) {
        ticketId = TICKET_DETAILS_DATA.displayId;
      }

      if( screenPop.inContactDetailsPage() ) {
        requesterId = $('form.edit_user').find(':input[id="userid"]').val();
      }
      $.ajax({
        url: '/integrations/cti/screen_pop/click_to_dial',
        data: {requester_number: requester_number, ticket_id: ticketId, requester_id: requesterId},
        dataType: "json",
        type: 'POST',
        error: function (data) {
          console.log("Unable to place call");
        }
      });
    },
    setCtiPopIconTooltip: function (){
      var tooltip;
      if(this.callOngoing){
        tooltip = "cti phone";
      } else {
        tooltip = "No call in progress";
      }
      return tooltip;
    },
    callActionEnd: function() {
      this.resetForm();
      this.resetValues();
      ctiFeature.freshSocket.emit('callActionEnd');
    },
    resetValues: function() {
      this.requester_id = null;
      this.ticket_id = null;
      this.call_id = null;
      this.new_ticket = false;
      this.callOngoing = false;
      this.ctiCallNumber = null;
      this.requesterName = null;
    }

  };
}(jQuery));
