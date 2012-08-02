
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
      jQuery.each(jQuery(".ticket-description-tip"), function(i, item){
        _self = jQuery(item);        
        var tipUrl = jQuery(item).data("tipUrl");
        jQuery(item).qtip({
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
				delay: 200,
				effect: function(offset) {
					jQuery(this).show("fade", 240); // "this" refers to the tooltip
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

	var choice = getCookie('ticket_view_choice');
	if (choice == 'list') {
		jQuery('.ticket-view-choice.ticket-view-list').click();
	} else {
		jQuery('.ticket-view-choice.ticket-view-detail').click();
	}
	
// ---- END OF extract from /helpdesk/shared/_ticket_view.html.erb ----


		//Clicking on the row (for ticket list only), the check box is toggled.
	jQuery('.tickets tbody tr').live('click',function(ev) {
		if (! jQuery(ev.target).is('input[type=checkbox]') && ! jQuery(ev.target).is('a') && ! jQuery(ev.target).is('.quick-action')) {
			var checkbox = jQuery(this).find('input[type=checkbox]').first();
			checkbox.prop('checked',!checkbox.prop('checked'));
			checkbox.trigger('change');
		}
	});

    jQuery('.tickets tbody tr .check :checkbox').live('change', function() {
        if (jQuery(this).prop('checked')) {
          jQuery(this).parent().parent().addClass('active');
        } else {
          jQuery(this).parent().parent().removeClass('active');
        }
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
			url: '/helpdesk/tickets/quick_assign/' + ticket_id,
			data: {assign: 'agent', value : agent_user_id},
			success: function (data) {
				jQuery('[data-ticket=' + ticket_id + '] [data-type="assigned"] .result').text(new_text);
				jQuery('[data-ticket=' + ticket_id + '] [data-type="assigned"] .result').animateHighlight(jQuery('body').css('backgroundColor'));

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

		parent = full_menu.data('parent');

		ticket_id = parent.data('object-id');
		new_status = selected_item.data('status-id');

		jQuery.ajax( {
			url: '/helpdesk/tickets/quick_assign/' + ticket_id,
			data: {assign:'status', value : new_status},
			success: function (data) {
				jQuery('[data-ticket=' + ticket_id + '] [data-type="status"] .result').text(new_text);
				jQuery('[data-ticket=' + ticket_id + '] [data-type="status"] .result').animateHighlight(jQuery('body').css('backgroundColor'));

				full_menu.find('.ticksymbol').remove();
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

		parent = full_menu.data('parent');

		ticket_id = parent.data('object-id');
		new_priority = selected_item.data('priority-id');

		jQuery.ajax( {
			url: '/helpdesk/tickets/quick_assign/' + ticket_id,
			data: {assign:'priority', value : new_priority},
			success: function (data) {
				priority_colored_border = jQuery('[data-ticket=' + ticket_id + '] .priority-border');
				priority_colored_border.removeAttr('class').addClass('priority-border priority-' + priority_ids[new_priority]);

				jQuery('[data-ticket=' + ticket_id + '] [data-type="priority"] .result').text(new_text);
				jQuery('[data-ticket=' + ticket_id + '] [data-type="priority"] .result').animateHighlight(jQuery('body').css('backgroundColor'));

				full_menu.find('.ticksymbol').remove();
				selected_item.prepend(ticksymbol);

				selected_item.addClass('active').siblings().removeClass('active');
				full_menu.removeClass('loading');

				hideActiveMenu();
			}
		});
	});


});

if (getCookie('ticket_list_updated') == "true") {
	eval(window.localStorage['updated_ticket_list']);
	if (window.localStorage['is_unsaved_view']) {
		jQuery("#active_filter").addClass('unsaved').text(TICKET_STRINGS['unsaved_view']);
	}
	setCookie('ticket_list_updated',false);
}