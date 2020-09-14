/*jslint browser: true, devel: true */
/*global  App, bulkActionButtonsDisabled, updateWorkingAgents */

window.App = window.App || {};
window.App.Tickets = window.App.Tickets || {};
(function ($) {
	"use strict";

	App.Tickets.TicketList = {
		onVisit: function (data) {
			jQuery('#ticket-toolbar .bulk_action_buttons .btn').addClass('disabled').prop('disabled', true).attr("disabled","disabled");
			this.bindEventsInTicketToolbar();
			TicketListEvents();
			App.Tickets.Merge_tickets.initialize();
			this.filterSearch();

		},
		// This script moved from html page (shared/_ticket_toolbar.html)
		bindEventsInTicketToolbar: function () {
			
	  		jQuery(document).on("click.ticket_list", '#ticket-close-all-confirmation-submit', function(){
		    	jQuery('#close_all_ticket_btn').trigger('click');
		  	});

		  	jQuery(document).on("click.ticket_list", '#ticket-spam-all-confirmation-submit', function(){
		    	jQuery('#spam_all_ticket_btn').trigger('click');
		  	});

		  	jQuery(document).on("click.ticket_list", '#ticket-delete-all-confirmation-submit', function(){
		    	jQuery('#delete_all_ticket_btn').trigger('click');
		  	});

		  	jQuery(document).on("click.ticket_list", '#empty-spam-confirmation-submit', function(){
		    	jQuery('#empty_spam').trigger('click');
		  	});

		  	jQuery(document).on("click.ticket_list", '#empty-trash-confirmation-submit', function(){
		    	jQuery('#empty_trash').trigger('click');
		  	});

		  	jQuery(document).on("click.ticket_list", '[data-action="merge"]', function(ev){
		      	var selected_tickets=[];
		      	var parameters=[];
		      	jQuery("#tickets-expanded .selector:checked").each(function(){
		        	selected_tickets.push(jQuery(this).val());
		      	});
		      	jQuery.ajax({
		        	type: 'POST',
		        	url: '/helpdesk/merge_tickets/bulk_merge',
		        	data: { "source_tickets" : selected_tickets, "redirect_back" : true },
		        	success: function(data){
						jQuery('#merge_freshdialog-content').html(data);
					}
			    });
		  	});

		  	jQuery(document).on('click.ticket_list','.tooltip', function(){
		    	jQuery(this).twipsy('hide');
		  	});

		  	//load script only if bulk close validation feature enabled
		  	if(closeValidationLaunched){
		  		jQuery(document).on('click.ticket_list', '#failed-tickets', function(e) {
			  		e.preventDefault();
			  		jQuery('#failed-tickets-popup').remove();
			  		if(jQuery(this).data('tickets')){
			  			failedTicketData = failedTicketData ? failedTicketData : {};
			  			failedTicketData.failed_tickets = jQuery(this).data('tickets'); 
			  			failedTicketData.title = jQuery(this).data('title'); 
			  			failedTicketData.description = jQuery(this).data('description'); 
			  		}
			  		var data = {
			      		targetId : '#failed-tickets-popup',
			      		title : failedTicketData.title,
			      		width:  '710',
			      		destroyOnClose : false,
			      		templateFooter: false,
			      		templateHeader: "<div class='modal-header'><h3 class='ellipsis modal-title'>Bulk Close Tickets</h3>"
			      					+"<div><abbr>"+failedTicketData.description+"</abbr></div></div>"
			    	}
			    	jQuery.freshdialog(data);
			    	var failedTickets = failedTicketData.failed_tickets;
			    	var listData = "";
			    	jQuery.each(failedTickets, function(index, item){
			    		listData += "<li class='ellipsis failed_ticket' data-index="+ index +" data-failed-ticket-id="+item.id+">"+ 
			    		"<span class='subject ellipsis'>"+ item.subject + "  #"+item.display_id+ "</span><span class='updated_label hide'>Updated</span>"+
			    		"</li>";
			    	});
			    	jQuery('#failed-tickets-popup .modal-body').html("<ul class='failed_ticket_list'>" + listData + "</ul> <div class='ticket_properties_list'></div>");
			  	});

			  	jQuery(document).on('click.ticket_list', '.failed_ticket', function(e) {
			  		e.stopPropagation();
			  		e.preventDefault();
			  		var $properties_container = jQuery('.ticket_properties_list');
			  		$properties_container.empty();
			  		if($properties_container.hasClass('flow_in')){
			  			$properties_container.addClass('sloading loading-small loading-block');
			  		}
			  		$properties_container.addClass('flow_in');
			  		jQuery('.failed_ticket').removeClass('active').addClass('popup-active');
			  		jQuery(this).addClass('active');
			  		jQuery.ajax({
			  			url : '/helpdesk/tickets/'+ jQuery(this).data('failed-ticket-id')+'/component?component=ticket_fields',
			  			type: 'GET',
			  			contentType: 'application/text',
			  			success: function(data) {
			  				$properties_container.removeClass('sloading loading-small loading-block').html(data).prepend('<h3 class="title">Properties</h3>');
			  				App.Tickets.TicketList.validateRequiredOnCloseTickets();
			  			}
			  		});
			  	});

			  	jQuery(document).on('click', "#failed-tickets-popup:not('.failed_ticket')", function(e){
			  		if(jQuery(e.target).parents('.ticket_properties_list').length <= 0){
			  			var $ticket_properties_list = jQuery('.ticket_properties_list');
			  			$ticket_properties_list.removeClass('flow_in');
			  			jQuery('.failed_ticket').removeClass('active').removeClass('popup-active');
			  			setTimeout(function(){
			  				if(!jQuery('.ticket_properties_list').hasClass('flow_in')){
			  					$ticket_properties_list.empty();
			  				}
			  			}, 3000);
			  		}
			  	});

			  	jQuery(document).on('submit.ticket_list', '.ticket_properties_list #custom_ticket_form', function(e){
			  		e.preventDefault();
					e.stopPropagation();
					var tkt_form = $('.ticket_properties_list #custom_ticket_form');
					if (tkt_form.valid()) {
						App.Tickets.TicketList.submitTicketProperties();
					}else{
						App.Tickets.TicketList.scrollToError();
					}
			  	});

			  	//code added for agent and group filed change event capturing in bulk close validation popup
			  	jQuery(document).on('change.ticket_list', '.ticket_properties_list #helpdesk_ticket_group_id', function(e){
					// get the current selected agent if any
					var select_agent = jQuery('.ticket_properties_list .default_agent select')[0];
					var prev_val = select_agent.options[select_agent.selectedIndex].value;

					jQuery('.ticket_properties_list .default_agent')
						.addClass('sloading loading-small loading-right');

					$.ajax({type: 'GET',
						url: prev_val == "" ? '/helpdesk/commons/group_agents/'+this.value : '/helpdesk/commons/group_agents/'+this.value+"?agent="+prev_val,
						contentType: 'application/text',
						success: function(data){
							jQuery('.ticket_properties_list .default_agent select')
								.html(data)
								.trigger('change');

							jQuery('.ticket_properties_list .default_agent').removeClass('sloading loading-small loading-right');
						  }
					});
				});

				jQuery(document).on('change.ticket_list' ,'.ticket_properties_list #helpdesk_ticket_status', function(event){ 

					var _this = $(this);
					var previous =  _this.data("previous");
					//in case of deleted status, manually pass the condition for api trigger
					if(previous !== "" && !previous){
						previous = true;
					}
					_this.data("previous", _this.val());
					var select_group = jQuery('.ticket_properties_list .default_internal_group select')[0];
					var prev_val = ""
					if(select_group){
			      		prev_val = select_group.options[select_group.selectedIndex].value;
					}

					if(previous && select_group){
						jQuery('.ticket_properties_list .default_internal_group').addClass('sloading loading-small loading-right');
						var val = jQuery(".ticket_properties_list #helpdesk_ticket_status").val();

					    jQuery.ajax({type: "GET",
					      	url: prev_val == "" ? "/helpdesk/commons/status_groups?status_id="+val : "/helpdesk/commons/status_groups?status_id="+val+"&group_id="+prev_val,
					      	contentType: "application/text",
					      	success: function(data){
					    		jQuery('.ticket_properties_list #helpdesk_ticket_internal_group_id').html(data).trigger('change');
					        	jQuery('.ticket_properties_list .default_internal_group').removeClass('sloading loading-small loading-right');
					      	}
					    });
					}
				});
				jQuery(document).on("change.ticket_list", '.ticket_properties_list #helpdesk_ticket_internal_group_id', function(e){
				    jQuery('.ticket_properties_list .default_internal_agent').addClass('sloading loading-small loading-right');
				    var select_group = jQuery('.ticket_properties_list .default_internal_agent select')[0];
			      	var prev_val = select_group.options[select_group.selectedIndex].value;
					if(this.value){
						jQuery.ajax({
					       	type: 'GET',
					      	url:  prev_val == "" ? '/helpdesk/commons/group_agents/'+this.value : '/helpdesk/commons/group_agents/'+this.value+"?agent="+prev_val,
					      	contentType: 'application/text',
					      	success: function(data){
					        	jQuery('.ticket_properties_list #helpdesk_ticket_internal_agent_id').html(data).trigger('change');
					        	jQuery('.ticket_properties_list .default_internal_agent').removeClass('sloading loading-small loading-right');
					      	}
					    });
					}else{
			      		jQuery('.ticket_properties_list #helpdesk_ticket_internal_agent_id').html("<option value=''>...</option>").trigger('change');
						jQuery('.ticket_properties_list .default_internal_agent').removeClass('sloading loading-small loading-right');
					}  
				});

				jQuery(document).on('click.ticket_list', '.ticket_properties_list .date.field', function(e){
					if(jQuery('#ui-datepicker-div').is(':visible')){
						jQuery('.ticket_properties_list ul#TicketPropertiesFields').css('overflow-y', 'hidden');
					}else{
						jQuery('.ticket_properties_list ul#TicketPropertiesFields').css('overflow-y', 'auto');
					}
				});

				jQuery(document).on('click.ticket_list', '.ticket_properties_list', function(e){
					setTimeout(function(){
						if(jQuery('#ui-datepicker-div').is(':visible')){
							jQuery('.ticket_properties_list ul#TicketPropertiesFields').css('overflow-y', 'hidden');
						}else{
							jQuery('.ticket_properties_list ul#TicketPropertiesFields').css('overflow-y', 'auto');
						}
					}, 200);
				});

				jQuery(document).on('change.ticket_list', '.ticket_properties_list input.date', function(e){
					setTimeout(function(){
						if(jQuery('#ui-datepicker-div').is(':visible')){
							jQuery('.ticket_properties_list ul#TicketPropertiesFields').css('overflow-y', 'hidden');
						}else{
							jQuery('.ticket_properties_list ul#TicketPropertiesFields').css('overflow-y', 'auto');
						}
					}, 500);
				});
		  	}

		},
		onLeave: function() {
			$(document).off('.ticket_list');
			$('body').off('.ticket_list');
			jQuery('body').off('.filterList');
			App.Tickets.Merge_tickets.unBindEvent();
		},
		filterSearch: function(){
			jQuery("#filter-template").filterList("#filter-template",".tkt_views",function(element){
   				element.find('a').trigger('click');
   			}); 
		},
		validateRequiredOnCloseTickets: function() {
			var required_closure_elements = $(".ticket_properties_list .required_closure");
			required_closure_elements.each(function(){
	          	element = $(this)
	          	if(element.prop("type") == "checkbox"){
	            	element.prev().remove()
	          	}
          		element.parents('.field').children('label').find('.required_star').remove();
          		element.addClass('required').parents('.field').children('label').append('<span class="required_star">*</span>');
	        });
		},
		submitTicketProperties: function() {
			var tkt_form = $('#custom_ticket_form');
			var submit = $('#custom_ticket_form .btn-primary');
			submit.button('loading');
			submit.attr('disabled','disabled');

			$.ajax({
				type: 'POST',
				url: tkt_form.attr('action'),
				data: tkt_form.serialize(),
				dataType: 'json',
				success: function(response) {
					submit.val(submit.data('saved-text')).addClass('done');
					setTimeout( function() {
						submit.button('reset').removeClass('done');
					}, 2000);
					jQuery('.failed_ticket.active .updated_label').removeClass('hide');

				},
				error: function(jqXHR, textStatus, errorThrown) {
					submit.text(submit.data('default-text')).prop('disabled',false);
				}
			});
		},
		scrollToError: function(){
			var errorLabel = $("label[class='error'][style!='display: none;']");
			var elem = errorLabel.parent().children().first();
			var topContainerHeight = elem.parents('ul#TicketPropertiesFields').offset().top;
			jQuery("body .ticket_properties_list ul#TicketPropertiesFields").animate({
	          	scrollTop: elem.offset().top - topContainerHeight
	        }, 'slow');
		}
	}
}(jQuery));

bulkActionButtonsDisabled = function () {
	if (jQuery('#ticket-list .check .selector:checked').length > 0 && !jQuery("#all-views").data("selectallMode")) {
		jQuery('#ticket-toolbar .bulk_action_buttons .btn').removeClass('disabled').prop('disabled', false).removeAttr('disabled');
	} else {
		jQuery('#ticket-toolbar .bulk_action_buttons .btn').addClass('disabled').prop('disabled', true).attr("disabled","disabled");
	}
}
ticksymbol = "<span class='icon ticksymbol'></span>";
priority_ids = {1: "low", 2:"medium", 3:"high", 4:"urgent"};

TicketListEvents = function() {

Fjax.beforeNextPage = function() {
	jQuery('#ticket_pagination').html('<span class="disabled prev_page"><span></span></span><span class="disabled next_page"><span></span></span>');
	// Disabling Prev/Next pagination buttons when switching views or going to next page.
}
jQuery('body').append('<div id="agent_collision_container" class="hide"></div>');

// ---- EXTRACTED FROM /helpdesk/shared/_tickets.html.erb ----
	jQuery(".ticket-description-tip").livequery(function () {
		var _self = jQuery(this);        
        var tipUrl = _self.data("tipUrl");
        var ticket_id = _self.parent().parent().parent().data('ticket');
        _self.qtip({
        	prerender: false,
        	id: ticket_id,
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
				text: "<div class='ui-tooltip-ticket-loading'>"+TICKET_STRINGS['tooltip_loading']+"</div>",
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
          	},
          	events: {
          		show: function(event, api) {
          			working_agents = jQuery('#working_agents_' + ticket_id);
          			if (working_agents.length > 0) {
          				working_agents = working_agents.detach();
          				jQuery(api.elements.content).after(working_agents);

          				show_working_agents = false;
          				if (!working_agents.find('[rel=viewing_agents]').hasClass('hide')) {
          					jQuery(api.elements.content).parent().addClass('hasViewers');
          					show_working_agents = true;
          				} 
          				if (!working_agents.find('[rel=replying_agents]').hasClass('hide')) {
          					jQuery(api.elements.content).parent().addClass('hasReplying');
          					show_working_agents = true;
          				} 
          				if (show_working_agents) {
          					jQuery('#working_agents_' + ticket_id).show();
          				} else {
          					jQuery('#working_agents_' + ticket_id).hide();
          				}
          			}
          		},
          		hide: function(event, api) {
          			working_agents = jQuery(api.elements.content).parent().find('#working_agents_' + ticket_id);
          			if (working_agents.length > 0) {
          				working_agents = working_agents.detach();
          				jQuery('#agent_collision_container').append(working_agents);
          				jQuery(api.elements.content).parent().removeClass('hasViewers hasReplying');
          			}
          		}
          	}
        }); 
	});

	//For Agent Collision data to appear in Ticket Tooltips.
	updateWorkingAgents = function(key,type) {
		collision_dom = jQuery($(key));
		ticket_id = jQuery($(key)).data('ticket-id');
		var working_agents;
		if (jQuery('#working_agents_' + ticket_id).length == 0) {
			working_agents = jQuery('<div class="working-agents" id="working_agents_' + ticket_id + '" />');
			jQuery(working_agents).append(jQuery('<div rel="viewing_agents" class="hide symbols-ac-viewingon-listview" />'));
			jQuery(working_agents).append(jQuery('<div rel="replying_agents" class="hide symbols-ac-replyon-listview" />'));
			var container;
			if (jQuery('#ui-tooltip-' + ticket_id).length > 0) {
				container = jQuery('#ui-tooltip-' + ticket_id);
			} else {
				container = jQuery('#agent_collision_container');
			}
			container.append(working_agents);
		}

		working_agents = jQuery('#working_agents_' + ticket_id);


		if(type == "viewing") {
			viewing_agents = jQuery(working_agents).find("[rel=viewing_agents]");
			if (collision_dom.find("[rel=viewing_agents_tip]").html() != ''){
				jQuery('#ui-tooltip-' + ticket_id).addClass('hasViewers');
				viewing_agents.removeClass('hide');
				jQuery('#working_agents_' + ticket_id).show();
			} else {
				jQuery('#ui-tooltip-' + ticket_id).removeClass('hasViewers');
				viewing_agents.addClass('hide');
			}
			viewing_agents.html(collision_dom.find("[rel=viewing_agents_tip]").html());

		} else if(type == "replying") {
			replying_agents = jQuery(working_agents).find("[rel=replying_agents]");
			if (collision_dom.find("[rel=replying_agents_tip]").html() != ''){
				jQuery('#ui-tooltip-' + ticket_id).addClass('hasReplying');
				replying_agents.removeClass('hide');
				jQuery('#working_agents_' + ticket_id).show();
			} else {
				jQuery('#ui-tooltip-' + ticket_id).removeClass('hasReplying');
				replying_agents.addClass('hide');
			}
			replying_agents.html(collision_dom.find("[rel=replying_agents_tip]").html());

		}		
	}
        
     jQuery(".nav-trigger").showAsMenu();

// ---- END OF extract from /helpdesk/shared/_tickets.html.erb ----

// ---- EXTRACTED FROM /helpdesk/shared/_ticket_view.html.erb ----
  
	jQuery('#recent_ticket_count').click(function(){
	    jQuery("#ticket-list").html("<div class='sloading loading-small loading-block'></div>"); 
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
	// jQuery('.tickets tbody tr').on('click',function(ev) {
	// 	if (! jQuery(ev.target).is('input[type=checkbox]') && ! jQuery(ev.target).is('a') && ! jQuery(ev.target).is('.quick-action')) {
	// 		var checkbox = jQuery(this).find('input[type=checkbox]').first();
	// 		checkbox.prop('checked',!checkbox.prop('checked'));
	// 		checkbox.trigger('change');
	// 	}
	// });

	var checkboxStore = null;
	jQuery(document).on('click.ticket_list', '.tickets tbody tr .check :checkbox',function(e){
	var $checkboxes = jQuery('.tickets tbody tr .check :checkbox');
	
	// Add selection border on click
    var index = jQuery(e.target).parent().parent().index();
    jQuery('#ticket-list').data('menuSelector').setCurrentElement(index);

		if(!checkboxStore) {
			checkboxStore = e.target;
			return;
		}
		if(e.shiftKey) {
			var start = $checkboxes.index(e.target);
			var end = $checkboxes.index(checkboxStore);
			$checkboxes.slice(Math.min(start,end), Math.max(start,end)+ 1).prop('checked', e.target.checked).change();
		}
		checkboxStore = e.target;
	});

	jQuery(document).on('change.ticket_list', 'tbody tr .check :checkbox', function() { 
        if (jQuery(this).prop('checked')) {
          jQuery(this).parent().parent().addClass('active');
        } else {
          jQuery(this).parent().parent().removeClass('active');
        }        
        var select_all_checkbox = jQuery("#helpdesk-select-all");
        var select_all_previous_state = select_all_checkbox.prop('checked');
        select_all_checkbox.prop('checked', jQuery('.tickets tbody tr .check :checkbox:checked').length == jQuery('.tickets tbody tr .check :checkbox').length);
        if (select_all_previous_state !== select_all_checkbox.prop('checked')){
            select_all_checkbox.trigger("change");
        }
        bulkActionButtonsDisabled();
    });

	//bulkActionButtonsDisabled();
	
	//TODO. Need to remove this. Added because dynamic menus are dom manuplations instead of style.
	// Quick Actions
	jQuery(document).on("click.ticket_list", '.action_assign', function(ev) {
		ev.preventDefault();

		selected_item = jQuery(this);

		if (selected_item.hasClass('active')) {
			hideActiveMenu();
			return false;
		}

		full_menu = selected_item.parent().parent();
		full_menu.addClass('loading');

		ticket_id = full_menu.data('parent').data('object-id');
		agent_user_id = selected_item.data('agent-id');
		assign_action = selected_item.data('assign-action');
		new_value = selected_item.data('value');
		new_text = selected_item.data('text') || selected_item.text();
		jQuery("#all-views").data("quickAction", ticket_id);

		jQuery.ajax( {
			type: "POST",
			url: '/helpdesk/tickets/quick_assign/' + ticket_id,
			data: {assign: assign_action, value : new_value, disable_notification: ev.shiftKey, _method: 'put'},
			success: function (data) {
				if(data.success){
					jQuery('[data-ticket=' + ticket_id + '] [data-type="' + assign_action + '"] .result').text(new_text);
					jQuery('[data-ticket=' + ticket_id + '] [data-type="' + assign_action + '"] .result').animateHighlight();

					//Special Processing for Priority
					if (assign_action == 'priority') {
						priority_colored_border = jQuery('[data-ticket=' + ticket_id + '] .priority-border');
						priority_colored_border_1 = jQuery('[data-ticket=' + ticket_id + '] .sc-item-cursor');
						priority_colored_border.removeAttr('class').addClass('priority-border priority-' + priority_ids[new_value]);
						priority_colored_border_1.removeAttr('class').addClass('sc-item-cursor priority-border priority-' + priority_ids[new_value] + ' shorcuts-info');
					}

					//Special Processing for Status
					if (assign_action == 'status') {
						jQuery('[data-ticket=' + ticket_id + ']').removeClass('ticket-status-4').removeClass('ticket-status-5');
						if (new_value == 4 || new_value == 5) {
							jQuery('[data-ticket=' + ticket_id + ']').addClass('ticket-status-' + new_value);
						}
					}

					full_menu.find('.ticksymbol').remove();
					selected_item.prepend(ticksymbol);
					selected_item.addClass('active').siblings().removeClass('active');
				}else{
					jQuery("#noticeajax").empty().hide();
					jQuery("#notice").empty().hide();
					jQuery("#noticeajax").html(data.message).show();
        			// jQuery.scrollTo("body");
        			jQuery('body #failed-tickets').trigger('click.ticket_list');
        			jQuery("#noticeajax").empty().hide();
				}
				full_menu.removeClass('loading');
				hideActiveMenu();
			}
		});

		return false;
	});

	jQuery(document).on('click.ticket_list', '#leftViewMenu a[rel=default_filter]', function(ev) {
		setCookie('wf_order','created_at');
		setCookie('wf_order_type','desc');
	});

	jQuery(document).on('click.ticket_list','.link-item',function(){
		jQuery('#filter-template').focus();
		if(jQuery('.tkt_views').size() > 15){
            jQuery('#leftViewMenu').addClass('hasSearch');
        }else{
            jQuery('.filter-search').addClass('hide');
         }
		var currActive = jQuery('[data-picklist]').children('li.active');
		currActive.removeClass('active');
        jQuery('[data-picklist]').find('li:visible').first().addClass('active');
	});

	jQuery(document).on('click.ticket_list', '#toggle_select_all', function(ev) {
      	ev.preventDefault();
      	var all_view_selector = jQuery("#all-views");
      	updateBulkActionTicketCount();
      	var select_all_mode = all_view_selector.data("selectallMode");
      	if(!select_all_mode) {
        	all_view_selector.data("selectallMode", true);
        	bulkActionButtonsDisabled();
        	jQuery("#toggle_select_all_default").hide();
        	jQuery("#toggle_select_all_clear").show();
        	jQuery("#toggle_select_all_page").hide();
        	jQuery("#toggle_select_all_view").show();
        	jQuery('.dynamic-menu').addClass('disabled').prop('disabled', true);
        	freezeTicketListView(true);
        	toggleTicketToolbar(true);
	  	}
      	else {
        	all_view_selector.data("selectallMode", false);
        	bulkActionButtonsDisabled();
        	jQuery("#toggle_select_all_default").show();
        	jQuery("#toggle_select_all_clear").hide();
        	jQuery("#toggle_select_all_view").hide();
        	jQuery("#toggle_select_all_page").show();
        	jQuery('.dynamic-menu').removeClass('disabled').prop('disabled', false);
        	freezeTicketListView(false);
        	toggleTicketToolbar(false);
        	jQuery("#helpdesk-select-all").removeAttr("checked").trigger("toggleState").trigger('change');
      	}
	});

  	jQuery("#helpdesk-select-all").bind("change", function(ev){
    	if(!selectAllBarAvailable()) {
      		return;
    	}
    	var select_all_bar = $J("#select_all_alert");
    	updateBulkActionTicketCount();
    	if($J(this).prop("checked")){
      	disableAutoRefresh();
      	select_all_bar.show();
    	}
    	else {
      	enableAutoRefresh();
      	select_all_bar.hide();
    	}
  	});

  	var toggleTicketToolbar = function(select_all_mode){

  		if(select_all_mode){
        	jQuery("#ticket-toolbar .bulk_action_buttons").hide();
        	jQuery("#ticket-toolbar .admin_bulk_actions").show();
  		}
  		else {
        	jQuery("#ticket-toolbar .admin_bulk_actions").hide();
        	jQuery("#ticket-toolbar .bulk_action_buttons").show();
  		}
  	}

  	var updateBulkActionTicketCount = function() {
    	var tkt_count = parseInt(jQuery("#ticket_list_count").text());
    	if (!isNaN(tkt_count)) {
      		jQuery(".admin_select_all_ticket_count").text(tkt_count);
    	}
    	var num_tickets_in_page = jQuery("#tickets-expanded input[type=checkbox]").length
    	jQuery(".admin_select_all_ticket_count_page").text(num_tickets_in_page);
  	}
  	var selectAllBarAvailable = function() {
      	return !(jQuery("#select_all_alert").length < 1 || jQuery(".toolbar_pagination_full").length < 1);
  	};

  	var freezeTicketListView = function(select_all_view){
     	var select_all_checkbox = jQuery("#helpdesk-select-all");
     	if(select_all_view === true){
      		jQuery("#tickets-expanded input[type=checkbox]").attr("disabled", "disabled");
      		select_all_checkbox.attr("disabled", "disabled");
     	}
     	else {
      		jQuery("#tickets-expanded input[type=checkbox]").removeAttr("disabled");
      		select_all_checkbox.removeAttr("disabled");       
     	}
  	};

  	jQuery(".filter_item").bind("change", function(){
      	if(!selectAllBarAvailable()){
          	return;
      	}
      	if(jQuery("#all-views").data("selectallMode")){
        	jQuery("#toggle_select_all").trigger("click");
      	}
      	var select_all_checkbox = jQuery("#helpdesk-select-all");
      	select_all_checkbox.prop("checked", false);
      	select_all_checkbox.removeAttr("disabled"); 
      	select_all_checkbox.trigger("change"); 
  	});

	// Uncheck select all checkbox before navigate to next & prev page (in pagination)
	jQuery(document).on('click.ticket_list', '.next_page, .prev_page', function () {
		jQuery('#helpdesk-select-all').removeAttr('checked');
	});

  	jQuery('body').on('click.ticket_list','a[data-target="#bulk"]', function () {
    	jQuery("#bulk").remove();
  	});

	jQuery(window).on('resize.ticket_list', function(){
		bulkActionButtonsDisabled();
	}).trigger('resize');
}