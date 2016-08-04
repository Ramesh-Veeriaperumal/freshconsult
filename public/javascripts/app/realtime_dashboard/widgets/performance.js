RealtimeDashboard.Widgets = RealtimeDashboard.Widgets || {};

RealtimeDashboard.Widgets.Performance = function(widget_name,container,preview_limit){
	
	var _fd = {
		constants : {
			endPoint_agent : '/helpdesk/dashboard/agent_performance',
			endPoint_group : '/helpdesk/dashboard/group_performance',
			stats_endPoint_agent : '/helpdesk/dashboard/agent_performance_summary',
			stats_endPoint_group : '/helpdesk/dashboard/group_performance_summary'
		},
		fetchData : function(forceRefresh,group_id) {
			var self = this;
			var data = {};
			if(!self.core.isAllSelected(group_id)) {
				data['group_id'] = group_id;
			}	

			if(true || self.core.refresh.did_time_expire() || !self.core.readFromLocalStorage(_fd.widget_name)) {
				var opts = {
		            url: _fd.widget_name == "agent_performance" ? self.constants.endPoint_agent : self.constants.endPoint_group,
		            data : data,
		            success: function (response) {
		                _fd.resp = response.result;
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
		fetchStats : function(container) {
			var self = this;
			
			if(true || self.core.refresh.did_time_expire() || !self.core.readFromLocalStorage(_fd.widget_name)) {

				jQuery( '#' + container).html('<div class="sloading loading-small loading-block"></div>');
				var opts = {
		            url: _fd.widget_name == "agent_performance" ? self.constants.stats_endPoint_agent : self.constants.stats_endPoint_group ,
		            success: function (response) {
		                _fd.stats = response.result;
		            	self.core.addToLocalStorage(_fd.widget_name + '_stats',_fd.stats);
						self.constructChart(container,false);
						self.showTotalStats();
		            }
		        };
		        self.core.makeAjaxRequest(opts);
			} else{
				_fd.stats = JSON.parse(self.core.readFromLocalStorage(_fd.widget_name + '_stats'));
				self.parseResponse();
			}
		},
		parseResponse : function() {
			var self = this;
			if(!jQuery.isEmptyObject(_fd.resp) && _fd.resp['errors'] == undefined) {
			
				_fd.resp.chartData = _fd.resp.values;
				var yMax = 0; 
				jQuery.each(_fd.resp.chartData,function(i,el) {
					 el['locale_key'] = self.locale_key;
					 var inline_max = Math.max.apply(Math,el['data']);
					 if(yMax == 0 || yMax < inline_max ) {
					 	yMax = inline_max;
					 }
					 var arr = [];
					 jQuery.each(el['data'],function (i,x) { 
					    arr.push( { 'y' : x , 'subject_id' : _fd.resp.ids[i]} ); 
					 });
					 el['data'] = arr;
				});
				_fd.yMax = yMax;
				self.constructChart(_fd.container,true);
			} else {
				self.core.appendNoData(_fd.container + '_widget');
			}
			
			jQuery('#filter_by_group_dropdown').removeClass('disabled sloading');
			self.core.hideLoader(self.container_class);
		},
		constructChart: function (container,isMainView) {
			var self = this;

			var limit = _fd.preview_limit;
			var original = jQuery.extend({},_fd.resp);

			var categories = _fd.resp.categories;
			var series = _fd.resp.series;
			
			/* Graph opts */
			var opts = {
				type : _fd.widget_name,
				chartData : _fd.resp.chartData,
				xAxisLabel : categories,
				container : container
			}
			if(isMainView) {
				opts.height = 220;
				opts.chartClick = function(e) {
					self.sidebarModalChart('graph_space');
				}
				opts.legend = true;
				if(limit < categories.length-1){
					opts.max = limit;	
				}
				opts.scrollbar = false;
				opts.label_enabled = true;
				opts.gridLineWidth = 1;
				opts.chartCursor = true;
				opts.showYAxisLabels = true;
			} else {
				opts.height = 250;
				opts.enableHover = true;
				opts.tooltip_callback = self.tooltip_callback;
				opts.hover_callback = self.hover_callback;
				if(6 < categories.length){
					opts.max = 6;	
				}
				opts.scrollbar = true;
				opts.label_enabled = true;
				opts.showYAxis = false;
				opts.showYAxisLabels = false;
				opts.legend = false;
				opts.crossHair = true;
				opts.total_action = function() {
					self.showTotalStats();
				}
				opts.tick = 1;
				opts.yMax = _fd.yMax;
			}
			
			opts.label_formatter = function () {
                //return this.value.length > 10 ? this.value.substr(0,10) + '...' : this.value;
           		return this.value;
            }
            
			multiSeriesColumn(opts);
		},
		/* Received & resolved count from graph,
		* Other three metrics from stats object obtained through fetchStats
		*/
		tooltip_callback : function() {
			RealtimeDashboard.locals.current = this;
		    return false;
		},
		hover_callback : function() {
			var str = [];
			var selected = RealtimeDashboard.locals.current;

			if(selected != undefined && selected.points && selected.points.length > 0) {
		        var locale_key = '',subject_id = '';

		        jQuery.each(selected.points,function(i,point) {
		            str.push({
		                value : point.y,
		                color : point.color,
		                name : point.series.name == "received" ? I18n.t('helpdesk.realtime_dashboard.stats.received_tickets') : I18n.t('helpdesk.realtime_dashboard.stats.resolved_tickets')
		            });
		            if(point){
		            	if(point.series.userOptions != undefined){
		            		locale_key = point.series.userOptions.locale_key;
		            	}
		            	if(point.point != undefined){
		            		subject_id = point.point.subject_id;
		            	}
		            }
		        });
	        	//Take Fcr data from stats object
		         var fcr_stats = _fd.stats[subject_id];
		         if(fcr_stats != undefined) {
		         		var fcr_tmpl = [
					        {
								value : fcr_stats['fcr_tickets'] == null ? 0 : fcr_stats['fcr_tickets'],
								name : I18n.t('helpdesk.realtime_dashboard.stats.first_contact_resolution')
							},
							{
								value : fcr_stats['resolution_sla'] == null ? 0 : fcr_stats['resolution_sla'],
								name : I18n.t('helpdesk.realtime_dashboard.stats.resolution_within_sla')
							},
							{
								value : fcr_stats['avg_resolution_time']  == null ? 0 : fcr_stats['avg_resolution_time'],
								name : I18n.t('helpdesk.realtime_dashboard.stats.avg_resolution_time')
							}
						];
						
				        var renderData = {
				            title : selected.x
				        }
				        renderData.items = str.concat(fcr_tmpl);

				        RealtimeDashboard.CoreUtil.Utils.renderTemplate('.graph_details',
			                        'app/realtime_dashboard/template/stats_tmpl_2', renderData);
		         }
		    }
		},
		showTotalStats : function() {
			if(_fd.stats != undefined) {
					var cdata = _fd.stats.total[0];
					var str = [
						{
							value : cdata['received_tickets'],
							name : I18n.t('helpdesk.realtime_dashboard.stats.received_tickets'),
							color : '#2CA0DB',
						},
						{
							value : cdata['resolved_tickets'],
							name : I18n.t('helpdesk.realtime_dashboard.stats.resolved_tickets'),
							color : '#99CD60',
						},
						{
							value : cdata['fcr_tickets'] == null ? 0 : cdata['fcr_tickets'],
							name : I18n.t('helpdesk.realtime_dashboard.stats.first_contact_resolution')
						},
						{
							value : cdata['resolution_sla'] == null ? 0 : cdata['resolution_sla'],
							name : I18n.t('helpdesk.realtime_dashboard.stats.resolution_within_sla')
						},
						{
							value : cdata['avg_resolution_time'] == null ? 0 : cdata['avg_resolution_time'],
							name : I18n.t('helpdesk.realtime_dashboard.stats.avg_resolution_time')
						}
					];
					
					var renderData = {};
			        if(_fd.widget_name == "agent_performance") {
			        	renderData.title = I18n.t('helpdesk.realtime_dashboard.stats.total_agent_performance');
			        } else {
			        	renderData.title = I18n.t('helpdesk.realtime_dashboard.stats.total_group_performance');
			        }
					renderData.items = str;
				    RealtimeDashboard.CoreUtil.Utils.renderTemplate('.graph_details',
				                        'app/realtime_dashboard/template/stats_tmpl_2', renderData);
			}
		},
		checkIsSidebarViewing: function () {
			if(jQuery('.slider-modal').is(":visible")) {
				var chartName = jQuery('.unresolved_tickets').data('chartName');
				this.sidebarModalChart(chartName);
			}
		},
		sidebarModalChart: function (container) {
			var self = this;
			self.core.controls.showDashboardDetails(_fd.widget_name,I18n.t(self.locale_key),false,_fd.formated_time);
			self.fetchStats(container);
		},
		bindEvents : function() {
			var self = this;
			
			jQuery(document).on("next_page",function(ev,data){
				//console.log(_fd.widget_name,data.chart_name);
			});

			jQuery(document).on('group_change',function(ev,data){
				self.fetchData(true,data.group_id);
			});
		},
		showTimeStamp : function() {
			var self = this;
			var date = new Date(_fd.resp.last_dump_time);
			var str = 'as of ' + moment(date).format(self.core.time_format);
			_fd.formated_time = str;
			jQuery('.' + _fd.widget_name + '_widget' +' [rel=timestamp]').html(str);
		},
		init : function() {
			var self = this;
			self.core = RealtimeDashboard.CoreUtil;
			self.locale_key = self.core.locale_prefix + _fd.widget_name;
			self.fetchData(false,'-');
			self.bindEvents();
		}	
	}
	_fd.container = container;
	_fd.widget_name = widget_name;
	_fd.preview_limit = preview_limit;
	return _fd;
}