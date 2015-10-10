HelpdeskReports.ChartsInitializer = HelpdeskReports.ChartsInitializer || {};

HelpdeskReports.ChartsInitializer.AgentSummary = (function () {
	var _FD = {
		populatetemplate: function(data){
			var metricsData = JST["helpdesk_reports/templates/agent_summary_tmpl"]({
				'data':  data,
				'report' : "agent"
			});
			var agentData = JST["helpdesk_reports/templates/metrics_name"]({
				'data':  data,
				'report' : "agent"
			});
			jQuery("[data-table='ticket-data']").html(metricsData);
			jQuery("[data-table='agent-name']").html(agentData);
		},
		bindevents: function(){
			jQuery('#reports_wrapper').on('click.helpdesk_reports.agent', "[data-action='data-tab-nav']", function (event) {
				_FD.actions.toggleTable(event);
			});
		},
		actions: {
			toggleTable: function (event) {
				var el = event.target || event.srcElement || event.currentTarget;
				var dataToLoad = (jQuery(el).attr('id') === 'agent-details-next' || jQuery(el).parent().attr('id') === 'agent-details-next') ? 'next' : 'prev';
				jQuery("[data-action='data-tab-nav']").removeClass('disabled');
				jQuery("#agent-details-"+dataToLoad).addClass('disabled');
				 // Todo : Remove when changing table to datatable
				if(dataToLoad === 'next'){
					jQuery('.footer').removeClass('shadow');
                    jQuery('.header').addClass('shadow');
					if (jQuery('html').attr('dir') === 'rtl'){
					 	jQuery("[data-table='wrapper']").animate({'right':'-100%'});
					}else{
						jQuery("[data-table='wrapper']").animate({'left':'-100%'});
					}
				}else{
					jQuery('.header').removeClass('shadow');
                    jQuery('.footer').addClass('shadow');
					if (jQuery('html').attr('dir') === 'rtl'){
					 	jQuery("[data-table='wrapper']").animate({'right':'0'});
					}else{
					 	jQuery("[data-table='wrapper']").animate({'left':'0'});
					}
				}
			}
		}
	};
	return  {
		init: function(data){
			_FD.populatetemplate(data);
			_FD.bindevents();
		}
	}
})();