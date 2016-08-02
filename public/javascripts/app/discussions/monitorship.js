/*jslint browser: true, devel: true */
/*global  App */
window.App = window.App || {};
window.App.Discussions = window.App.Discussions || {};
(function ($) {
  "use strict";

  App.Discussions.Monitorship = {
    init: function () {
      this.addListeners();
    },
    unbind: function () {
      $('body').off('.monitorship');
    },
    addListeners: function () {
      $("body").on('change.monitorship', '.follower_input', this.addFollower.bind(this));
      $("body").on('click.monitorship', '.unfollow', this.removeFollower.bind(this));
      $("body").on('click.monitorship', '#toggle_monitorship_status', this.toggleAddFollower);
      $("body").on('click.monitorship', '.follower-close', function () {
        $("#new_follower_page").hide();
      });
      $("body").on('click.monitorship', this.clickedOutside);
    },
    toggleAddFollower: function () {
      $("#new_follower_page").toggle();
      if ($("#new_follower_page").is(':visible')) {
        $('.follower_input .select2-search-field').focus();
      };
      jQuery("#followerlist").find('img').trigger( "unveil" );
      jQuery("#addfollower .select2-search-field input").focus()
    },
    clickedOutside: function (e) {
      var container =  $('#follower-container');
      if (!container.is(e.target) && container.has(e.target).length === 0) {
        $("#new_follower_page").hide();
      }
    },
    addFollower: function () {
      var $this = this;
      this.updateFollower('follow', {
        user_id : $("select.follower_input").val()[0]
      }, function () {
        $('#followerlist ul li:first').animateHighlight();
      });
    },
    removeFollower: function () {
      this.updateFollower('unfollow');
    },
    updateFollower: function (action, data, callback) {
      callback = callback || function () {};
      data = data || {};
      $("#addfollower .select2-search-choice").hide();
      $('#addfollower .select2-input').trigger('focus');
      $("#followerlist").addClass("sloading");
      $.ajax({
        type: 'POST',
        url:  $(".add_follower_icon").data('remote-url') + action,
        data: data,
        dataType: 'script',
        success: callback
      });
    },
    toggleForCurrentUser: function () {
      var el = $('#toggle_monitorship_status');
      if (el.data('following')) {
        this.removeFollower();
      } else {
        $('#ids').select2('val', parseInt(el.data('current-user'), 10));
        this.addFollower();
      }
    }
  };
}(window.jQuery));