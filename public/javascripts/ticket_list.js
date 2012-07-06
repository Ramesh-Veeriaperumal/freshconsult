

// ---- EXTRACTED FROM /helpdesk/shared/_tickets.html.erb ----
      jQuery.each(jQuery(".ticket-description-tip"), function(i, item){
        _self = jQuery(item);        
        var tipUrl = jQuery(item).data("tipUrl");
        jQuery(item).qtip({
            position: { 
              my: 'top left',
              at: 'bottom left',
              target: _self.parent(),
              viewport: jQuery(window) 
            }, 
           style : {
            classes: 'ui-tooltip-ticket ui-tooltip-rounded'
           },             
           content: {
              text: '<%= t("index_tooltip_loading_msg")%>',
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
	/* new PeriodicalExecuter(function(pe) {
		params = jQuery("#FilterOptions").serializeArray(); 
		params.push({name:"latest_updated_at",value:jQuery('#latest_updated_at').prop('value')})
	
		jQuery.ajax({
		  url:"/helpdesk/tickets/latest_ticket_count",
		  type: "POST",
	      dataType: "script",
		  data: params,
		  success: function(data) {
		  	if(data > 0) {
	  			jQuery('#recent_ticket_count')
	  			  .html(plural(data, "<%= t('latest_ticket') %>", "<%= t('latest_tickets') %>"));
	  			jQuery('#recent_ticket_count').slideDown();
			}
		  }
		});
	}, 30); */
  
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

	jQuery(function() {
		var choice = getCookie('ticket_view_choice');
		if (choice == 'list') {
			jQuery('.ticket-view-choice.ticket-view-list').click();
		} else {
			jQuery('.ticket-view-choice.ticket-view-detail').click();
		}

	})

// ---- END OF extract from /helpdesk/shared/_ticket_view.html.erb ----


// Quick Actions
// Assign Agent
console.log('asdas');
jQuery(document).ready(function() {
	jQuery('.action_assign_agent').live("click",function(ev) {
		console.log('Assigning Agent');
		// ev.preventDefault();
		ticket_id = jQuery(this).data('ticket-id');
		agent_user_id = jQuery(this).data('agent-id');
		new_text = jQuery(this).text();

		jQuery.ajax( {
			url: '/helpdesk/tickets/quick_assign_agent/' + ticket_id,
			data: {agent : agent_user_id},
			success: function (data) {
				jQuery('[data-ticket=' + ticket_id + '] [data-type="assigned"] .result').text(new_text);
			}
		});
	});
});

// Assign Status