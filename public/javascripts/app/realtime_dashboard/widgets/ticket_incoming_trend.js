RealtimeDashboard.Widgets = RealtimeDashboard.Widgets || {};

RealtimeDashboard.Widgets.TicketIncomingTrend = function(widget_name,container){
	var _fd = {
		constants : {
			endPoint : '/helpdesk/dashboard/admin_glance',
			channel_workload : '/helpdesk/dashboard/channels_workload'
		},
		color_codes : ['#7DAE4C','#D18470','#717171','#D4BBA7','#C3A7CC','#70BA6A','#62D3DC','#648DB0',"#D4D4D4", "#D4F1FE", "#97DCFD","#1486C4"],
		fetchData : function() {
			var self = this;
			
			var opts = {
	            url: self.constants.endPoint,
	            success: function (response) {
	            	_fd.resp = response;
	                self.parseResponse();
	                self.showTimeStamp();
	            },
	            error : function(){
	            	self.core.appendNoData(_fd.container + '_widget');
	            }
	        };
	        self.core.makeAjaxRequest(opts);
		},
		fetchStats : function(container) {
			var self = this;
			
			if(true || self.core.refresh.did_time_expire() || !self.core.readFromLocalStorage(_fd.widget_name)) {
				jQuery("#" + container).html('<div class="sloading loading-small loading-block"></div>');
				var opts = {
		            url: self.constants.channel_workload,
		            success: function (response) {
		                _fd.stats = response.result;
		            	self.core.addToLocalStorage(_fd.widget_name + '_stats',_fd.stats);
						self.constructChannelChart(container);
						self.showTotalStats();
		            }
		        };
		        self.core.makeAjaxRequest(opts);
			} else{
				_fd.stats = JSON.parse(self.core.readFromLocalStorage(_fd.widget_name + '_stats'));
				self.constructChannelChart('graph_space');
				self.showTotalStats();
			}
		},
		parseResponse : function() {
			
			var self = this;
			if(!jQuery.isEmptyObject(_fd.resp) && _fd.resp['result']['errors'] == undefined ) {
				self.constructChart(_fd.resp,_fd.container);
			} else {
				self.core.appendNoData(_fd.container + '_widget');
			}
			
			jQuery('#filter_by_group_dropdown').removeClass('disabled sloading');
		},
		constructChart: function (data,container) {
			
			var self = this;
			var original = jQuery.extend({},data);
			var categories = _.keys(data.result);
			var chartData = {
				received : [],
				resolved : []
			};

			jQuery.each(categories,function(i,el) {
				 //Dummy data
				 //data.result[el]['received_count'] = Math.floor((Math.random() * 100) + 1);
				 //data.result[el]['resolved_count'] = Math.floor((Math.random() * 100) + 1);
				 if(el != 'last_dump_time') {
				 	chartData['received'].push((data.result[el]['received_count']));
				 	chartData['resolved'].push((data.result[el]['resolved_count']));
				 }
			});
			
			var series = [{
				name : 'Received',
				data : chartData['received']
			}];
			/* Graph opts */
			var opts = {
				type : _fd.widget_name,
				series : series,
				xAxisLabel : categories,
				container : container,
				legend : false,
				colors : _fd.color_codes,
				height : 220,
				chartClick : function(e) {
					self.sidebarModalChart(original,'graph_space');
				},
				formatter : function() {
					return this.value + ":00";
				},
				tooltip_callback : function(){
					return false;
				},
				crosshairs : [false,false],
				series_hover : false
			}
			lineChart(opts);
		},
		constructChannelChart : function(container) {

			var self = this;
			var original = jQuery.extend({},_fd.stats);
			var categories = _.keys(_fd.resp.result);
			var max = 0;
			var channels = [];

			jQuery.each(_.keys(original.source_id_name_mappings),function(i,key){
				var series = {};
				series.name = original.source_id_name_mappings[key];
				series.data = [];
				jQuery.each(categories,function(j,label){
					if(label == 'last_dump_time'){
						return ;
					}
					var val = original.source_workload[key][label]['received_count'];
					series.data.push(val);
					if(max == 0 || max < val){
						max = val;
					}
					//series.data.push(Math.floor((Math.random() * 100) + 1));
				});
				series.lineColor = self.color_codes[i];
				channels.push(series);
			});
			/* Graph opts */
			var opts = {
				type : _fd.widget_name,
				series : channels,
				xAxisLabel : categories,
				container : container,
				legend : false,
				colors : _fd.color_codes,
				hover_callback : self.hover_callback,
				formatter : function() {
					return this.value + ":00";
				},
				crosshairs : [true,false],
				total_action:  function() {
					self.showTotalStats();
				},
				yMax : max,
				series_hover : true
			}
			
			opts.height = 280;
			opts.enableHover = true;
			opts.tooltip_callback = self.tooltip_callback;
			lineChart(opts);
		},
		tooltip_callback : function() {
			RealtimeDashboard.locals.current_trend_point = this;
		    /* Time in tooltip
		    var mkup = '';
		    if(this.x < 12) {
		    	mkup = '<div>' + this.x + ' AM</div>'
		    } else {
		    	mkup = '<div>' + (parseInt(this.x) - 12) + ' PM</div>'
		    }
		    */
		    return false;
		},
		hover_callback : function() {
			var str = [];
			var selected = RealtimeDashboard.locals.current_trend_point;

			if(selected != undefined && selected.points && selected.points.length > 0) {
		        var lineColor = '#333';
		        jQuery.each(selected.points,function(i,point) {
		            str.push({
		                value : point.y,
		                color : point.color,
		                name : point.series.name
		            });
		            if(point.series.userOptions != undefined){
		            	lineColor = point.series.userOptions.lineColor;
		            }
		        });
		        var renderData = {
		            title : ''
		        }
		        var time = selected.x;
		        if(time < 12) {
			    	renderData.title = (time != 0 ? time : 12 ) + ' AM';
			    } else {
			    	renderData.title = (time != 12 ? (parseInt(time) - 12) : 12 )+ ' PM';
			    }
		        renderData.items = str;
		        renderData.class = 'thinSymbol';
		        jQuery('.graph_details').addClass('incoming-trend');
		        RealtimeDashboard.CoreUtil.Utils.renderTemplate('.graph_details',
		                        'app/realtime_dashboard/template/stats_tmpl_table', renderData);
		    }
		},
		sidebarModalChart: function (values,container) {
			var self = this;
			self.core.controls.showDashboardDetails(_fd.widget_name,I18n.t('helpdesk.realtime_dashboard.ticket_workload_channels'),false,_fd.formated_time);
			self.fetchStats(container);
		},
		showTotalStats : function() {
			var str = [];
			var original = jQuery.extend({},_fd.stats);
			var categories = _.keys(_fd.resp.result);
			var self = this;

			jQuery.each(_.keys(original.source_id_name_mappings),function(i,key){

				var row = {};
				row.name = original.source_id_name_mappings[key];
				row.value = 0;
				jQuery.each(categories,function(j,hour){
					if(hour == 'last_dump_time') {
						return;
					}
					row.value += original.source_workload[key][hour]['received_count'];
				});
				row.color = self.color_codes[i];
				str.push(row);
			});
			
			var renderData = {
	            title : I18n.t('helpdesk.realtime_dashboard.stats.total_workoad')
	        }
			renderData.items = str;
			renderData.class = 'thinSymbol';
			jQuery('.graph_details').addClass('incoming-trend');
		    RealtimeDashboard.CoreUtil.Utils.renderTemplate('.graph_details',
		                        'app/realtime_dashboard/template/stats_tmpl_table', renderData);
		},
		showTimeStamp : function() {
			var self = this;
			var date = new Date(_fd.resp.result.last_dump_time);
			var str = 'as of ' + moment(date).format(self.core.time_format);
			_fd.formated_time = str;
			jQuery('.' + _fd.widget_name + '_widget' +' [rel=timestamp]').html(str);
		},
		bindEvents : function() {

		},
		init : function() {
			var self = this;
			self.core = RealtimeDashboard.CoreUtil;
			self.locale_key = self.core.locale_prefix ;//+ _fd.widget_name;
			self.fetchData();
			self.bindEvents();
		}
	}
	_fd.widget_name = widget_name;
	_fd.container = container;
	return _fd;
}