/*jslint browser: true, devel: true */
/*global  App */

window.App = window.App || {};
window.App.Tickets = window.App.Tickets || {};

(function ($) {
  "use strict";
  
  App.Tickets.Watcher = {
    currentUserID: 0,
    currentUserName: "",
    init: function () {
      this.offEventBinding();
      this.currentUserID = (DataStore.get('current_user').currentData.user.id).toString();
      this.currentUserName = (DataStore.get('current_user').currentData.user.name).toString();
      this.addListeners();
    },
    addListeners: function () {
      $("body").on('change.watcher', '.watcher_input', this.addWatcher.bind(this));
      $("body").on('click.watcher', '.unwatch', this.removeWatcher.bind(this));
      $("body").on('click.watcher', '#monitor', this.toggleWatcher.bind(this));
      $("body").on('click.watcher', '.watcher-close', this.closeWatcher.bind(this));
      $("body").on('click.watcher', this.clickedOutside.bind(this));
    },
    removeHighlightClass: function () {
       jQuery("#watcherlist li").removeClass("watcher_highlight");
    },
    toggleWatcher: function (ev) {
      this.removeHighlightClass();
      jQuery("#new_watcher_page").toggle();
      jQuery("#addwatcher .select2-search-field input").focus()
    },
    closeWatcher: function () {
      jQuery(".watchers_tooltip").hide();
      this.removeHighlightClass();
    },
    clickedOutside: function (ev) {
      if(!jQuery(ev.target).parents().hasClass("ticket-btns")){
        jQuery("#new_watcher_page").hide();
        this.removeHighlightClass();
      }
    },
    updateWatcherCount: function () {
      jQuery(".watcher_count").html('('+jQuery("#watcherlist li").length+')');
    },
    addWatcher: function () {
      var self = this,
          user_id = jQuery(".watcher_input").select2('data').last().id,
          requestURL = $("#monitor").data('remote-url') + "/create_watchers?user_id=" + user_id;

      this.watcherRequest(requestURL ,'POST', function (data) {
        jQuery('#watcherlist').remove();
        jQuery(data).insertAfter('#addwatcher');
        jQuery("#watcherlist").removeClass("sloading");

        self.updateWatcherCount();

        if(user_id == self.currentUserID)
          jQuery('#watcher_toggle').data('watching', true);

        trigger_event("watcher_added",{});
      })

      if(!jQuery(".watcher_count").text()) {
        jQuery(".watcher_label div").first().append('<span class="watcher_count"></span>');
      }

      if (user_id == this.currentUserID) {
        jQuery("#monitor a").addClass("monitor_active").removeClass("monitor");
      }

      jQuery(".ticket-add-watcher .select2-search-choice").hide();
      jQuery(".watcher_input").focus();
    },
    removeWatcher: function () {
      var self = this,
          requestURL = $("#monitor").data('remote-url') + "/unwatch",
          selected_ids = jQuery("select.watcher_input").val();
      this.watcherRequest(requestURL ,'DELETE', function(data){
          jQuery("#watcherlist").removeClass("sloading");
          jQuery(".construct").append(jQuery("#watcherlist .unwatch"));
          jQuery("#monitor a").addClass("monitor").removeClass("monitor_active");
          trigger_event("watcher_removed",{});

          if(jQuery.inArray(self.currentUserID, jQuery("select.watcher_input").val()) == -1) {
            jQuery("select.watcher_input")
              .prepend(jQuery("<option></option>")
              .attr("value", self.currentUserID )
              .text("Me ("+self.currentUserName+")"));
          } else {
            selected_ids.splice(selected_ids.indexOf(self.currentUserID), 1);
          }

          jQuery("select.watcher_input").val(selected_ids);
          jQuery("#watcherlist li").first().remove();

          self.updateWatcherCount();

          if(jQuery("#watcherlist li").length == 0) {
            jQuery(".watcher_count").remove();
            jQuery("#watcherlist").remove();
          }
          jQuery('#watcher_toggle').data('watching', false);
        });
    },
    watcherRequest: function (requestURL, type, callback) {
      jQuery.ajax({
        type: type,
        url: requestURL,
        beforeSend: function() {
          jQuery("#watcherlist").addClass("sloading");
        },
        success: callback
      });
    },
    offEventBinding: function () {
      $('body').off('.watcher');
    }
  };

}(window.jQuery));