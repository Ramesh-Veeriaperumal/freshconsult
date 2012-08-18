
bulkActionButtonsDisabled = function () {
	if (jQuery('#ticket-list .check .selector:checked').length > 0 ) {
		jQuery('#ticket-toolbar .bulk_action_buttons .button').removeAttr('disabled');
	} else {
		jQuery('#ticket-toolbar .bulk_action_buttons .button').attr('disabled','disabled');
	}
}
ticksymbol = "<span class='icon ticksymbol'></span>";
priority_ids = {1: "low", 2:"medium", 3:"high", 4:"urgent"}

jQuery(document).ready(function() {
	
// ---- EXTRACTED FROM /helpdesk/shared/_tickets.html.erb ----
	jQuery(".ticket-description-tip").livequery(function () {
		_self = jQuery(this);        
        var tipUrl = _self.data("tipUrl");
        _self.qtip({
			position: { 
				my: 'top left',
				at: 'bottom  left',
				viewport: jQuery(window) 
			}, 
			style : {
				classes: 'ui-tooltip-ticket ui-tooltip-rounded',
				tip: {
					mimic: 'center'
				}
			},             
			content: {
				text: TICKET_STRINGS['tooltip_loading'],
				ajax: {
					url: tipUrl,
					once: true
				}
			},
			show: {
				solo: true,
				delay: 500,
				effect: function(offset) {
					jQuery(this).show("fade", 200); // "this" refers to the tooltip
				}
          	}
        }); 
	});
        
     jQuery(".nav-trigger").showAsMenu();

// ---- END OF extract from /helpdesk/shared/_tickets.html.erb ----

// ---- EXTRACTED FROM /helpdesk/shared/_ticket_view.html.erb ----
  
	jQuery('#recent_ticket_count').click(function(){
	    jQuery("#ticket-list").html("<div class='loading-box'></div>"); 
	     jQuery.ajax({
	        url: "/helpdesk/tickets/custom_search",
	        type: "POST",
	        dataType: "script",
	        data: jQuery("#FilterOptions").serializeArray(),
	        success: function(msg){ 
	        }
	      }); 
		jQuery(this).hide();	
	});	

	jQuery('.ticket-view-choice').click(function() {
		if (jQuery(this).hasClass('ticket-view-detail')) {
			jQuery("#ticket-list").removeClass("list_view").addClass("detailed_view");
			setCookie('ticket_view_choice','detail',365);
		}
		if (jQuery(this).hasClass('ticket-view-list')) {
			jQuery("#ticket-list").removeClass("detailed_view").addClass("list_view");
			setCookie('ticket_view_choice','list',365);
		}
		jQuery(this).parent().addClass('active').siblings().removeClass('active');
	});

	setCookie('ticket_view_choice','detail',365);
	var choice = getCookie('ticket_view_choice');
	if (choice == 'list') {
		jQuery('.ticket-view-choice.ticket-view-list').click();
	} else {
		jQuery('.ticket-view-choice.ticket-view-detail').click();
	}
	
// ---- END OF extract from /helpdesk/shared/_ticket_view.html.erb ----


		//Clicking on the row (for ticket list only), the check box is toggled.
	// jQuery('.tickets tbody tr').live('click',function(ev) {
	// 	if (! jQuery(ev.target).is('input[type=checkbox]') && ! jQuery(ev.target).is('a') && ! jQuery(ev.target).is('.quick-action')) {
	// 		var checkbox = jQuery(this).find('input[type=checkbox]').first();
	// 		checkbox.prop('checked',!checkbox.prop('checked'));
	// 		checkbox.trigger('change');
	// 	}
	// });

    jQuery('.tickets tbody tr .check :checkbox').live('change', function() {
        if (jQuery(this).prop('checked')) {
          jQuery(this).parent().parent().addClass('active');
        } else {
          jQuery(this).parent().parent().removeClass('active');
        }

        jQuery("#helpdesk-select-all").prop('checked', jQuery('.tickets tbody tr .check :checkbox:checked').length == jQuery('.tickets tbody tr .check :checkbox').length);
        bulkActionButtonsDisabled();
    });

	bulkActionButtonsDisabled();
	
	// Quick Actions	
	// Assign Agent
	jQuery('.action_assign_agent').live("click",function(ev) {
		
		ev.preventDefault();
		selected_item = jQuery(this);
		ticket_id = selected_item.data('ticket-id');
		agent_user_id = selected_item.data('agent-id');
		new_text = selected_item.text();

		full_menu = selected_item.parent();
		full_menu.addClass('loading');
		jQuery.ajax( {
			type: "POST",
			url: '/helpdesk/tickets/quick_assign/' + ticket_id,
			data: {assign: 'agent', value : agent_user_id, _method: 'put'},
			success: function (data) {
				jQuery('[data-ticket=' + ticket_id + '] [data-type="assigned"] .result').text(new_text);
				jQuery('[data-ticket=' + ticket_id + '] [data-type="assigned"] .result').animateHighlight();

				full_menu.find('.ticksymbol').remove();
				selected_item.prepend(ticksymbol);
				selected_item.addClass('active').siblings().removeClass('active');
				full_menu.removeClass('loading');

				hideActiveMenu();
			}
		});
	});

	// Assign Status
	jQuery('.action_assign_status').live("click",function(ev) {
		
		ev.preventDefault();
		selected_item = jQuery(this);
		new_text = selected_item.text();

		full_menu = selected_item.parent();
		full_menu.addClass('loading');

		ticket_id = full_menu.data('parent').data('object-id');
		new_status = selected_item.data('status-id');

		jQuery.ajax( {
			type: "POST",
			url: '/helpdesk/tickets/quick_assign/' + ticket_id,
			data: {assign:'status', value : new_status, _method: 'put'},
			success: function (data) {
				jQuery('[data-ticket=' + ticket_id + '] [data-type="status"] .result').text(new_text);
				jQuery('[data-ticket=' + ticket_id + '] [data-type="status"] .result').animateHighlight();

				full_menu.find('.ticksymbol').remove();

				jQuery('[data-ticket=' + ticket_id + ']').removeClass('ticket-status-4').removeClass('ticket-status-5');
				if (new_status == 4 || new_status == 5) {
					jQuery('[data-ticket=' + ticket_id + ']').addClass('ticket-status-' + new_status);
				}
				selected_item.prepend(ticksymbol);
				selected_item.addClass('active').siblings().removeClass('active');
				full_menu.removeClass('loading');
				hideActiveMenu();
			}
		});
	});

	// Assign Priority
	jQuery('.action_assign_priority').live("click",function(ev) {
		
		ev.preventDefault();
		selected_item = jQuery(this);
		new_text = selected_item.text();

		full_menu = selected_item.parent();
		full_menu.addClass('loading');

		ticket_id = full_menu.data('parent').data('object-id');
		new_priority = selected_item.data('priority-id');

		jQuery.ajax( {
			type: "POST",
			url: '/helpdesk/tickets/quick_assign/' + ticket_id,
			data: {assign:'priority', value : new_priority, _method: 'put'},
			success: function (data) {
				priority_colored_border = jQuery('[data-ticket=' + ticket_id + '] .priority-border');
				priority_colored_border.removeAttr('class').addClass('priority-border priority-' + priority_ids[new_priority]);

				jQuery('[data-ticket=' + ticket_id + '] [data-type="priority"] .result').text(new_text);
				jQuery('[data-ticket=' + ticket_id + '] [data-type="priority"] .result').animateHighlight();

				full_menu.find('.ticksymbol').remove();
				selected_item.prepend(ticksymbol);

				selected_item.addClass('active').siblings().removeClass('active');
				full_menu.removeClass('loading');

				hideActiveMenu();
			}
		});
	});

	jQuery('#leftViewMenu a[rel=default_filter]').click(function(ev) {
		setCookie('wf_order','created_at');
		setCookie('wf_order_type','desc');
	});
	jQuery('#leftViewMenu a').click(function(ev) {
		filter_opts_sisyphus.manuallyReleaseData();
	});
});

if (getCookie('ticket_list_updated') == "true") {
	if (supports_html5_storage()) {
		
		eval(window.localStorage['updated_ticket_list']);
		if (window.localStorage['is_unsaved_view']) {
			jQuery("#active_filter").addClass('unsaved').text(TICKET_STRINGS['unsaved_view']);
		}
		setCookie('ticket_list_updated',false);	
	}
}