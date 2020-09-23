/*jslint browser: true, devel: true */
/*global  App */

window.App = window.App || {};

(function ($) {
  "use strict";

  App.Tickets.CollabTicketDetails = {
    onFirstVisit: function (data) {
      this.onVisit(data);
    },

    onVisit: function (data) {
      if(typeof TICKET_DETAILS_DATA !== "undefined") {
        this.init();

        if(typeof App.CollaborationUi !== "undefined") {
          App.CollaborationUi.askInitUi();
        } else {
          var collab_btn = jQuery("#collab-btn");
          if(collab_btn.length) {
            collab_btn.addClass("hide");
                  console.info("Did not start collaboration. CollaborationUi script was not loaded.");
          }
        }
      }

      var iris_notification_dd = jQuery('#user-notifications-popover');
      if(iris_notification_dd.length && !iris_notification_dd.hasClass("hide")) {
        iris_notification_dd.addClass("hide");
      }
    },

    onLeave: function (data) {
      $('body').off('.archive_ticket_details');
      App.Tickets.TicketRequester.unBindEvents();

      if(!!App.CollaborationUi && typeof App.CollaborationUi.unbindEvents === "function") {
        App.CollaborationUi.unbindEvents();
      }
      // TODO(mayank): (remove deleting global object if not needed)
      // delete window.TICKET_DETAILS_DATA;
    },

    init: function () {
      this.updateShowMore();
      this.updatePagination();
      this.toggleWidgets();
      this.toggleActivities();
      this.maximizeActivityContainer();
      this.getAdjacentTickets();
      this.quoteText();
      this.toggleQuotedText();
      this.updateLocalRecentTickets();
      App.Tickets.TicketRequester.init();
    },
    paginationScroll : function(){
      var element = $("[data-activity-id ='"+TICKET_DETAILS_DATA['last_activity_batch']+"']");
      if(element){
        $.scrollTo(element,{offset: $(window).height()-jQuery('#sticky_header').outerHeight(true)});
      }
    },
    updateShowMore : function () {
      //Checking if it is Notes (true) or Activities (false)
      var showing_notes = $('#all_notes').length > 0;
      var total_count, loaded_items, show_more;

      if (showing_notes){
        loaded_items = $('[rel=activity_container] .conversation').length;
        total_count = TICKET_DETAILS_DATA['total_notes'];
      } else {
        total_count = TICKET_DETAILS_DATA['total_activities'];
        loaded_items = TICKET_DETAILS_DATA['loaded_activities'];
      }

      if (loaded_items < total_count) {
        var remaining_notes = total_count - loaded_items;
        $('#show_more [rel=count-total-remaining]').text(total_count - loaded_items);
        
        $('#show_more').removeClass('hide');
        show_more = true;
      } else {
        $('#show_more').addClass('hide');
        show_more = false;
      }
      if(!showing_notes){
        this.paginationScroll();
      }
      return show_more;
    },

    updatePagination : function () {
      var self = this;
      var showing_notes = $('#all_notes').length > 0;

      //Unbinding the previous handler:
      $('#show_more').off('click.archive_ticket_details');
      $('#show_more').on('click.archive_ticket_details',function(ev) {
        ev.preventDefault();
        $('#show_more').addClass('loading');
        var href;
        if (showing_notes)
          href = TICKET_DETAILS_DATA['notes_pagination_url'] + 'before_id=' + TICKET_DETAILS_DATA['first_note_id'];
        else
          href = TICKET_DETAILS_DATA['activities_pagination_url'] + 'before_id=' + TICKET_DETAILS_DATA['first_activity'] + '&limit=' +  TICKET_DETAILS_DATA['pagination_limit'];

        $.get(href, function(response) {
          if(response.trim()!=''){
            TICKET_DETAILS_DATA['first_activity'] = null;
            TICKET_DETAILS_DATA['first_note_id'] = null;
          }
          TICKET_DETAILS_DATA['last_activity_batch'] = null;
          $('#show_more').removeClass('loading').addClass('hide');
          $('[rel=activity_container]').prepend(response);
          self.updateShowMore();
          trigger_event("ticket_show_more",{})
          try {
            freshfonePlayerSettings();
          } catch (e) { console.log("freshfonePlayerSettings not loaded");}
        });
      });
    },

    toggleWidgets : function() {
      $('body').on('click.archive_ticket_details', '.widget .title', function(ev) {
        $(this).parents(".widget").toggleClass('inactive');
      });
    },

    toggleActivities : function () {
      var self = this;
      $('body').on('click.archive_ticket_details', '#activity_toggle', function(ev) {
        var _toggle = $(this);

        if (_toggle.hasClass('disabled')){
          _toggle.toggleClass('active');
          return false;
        }
        _toggle.addClass('disabled')
        var showing_notes = $('#all_notes').length > 0;
        var url = showing_notes ? TICKET_DETAILS_DATA['activities_pagination_url'] + 'limit=' + TICKET_DETAILS_DATA['pagination_limit'] : TICKET_DETAILS_DATA['notes_pagination_url'];
        
        if (showing_notes) {
          TICKET_DETAILS_DATA['first_activity'] = null;
          TICKET_DETAILS_DATA['loaded_activities'] = 0;
        } else {
          TICKET_DETAILS_DATA['first_note_id'] = null;
          TICKET_DETAILS_DATA['total_notes'] = 0;
        }

        $('#show_more').data('next-page',null);  //Resetting

        $.ajax({
          url: url,
          success: function(response) {
            if(response.trim()!=''){
              $('[rel=activity_container]').replaceWith(response);
              $('#show_more').data('next-page',null);  //Resetting
              if (self.updateShowMore()) self.updatePagination();
              _toggle.removeClass('loading_activities disabled');
              trigger_event("activities_toggle",{ current: showing_notes ? 'notes' : 'activities' });
              var _shortcut = ' ( ' + _toggle.data('keybinding') + ' )';
              if(showing_notes){
                $("#original_request .commentbox").addClass('minimized');
                if(_toggle.data('hide-title'))
                _toggle.attr('title',_toggle.data('hide-title')+_shortcut);
              }
              else{
                $.scrollTo($('body'));
                $("#original_request .commentbox").removeClass('minimizable minimized');
                if(_toggle.data('show-title'))
                _toggle.attr('title',_toggle.data('show-title')+_shortcut);
              }
            }
            else{
              _toggle.removeClass('loading_activities disabled active');
            }

          }, 
          error: function(response) {
            $('#show_more').removeClass('hide');
            _toggle.toggleClass('active disabled');
          }
        })
      });
    },

    maximizeActivityContainer : function() {
        $('body').on('click.ticket_details', '.conversation_thread .minimized ', function(ev){
          if ($(ev.target).is('a')) return;
          $(this).toggleClass('minimized minimizable');
        });

        $('body').on('click.ticket_details', '.conversation_thread .minimizable .author-mail-detail, .conversation_thread .minimizable .subject', function(ev){
          if ($(ev.target).is('a')) return;
          var minimizable_wrap = $(this).closest('.minimizable');
          if((minimizable_wrap.find(".edit_helpdesk_note").length == 0) || (minimizable_wrap.find(".edit_helpdesk_note").is(":hidden"))){
            minimizable_wrap.toggleClass('minimized minimizable');
          }
        });
    },

    getAdjacentTickets: function(){
      $.getScript("/helpdesk/tickets/collab/" + TICKET_DETAILS_DATA['display_id'] + "/prevnext");
    },


    quoteText: function(){
      var self = this;
      $("div.request_archive_mail").livequery(function(){ 
        self.quote_text_from_archive(this)
      });
    },

    toggleQuotedText: function(){
      var self = this;
      $('body').on('click.archive_ticket_details', '.archive-q-marker.tooltip', function(ev){
        var _container = $(this).parents('.details');
        var _fd_quote = $(this).parents('.freshdesk_quote')
        if (_fd_quote.data('remoteQuote')){
          var _note_id = _container.data('note-id');
          var _messageDiv = _container.find('div:first');
          var options = { "force_quote": true };
          $.ajax({
            url: '/helpdesk/archive_tickets/'+TICKET_DETAILS_DATA["displayId"]+'/archive_notes/'+_note_id+'/full_text',
            data: { id: _note_id },
            success: function(response){
              if(response!=""){
                _messageDiv.find('.tooltip').twipsy('hide');
                _messageDiv.html(response);
                self.quote_text_from_archive(_messageDiv, options);
              }
              else {
                _container.find('div.freshdesk_quote').remove();
              }
              $('.twipsy.in').remove();
            }
          });
        }
      })
    },

    quote_text_from_archive: function(item, options){
      options = options || {}
      if (!$(item).attr("data-quoted") || options["force_quote"]) {
        var show_hide = $("<a href='#' title='Show quoted text'/>").addClass("archive-q-marker tooltip").text("")
        var child_quote = $(item).find("div.freshdesk_quote").first().prepend(show_hide).children("blockquote.freshdesk_quote")
        if(!options["force_quote"]){
          child_quote.hide();
        }
        show_hide.bind("click", function(ev){
           ev.preventDefault();
           child_quote.toggle();
        });
        $(item).removeClass("request_archive_mail");
        $(item).attr("data-quoted", true);
      }
    },

    updateLocalRecentTickets: function(){
      //RECENT TICKETS SETUP
      NavSearchUtils.saveToLocalRecentTickets(TICKET_DETAILS_DATA);
    }


  }
}(window.jQuery));

