HelpdeskReports.ChartsInitializer = HelpdeskReports.ChartsInitializer || {};

HelpdeskReports.ChartsInitializer.TimeSpent = (function ($) {
	
	var _FD = {
			VIEW_MORE_ABOVE : 5,
			/* Builds the section markup
			*/
			bindEvents: function(){
	            $('input[type=radio][name=type]').change(function() {
			        HelpdeskReports.locals.current_type = this.value
			        _FD.buildChart(false);
			    });
	        },
			groupByDropDown : function(){
				var options = HelpdeskReports.locals.lifecycle_group_by_options;
				var keys = _.keys(HelpdeskReports.locals.lifecycle_group_by_options);
				var custom_fields = _.keys(HelpdeskReports.locals.custom_field_hash);
				var option_label;
				jQuery.each(keys,function(i,el){
						switch(el) {
							case 'product_id':
								option_label = I18n.t('ticket_fields.fields.product');
								break;
							case 'group_id':
								option_label = I18n.t('ticket_fields.fields.group');
								break;
							default:
								option_label = (_.contains(custom_fields,el)) ? options[el] :I18n.t('ticket_fields.fields.'+el);
						}
						var option = jQuery("<option value=" + el +">" + option_label  + "</option>")
						jQuery("[name=group_by]").append(option);
						option_label = '';
				});
				jQuery("[name=group_by]").val(HelpdeskReports.locals.current_group_by)
				if(HelpdeskReports.locals.current_group_by != 'group_id'){
					jQuery("[rel=suffix]").html(I18n.t('helpdesk_reports.in_each_group'));
				}else{
					jQuery("[rel=suffix]").html(I18n.t('helpdesk_reports.with_each_agent'));
				}
				var help_msg = HelpdeskReports.CoreUtil.getTimespentExportHelpText();
				jQuery('#timespent_aggregate_help_msg').text(help_msg);
			},
			construct : function() {
				var groups = _FD.chart_data;
				var self = this;

				$.each(groups.data,function(idx,group) {
					var title = group['name'];
					var total_hours = HelpdeskReports.CoreUtil.timeMetricConversion(group['total_time']);
					var group_level1_id = group['id'];
					var tmpl = JST["helpdesk_reports/templates/time_spent_tmpl"]({
		                title : title,
		                total_hours: total_hours,
		                id : group_level1_id,
		                showViewMore :_.keys(group['category']).length > self.VIEW_MORE_ABOVE,
						idx : idx
		            });

		            jQuery('#timespent_graph').append(tmpl);
				});
				self.buildChart(false);
			},
			buildChart : function(is_details_view,grp_idx) {

				var groups = _FD.chart_data;
				var current_trend = HelpdeskReports.locals.current_type;
				var self = this;
				var data = [];
				var order = [];
				if(is_details_view) {
					data.push(groups.data[grp_idx]);
				} else {
					data = groups.data
				}

				$.each(data,function(idx,group) {
					
					var labels = [];
					var data_array = [];
					var limited_rows;
					var series = group['category'];
					if(current_trend == "total") {
						order = group['category_sort_by_total']
					}else{
						order = group['category_sort_by_avg']
					}
					if(!is_details_view){
						limited_rows = order.slice(0,_FD.VIEW_MORE_ABOVE);
					} else {
						limited_rows = order;
					}
					
					$.each(limited_rows,function(lp,key) {
						var tuple = series[key];
						
						var total_time = parseFloat(tuple['total_time']);
						var avg_time = parseFloat(tuple['avg_time']);
						var point = {
							time : total_time,
							ticket_cnt : tuple['tkt_count'],
							avg : avg_time,
							perc: tuple['percent_time'],
							//stats : group['stats'][key],
							name : group['name'],
							condition_id : group['id'],
							id : tuple['id']
						}
						if(current_trend == "total") {
							point['y'] = total_time
						} else {
							point['y'] = avg_time;
						}
						data_array.push(point);
						labels.push(tuple['name']);
					});

					var chartData = [{
						name : 'Total Hours',
						data : data_array
					}];

					var settings = {
	                    renderTo: is_details_view ? 'content'  : group['id'] +'_bar_chart', 
	                    xAxisLabel: labels,
	                    chartData: chartData,
	                    enableTooltip: true,
	                    height : labels.length * 50 > 50 ? labels.length * 50 : 90
	                }
	                var groupByCharts = new barChartWithAxis(settings);
	                groupByCharts.barChartGraph();
	                
				});
			}	
	}
	return  {
		init: function(data){
			_FD.chart_data = data;
			_FD.bindEvents();
			_FD.construct();
			_FD.groupByDropDown();
		},
		redraw : function(is_details_view,grp_idx){
			_FD.buildChart(is_details_view,grp_idx);	
		}
	}
})(jQuery);