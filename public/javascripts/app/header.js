/*jslint browser: true, devel: true */
/*global  App */

window.App = window.App || {};
window.App.Header  = window.App.Header || {};

(function ($) {
	"use strict";
	
	App.Header = {
		assumable_loaded: 0,
		init: function (is_assumed_user) {
			this.assumed_identity = is_assumed_user;
			this.bindEvent();
		},
		bindEvent: function() {
			$('#header-profile-avatar').on('click', this.loadAssumableAgents.bind(this));
			$('#toggle_shortcut').on('change', this.toggleShortcuts.bind(this));
			$('#shortcuts_info').on('click', this.loadShortcutInfo.bind(this));
			$('#available_icon').on('click', this.toggleAvailability.bind(this));
			$('#assumed_select_id').on('change', this.assumeIdentityUrl.bind(this));
		},
		loadAssumableAgents: function() {
			if(!this.assumable_loaded && !this.assumed_identity){
				var self    = this;
				var select  = jQuery("#assumed_select_id");

	      jQuery.ajax({
	        url: "/users/assumable_agents",
	        type: "GET",
	        success: function(agent_list){
	          if(agent_list.size() == 0){
	            jQuery("#switch_agent_container").remove();
	          } else{
							$.each(agent_list, function(index, agent){
								select.append("<option id='" + agent.id + "' value='" + agent.id + "'>" + agent.value + "</option>");
							})
							select.select2().show();
	          }
	          jQuery("#agt_loading").remove();
	          self.assumable_loaded = 1;
	        }
	      });
	    }
		},
		toggleShortcuts: function (ev){
	    var target = ev.currentTarget;
	    target.disabled = true;

	    jQuery.ajax({
	      type: "PUT",
	      dataType:"json",
	      url: $(target).data('remoteUrl'),
	      success: function (response) {
	        target.disabled = false;
	        if (response.shortcuts_enabled) {
	          if(window.shortcuts !== undefined){
	            jQuery(document).trigger("shortcuts:invoke");
	          } else {
	            Fjax.Assets.plugin('shortcut');
	          }
	        } else {
	          jQuery(document).trigger("shortcuts:destroy");
	        }
	      }
	    });
		},
		loadShortcutInfo: function (ev) {
			ev.preventDefault();
			jQuery('#shortcut_help_chart').trigger('click');
		},
		toggleAvailability: function (ev) {
			var request_data = {
				value: !( jQuery("#available_icon").attr("class") == "header-icons-agent-roundrobin-on" ),
				id: DataStore.get('current_user').currentData.user.id
			};

			jQuery.ajax({
	      type: "POST",
	      url: $(ev.currentTarget).data('remoteUrl'),
	      data: request_data,
	      beforeSend: function () {
	      	jQuery('#available_icon').addClass('header-spinner')
	      },
	      success: function () {
	      	var element = jQuery('#availabilty-toggle');
	        //change the icon class.
          jQuery('#available_icon').removeClass('header-spinner');

          if (jQuery('#available_icon').hasClass('header-icons-agent-roundrobin-on')) {
            jQuery('#available_icon').removeClass('header-icons-agent-roundrobin-on')
            													.addClass('header-icons-agent-roundrobin-off');
            element.attr('title', element.data('assignOn'));

          } else{
            jQuery('#available_icon').removeClass('header-icons-agent-roundrobin-off')
            													.addClass('header-icons-agent-roundrobin-on');
            element.attr('title', element.data('assignOff'));
          }
	      }
	    });
		},
		assumeIdentityUrl: function() {
			window.location = '/users/' + $('#assumed_select_id').val() + '/assume_identity';
		}
	};

}(window.jQuery));