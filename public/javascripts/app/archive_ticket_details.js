/*jslint browser: true, devel: true */
/*global  App */

window.App = window.App || {};

(function ($) {
  "use strict";

  App.Archiveticketdetails = {
    onFirstVisit: function (data) {
      this.onVisit(data);
    },

    onVisit: function (data) {
      this.init();
    },

    onLeave: function (data) {
      $('body').off('.archive_ticket_details') 
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
    },

    updateShowMore : function () {
      //Checking if it is Notes (true) or Activities (false)
      var showing_notes = $('#all_notes').length > 0;
      var total_count, loaded_items;

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
        return true;
      } else {
        $('#show_more').addClass('hide');
        return false;
      }
    },

    updatePagination : function () {

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
          href = TICKET_DETAILS_DATA['activities_pagination_url'] + 'before_id=' + TICKET_DETAILS_DATA['first_activity'];

        $.get(href, function(response) {
          TICKET_DETAILS_DATA['first_activity'] = null;
          TICKET_DETAILS_DATA['first_note_id'] = null;
          $('#show_more').removeClass('loading').addClass('hide');
          $('[rel=activity_container]').prepend(response);
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

        if (_toggle.hasClass('disabled')) return false;
        _toggle.addClass('disabled')
        var showing_notes = $('#all_notes').length > 0;
        var url = showing_notes ? TICKET_DETAILS_DATA['activities_pagination_url'] : TICKET_DETAILS_DATA['notes_pagination_url'];
        
        if (showing_notes) {
          TICKET_DETAILS_DATA['first_activity'] = null;
          TICKET_DETAILS_DATA['loaded_activities'] = 0;
        } else {
          TICKET_DETAILS_DATA['first_note_id'] = null;
          TICKET_DETAILS_DATA['total_notes'] = 0;
        }

        $('#show_more').addClass('hide').data('next-page',null);  //Resetting

        $.ajax({
          url: url,
          success: function(response) {
            $('[rel=activity_container]').replaceWith(response);
            $('#show_more').data('next-page',null);  //Resetting
            if (self.updateShowMore()) self.updatePagination();
            _toggle.removeClass('loading_activities disabled');
            trigger_event("activities_toggle",{ current: showing_notes ? 'notes' : 'activities' });
          }, 
          error: function(response) {
            $('#show_more').removeClass('hide');
            _toggle.toggleClass('active disabled');
          }
        })
      });
    },

    maximizeActivityContainer : function() {
      $('body').on('click.archive_ticket_details', '[rel=activity_container] .minimizable', function(ev){
        if ($(ev.target).is('a')) return;
        if(($(this).find(".edit_helpdesk_note").length == 0) || ($(this).find(".edit_helpdesk_note").is(":hidden"))){
          $(this).toggleClass('minimized');
        }
      });
    },

    getAdjacentTickets: function(){
      $.getScript("/helpdesk/archive_tickets/" + TICKET_DETAILS_DATA['display_id'] + "/prevnext");
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
    }

  }
}(window.jQuery));

