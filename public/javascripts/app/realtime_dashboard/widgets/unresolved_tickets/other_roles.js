RealtimeDashboard.Widgets = RealtimeDashboard.Widgets || {};
RealtimeDashboard.Widgets.UnresolvedTickets = RealtimeDashboard.Widgets.UnresolvedTickets || {};

RealtimeDashboard.Widgets.UnresolvedTickets.OtherRoles = function(container,widget_name,group_by,workload,preview_limit) {
	
	/*
		params: 
		{:group_id => 1} <NOTE:: SEND ONLY IF ITS FILTERED>
		{:group_by => "responder_id,status"},
		{:workload => "responder_id"}

		params:
		{:group_id => 1} <NOTE:: SEND ONLY IF ITS FILTERED>
		{:group_by => "responder_id,status"},
		{:workload => "responder_id"}
		
		params: 
		{:group_id => 1} <NOTE:: SEND ONLY IF ITS FILTERED>
		{:group_by => "responder_id,priority"},
		{:workload => "responder_id"}
	*/	
	var _fd = {
		constants : {
			endPoint : '/helpdesk/dashboard/unresolved_tickets_workload'
		},
		fetchData : function(forceRefresh,group_id) {
			var self = this;
			if(true || self.core.refresh.did_time_expire() || !self.core.readFromLocalStorage(_fd.widget_name)) {
				var opts = {
		            data: self.constructParams(group_id),
		            url: self.constants.endPoint,
		            success: function (response) {
		            	_fd.resp = response.workload;
		            	self.core.addToLocalStorage(_fd.widget_name,_fd.resp);
		                self.parseResponse();
		                self.showTimeStamp();
		            }
		        };
		        self.core.makeAjaxRequest(opts);
			} else{
				_fd.resp = JSON.parse(self.core.readFromLocalStorage(_fd.widget_name));
				self.parseResponse();
			}
			
		},
		paginate : {
			prev : function() {
				
			},
			next : function() {
				
			}
		},
		parseResponse : function () {
			var self = this;
			if(!jQuery.isEmptyObject(_fd.resp)) {
				self.constructChart(_fd.resp,_fd.container,true);
			} else {
				self.core.appendNoData(_fd.container + '_widget');
			}
			
			jQuery('#filter_by_group_dropdown').removeClass('disabled sloading');
		},
		constructParams : function(group_id) {
			var data = {};
			data['group_by'] = _fd.group_by;
			data['workload'] = _fd.workload;
			if(group_id != '-') {
				data['group_id'] = group_id;
			}
			return data;
		},
		bindEvents : function() {
			var self = this;

			jQuery(document).on('click.realtimeDashboard', '.view_all_link', function (e) {
				jQuery('.unresolved_tickets').barChart('destroy');
				self.sidebarModalChart( jQuery(e.currentTarget).data('content') );
			});
		
			jQuery(document).on("next_page",function(ev,data){
				//console.log(_fd.widget_name,data.chart_name);
				if(_fd.widget_name == data.chart_name) {
					self.fetchData();
				}
			});

			jQuery(document).on('group_change',function(ev,data){
				self.fetchData(true,data.group_id);
			});
		},
		checkIsSidebarViewing: function () {
			if(jQuery('.slider-modal').is(":visible")) {
				var chartName = jQuery('.unresolved_tickets').data('chartName');
				this.sidebarModalChart(chartName);
			}
		},
		sidebarModalChart: function (values,container) {
			var self = this;
			self.core.controls.showDashboardDetails(_fd.widget_name,I18n.t(self.locale_key),false,_fd.formated_time);
			setTimeout(function(){
				self.constructChart(values,container,false);
			},10)
		},
		constructChart: function (data,container,isMainView) {
			var self = this;
			var series_limit = 4;
			var limit = _fd.preview_limit;
			var values = data;
			var original = jQuery.extend({},data);
			
			if(isMainView) {
				if(data['order'].length > limit) {
					values['order'] = data['order'].slice(0,limit);
				}	
			} 
			
			var categories = values.order;
			var series = values.series;
			var spliced_series = [];
			var chartData = [],temp = {};
			var max = 0;

			//Show only top four series and club rest into 'other' series
			if(series.length > series_limit) {
				spliced_series = series.slice(0,series_limit);
				spliced_series.push('Others');
			} else {
				spliced_series = series;
			}
			
			/* Constructing data for graph */
			jQuery.each(spliced_series,function(i,el) {
				chartData.push({
					name : el,
					data : []
				});
				temp[el] = [];
			});	
			
			jQuery.each(categories,function(i,el) {
				var category = _fd.resp['data'][el];
				var sum = 0;
				var others_sum = 0;
				jQuery.each(category,function(j,row) { 
					if(jQuery.inArray(row.name,spliced_series) != -1) {
						temp[row.name].push(row.value);	
					} else{
						others_sum += row.value;
					}
					sum += row.value;

				});
				if(temp['Others'] != undefined) {
					temp['Others'].push(others_sum);	
				}
				if(max == 0 || max < sum){
					max = sum;
				}
			});

			jQuery.each(chartData,function(i,el) {
				 el['data'] = temp[el.name];
				 el['locale_key'] = self.locale_key;
			});
			/* Graph opts */
			var opts = {
				type : _fd.widget_name,
				chartData : chartData,
				xAxisLabel : categories,
				container : container
			}
			if(isMainView) {
				if(_fd.widget_name != 'unresolved_tickets_by_status') {
					opts.height = 220;
				} else {
					opts.height = 200;
				}
				
				opts.chartClick = function(e) {
					self.sidebarModalChart(original,'graph_space');
				}
				opts.legend = true;
				opts.gridLineWidth = 1;
				opts.chartCursor = true;
				opts.showYAxisLabels = true;
				opts.scrollbar = false;
			} else {
				opts.height = 250;
				opts.enableHover = true;
				opts.tooltip_callback = self.tooltip_callback;
				opts.hover_callback = self.hover_callback,
				opts.showYAxis = false;
				opts.showYAxisLabels = false;
				if(7 < categories.length){
					opts.max = 7;	
				}
				opts.scrollbar = true;
				opts.crossHair = true;
				opts.total_action =  function() {
					self.showTotalStats();
				}
				opts.tick = 1;
				opts.yMax = max;
			}
			stackedColumnGraph(opts);
		},
		tooltip_callback : function() {
			RealtimeDashboard.locals.current_unresolved_point = this;
		    return false;
		},
		hover_callback : function(){
			var str = [];
			var selected = RealtimeDashboard.locals.current_unresolved_point;
		    if(selected != undefined && selected.points && selected.points.length > 0) {
		        var locale_key = 'dummy_key';
		        jQuery.each(selected.points,function(i,point) {
		            str.push({
		                value : point.y,
		                color : point.color,
		                name : point.series.name
		            });
		            if(point.series.userOptions != undefined) {
		            	locale_key = point.series.userOptions.locale_key;	
		            }
		        });
		        var renderData = {
		            title : selected.x
		        }
		        renderData.items = str;
		        RealtimeDashboard.CoreUtil.Utils.renderTemplate('.graph_details',
		                        'app/realtime_dashboard/template/stats_tmpl_1', renderData);
		    }
		},
		showTotalStats : function() {
			//Will be implemented in future iter.
			jQuery('.graph_details').empty();
		},
		showTimeStamp : function() {
			var self = this;
			var date = new Date(_fd.resp.time_since);
			var str = 'as of ' + moment(date).format(self.core.time_format);
			_fd.formated_time = str;
			jQuery('.' + _fd.widget_name + '_widget' +' [rel=timestamp]').html(str);
		},
		init : function() {
				var self = this;
				self.core = RealtimeDashboard.CoreUtil;
				self.locale_key = self.core.locale_prefix + _fd.widget_name;
				self.bindEvents();
				self.fetchData(false,'-');
		}
	};
	_fd.container = container;
	_fd.widget_name = widget_name;
	_fd.group_by = group_by;
	_fd.workload = workload;
	_fd.preview_limit = preview_limit;
	return _fd;
}