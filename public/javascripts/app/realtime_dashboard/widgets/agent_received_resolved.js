RealtimeDashboard.Widgets = RealtimeDashboard.Widgets || {};

RealtimeDashboard.Widgets.AgentReceivedResolved = function(widget_name,container,preview_limit){
	
	var _fd = {
		constants : {
			endPoint : '/helpdesk/dashboard/my_performance',
			stats_endPoint : '/helpdesk/dashboard/my_performance_summary'
		},
		fetchData : function() {
			var self = this;
			self.core.showLoader(self.container_class);
			
			if(true || self.core.refresh.did_time_expire() || !self.core.readFromLocalStorage(_fd.widget_name)) {
				var opts = {
		            url: self.constants.endPoint,
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
		fetchStats : function(values,container) {
			var self = this;
			
			if(true || self.core.refresh.did_time_expire() || !self.core.readFromLocalStorage(_fd.widget_name)) {
				jQuery( '#' + container).html('<div class="sloading loading-small loading-block"></div>');
				var opts = {
		            url: self.constants.stats_endPoint,
		            success: function (response) {
		                _fd.stats = response.result;
		            	self.core.addToLocalStorage(_fd.widget_name + '_stats',_fd.stats);
		                //self.parseResponse();
						self.constructChart(values,container,false,true);
						self.showTotalStats(true);
						jQuery(".trend-toggle-tab").removeClass('hide');
		            },
		            error : function(){
		            	self.core.appendNoData(_fd.container + '_widget');
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
				self.constructChart(_fd.resp,_fd.container,true,true);
			} else {
				self.core.appendNoData(_fd.container + '_widget');
			}
			
			jQuery('#filter_by_group_dropdown').removeClass('disabled sloading');
			self.core.hideLoader(self.container_class);
		},
		constructChart: function (data,container,isMainView,showWeekTrend) {
			var self = this;
			var limit = _fd.preview_limit;
			var original = jQuery.extend({},data);

			if(showWeekTrend) {
				original = original.week;
			} else {
				original = original.month;
			}
			var  categories = original.categories[0];
			var series = original.series;
			var chartData = original.values;
			//Get maxvalue in data
			var yMax = 0;
			jQuery.each(chartData,function(i,el) {
				 el['locale_key'] = self.locale_key;
				 /* Dummy data
				 el['data'] = el['data'].map(function (x) { 
				    return Math.floor((Math.random() * 100) + 1); 
				 });*/
				 var inline_max = Math.max.apply(Math,el['data']);
				 if(yMax == 0 || yMax < inline_max ) {
				 	yMax = inline_max;
				 }
			});
			
			/* Graph opts */
			var opts = {
				type : _fd.widget_name,
				chartData : chartData,
				xAxisLabel : categories,
				container : container
			}

			if(isMainView) {
				opts.height = 180;
				opts.chartClick = function(e) {
					self.sidebarModalChart(data,'graph_space');
				}
				opts.legend = true;
				opts.max = limit;
				opts.scrollbar = false;
				opts.label_enabled = true;
				opts.gridLineWidth = 1;
				opts.showYAxisLabels = true;
			} else {
				opts.height = 250;
				opts.enableHover = true;
				opts.tooltip_callback = self.tooltip_callback;
				opts.hover_callback = self.hover_callback;
				if(7 < categories.length){
					opts.max = 7;	
				}
				opts.scrollbar = true;
				opts.label_enabled = false;
				opts.legend = false;
				opts.crossHair = true;
				opts.showYAxis = false;
				opts.showYAxisLabels = false;
				opts.total_action = function() {
					self.showTotalStats(showWeekTrend);
				}
				opts.yMax = yMax;
			}
			//For month, suffix current month to x axis labels
			if(!showWeekTrend){
				opts.label_formatter = function(){
					 var date = new Date();
					 return this.value + ' ' + RealtimeDashboard.month_name[date.getMonth()+1];
				}
			} 
			multiSeriesColumn(opts);
		},
		tooltip_callback : function() {
			RealtimeDashboard.locals.my_performance = this;
		    return false;
		},
		hover_callback : function() {
			var str = [];
			var selected = RealtimeDashboard.locals.my_performance;

		    if(selected != undefined && selected.points && selected.points.length > 0) {
		        var locale_key = '';
		        jQuery.each(selected.points,function(i,point) {
		            str.push({
		                value : point.y,
		                color : point.color,
		                name : point.series.name == "received" ? I18n.t('helpdesk.realtime_dashboard.stats.received_tickets') : I18n.t('helpdesk.realtime_dashboard.stats.resolved_tickets')
		            });
		            locale_key = point.series.userOptions.locale_key;
		        });
		        var renderData = {}
		        //Take Fcr data from stats object
				var current_tab = jQuery(".trend-toggle-tab .active").attr('data-trend');
		        var fcr_stats = _fd.stats[current_tab][selected.x];
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
		        renderData.items = str.concat(fcr_tmpl);
		        
		        if(current_tab == 'week') {
		        	renderData.title = selected.x;
		        } else {
		        	var date = new Date();
		        	renderData.title = selected.x + " " + RealtimeDashboard.month_name[date.getMonth()+1];
		        }

		        RealtimeDashboard.CoreUtil.Utils.renderTemplate('.graph_details',
		                        'app/realtime_dashboard/template/stats_tmpl_2', renderData);
		    }
		},
		showTotalStats : function(isWeek) {
			var cdata = {};
			if(isWeek) {
				cdata = _fd.stats['total']['week'][0];
			} else{
				cdata = _fd.stats['total']['month'][0];
			}
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
					value : cdata['avg_resolution_time'] == null ? 0 : cdata['avg_resolution_time'] ,
					name : I18n.t('helpdesk.realtime_dashboard.stats.avg_resolution_time')
				}
			];
			
			var renderData = {
	            title : I18n.t('helpdesk.realtime_dashboard.total_value')
	        }
			renderData.items = str;
		    RealtimeDashboard.CoreUtil.Utils.renderTemplate('.graph_details',
		                        'app/realtime_dashboard/template/stats_tmpl_2', renderData);
		},
		sidebarModalChart: function (values,container) {
			var self = this;
			self.core.controls.showDashboardDetails(_fd.widget_name,I18n.t(self.locale_key),false,_fd.formated_time);
			self.fetchStats(values,container);
		},
		bindEvents : function() {
			var self = this;
			jQuery(document).on('click','[data-action=toggle-trend]',function(event){
				
				jQuery('[data-action=toggle-trend].active').removeClass('active');
				
				var target = jQuery( event.target );
				target.addClass('active');
				if(target.attr('data-trend') == 'week') {
					self.showTotalStats(true);
					self.constructChart(_fd.resp,'graph_space',false,true);	
				} else{
					self.showTotalStats(false);
					self.constructChart(_fd.resp,'graph_space',false,false);
				}
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
			self.fetchData();
			self.bindEvents();
		}	
	}
	_fd.container = container;
	_fd.widget_name = widget_name;
	_fd.preview_limit = preview_limit;
	return _fd;
}