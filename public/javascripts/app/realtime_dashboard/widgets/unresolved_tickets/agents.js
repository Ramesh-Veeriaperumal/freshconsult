RealtimeDashboard.Widgets = RealtimeDashboard.Widgets || {};
RealtimeDashboard.Widgets.UnresolvedTickets = RealtimeDashboard.Widgets.UnresolvedTickets || {};

RealtimeDashboard.Widgets.UnresolvedTickets.Agent = function(container,widget_name,group_by,widget_type,list_limit) {
	
	var _fd = {
		tickets_data : {},
		isGlobalView: false,
		isResponder: false,
		constants : {
			endPoint : '/helpdesk/dashboard/unresolved_tickets_dashboard'
		},
		color_codes : {
			'Low' : '#90C765',
			'High' : '#F9BE4B',
			'Medium' : '#36A2F2',
			'Urgent' : '#DD3034',
			'empty_bar_color' : '#EFEFEF'
		},
		fetchData : function() {
			var self = this;

			var opts = {
	            data: self.constructParams(),
	            url: self.constants.endPoint,
	            success: function (response) {
	                _fd.resp = response;
	                self.parseResponse();
	            }
	        };
	        self.core.makeAjaxRequest(opts);
		},
		parseResponse : function () {
			var self = this;

			if(_fd.widget_type == 1) {

				if(jQuery.isEmptyObject(_fd.resp[_fd.widget_name])) {
					self.core.appendNoData(_fd.container + '_widget');
					return ;
				}
				this.checkDataAndconstructChart(_fd.resp);
			} else if(_fd.widget_type == 2) {

				this.constructList(_fd.resp,'#old_tickets_container',true);	
			}
			
			jQuery('#filter_by_group_dropdown').removeClass('disabled sloading');
		},
		constructParams : function() {

			var data = {};
			data['group_by'] = _fd.group_by;
			data['widget_name'] = _fd.widget_name;

			this.requestData = data;
			return data;
		},
		constructList : function(resp,targetContainer,isMainView) {
			var self = this;
			if (resp[_fd.widget_name] && resp[_fd.widget_name].length > 0) {
				
				var data = resp[_fd.widget_name];
				spliced = data;
				if(isMainView && (data.length > _fd.list_limit)) {
					spliced = data.slice(0,_fd.list_limit);
				}

				if (resp[_fd.widget_name].length <= 4) {
					jQuery('[rel=view_all_old_tickets]').hide(); // hide the View All panel
				}

				self.core.Utils.renderTemplate(targetContainer,
					'app/realtime_dashboard/template/unresolved_tickets_age_tmpl', spliced);
			} else {
				jQuery('.' + _fd.widget_name + '_widget #old_tickets_container').html("<div class='no_data_to_display text-center muted mt20'><i class='ficon-no-data fsize-72'></i><div class='mt10'>No Data to Display </div></div>");
				jQuery('.' + _fd.widget_name + '_widget [rel=view_all_old_tickets]').hide();
			}
		},
		checkDataAndconstructChart: function (resp) {
			var self = this;
			var chartname = _fd.widget_name;

			if(resp[chartname].length > 4) {
				jQuery('.' + chartname + '_widget .widget-more-link').show();
			}

			//this.constructChart('Bar', chartname ,'#' + chartname, resp[chartname], 4);
			this.constructChart1(resp[chartname],_fd.container,true);
		},
		constructChart1 : function(data,container,isMainView) {
			var self = this;
			var val = [],categories = [],dataLabels = [],custom_ids=[];

			 chartData = [
				{ 	name : 'dummy',
					borderRadius: 5,
	                states: { hover: { brightness: 0 } },
	                animation : false,
	                color : '#ebebeb',
	                cursor : 'pointer',
	                dataLabels: { enabled: false },
	                point: {
	                    events: {
	                        click: function (e) {
                                var ev = this;
                                self.clickForUnresolvedGraphs(ev,e.point);
	                        }
	                    }
	                }
				},
				{ 	name : 'Unresolved',
					borderRadius: 5,
	                animation: {
	                    duration: 1000,
	                    easing: 'easeInOutQuart'
	                },
	                cursor : 'pointer',
	                point: {
	                    events: {
	                        click: function (e) {
                                var ev = this;
                                self.clickForUnresolvedGraphs(ev,e.point);
	                        }
	                    }
	                }
				}
			];

			var temp = [];
			if(isMainView) {
				temp = data.slice(0,_fd.list_limit);
			} else {
				temp = data.slice(0,data.length);
			}

			jQuery.each(temp,function(i,el) {
				//For Dummy data
				//var rand = Math.floor((Math.random() * 10) + 1);
				//dataLabels.push(rand);
				//var obj = { y : rand, custom_id : 10};
				
				var obj = { y : el['value'], custom_id : el['id']};
				custom_ids.push(el['id']);
				if(self.color_codes[el['name']] != 'undefined'){
					obj.color = self.color_codes[el['name']];
				}
				val.push(obj);
				dataLabels.push(el['value']);
				categories.push(el['name']);
			});

			chartData[1]['data'] = val;
			chartData[0]['data'] = self.fillArray(_.max(dataLabels),val.length,custom_ids);

			//dataLabels = chartData[1]['data'];
			
			var opts = {
				xAxisLabel : categories,
				renderTo : container,
				chartData : chartData,
				dataLabels : dataLabels,
			};

			if(isMainView) {
				opts.height = self.calculateChartheight(_fd.list_limit);
			} else {
				opts.height = self.calculateChartheight(categories.length);
			}
			barChart(opts);
		},
		clickForUnresolvedGraphs : function(el,point) {

			var chartname = {
				"unresolved_tickets_by_priority"	: "priority",
				"unresolved_tickets_by_ticket_type"	: "type",
				"unresolved_tickets_by_status"		: "status",
			}

			var queryString = chartname[_fd.widget_name] +"="+ point.options.custom_id;
			queryString += '&agent=0' ;//+ DataStore.get('current_user').currentData.user.id;

			//on implementing method to pass additional attributes to pjaxify ,use the below and remove the anchor.
			//pjaxify("/helpdesk/tickets?"+ queryString);
			jQuery("[rel=tickets-anchor]").attr('href',"/helpdesk/tickets?"+ queryString).click();
		},
		sidebarModalChart: function (key,data) {
			var self = this;
			if(_fd.widget_type == 2) {
				self.core.controls.showDashboardDetails(_fd.widget_name,I18n.t('helpdesk.realtime_dashboard.unresolved_tickets_by_age'),false);
			} else{
				self.core.controls.showDashboardDetails(_fd.widget_name,I18n.t('helpdesk.realtime_dashboard.' + key ),false);
				this.constructChart1(data,'graph_space',false);
			}
		},
		bindEvents : function() {
			var self = this;
			
			if(_fd.widget_name == 'unresolved_tickets_by_ticket_type') {
				jQuery(document).on('click', '[rel=view_all_unresolved_ticket_type]', function (e) {
					self.sidebarModalChart('unresolved_tickets_by_ticket_type',_fd.resp['unresolved_tickets_by_ticket_type']);
				});
			}

			if(_fd.widget_name == 'unresolved_tickets_by_status') {
				jQuery(document).on('click', '[rel=view_all_unresolved_by_status]', function (e) {
					self.sidebarModalChart('unresolved_tickets_by_status',_fd.resp['unresolved_tickets_by_status']);
				});
			}
			
			if(_fd.widget_name == 'unresolved_tickets_by_age') {
				jQuery(document).on('click.realtimeDashboard', '[rel=view_all_old_tickets]', function (e) {
						self.constructList(_fd.resp,'.list_items',false);
						self.sidebarModalChart();
						jQuery("#graph_space").hide();
						jQuery(".list_items").show();
				});	
			}
			//Auto refresh event
			jQuery(document).on('group_change',function(ev,data){
				self.fetchData();
			});
		},
		fillArray: function(value, length,custom_ids) {
            var self = this;
            var arr = [];
            if(value == 0) {
            	value = 1; //some dummy value to show empty bar
            }
            for (var i = 0; i < length; i++) {
                arr.push({
                	y : value,
                	custom_id : custom_ids[i],
                	color : self.color_codes['empty_bar_color']
                });
            }
            return arr;
        },
        calculateChartheight: function (dataPoints) {
            var height = 53 * dataPoints;
            return height;
        },
        calculateChartWidth : function(){
        	var col_2 = jQuery("[data-gs-width=2]");
        	return col_2.width() - 35;
        },
		init : function() {
				var self = this;
				self.core = RealtimeDashboard.CoreUtil;
				self.isGlobalView = jQuery('#realtime-dashboard-content').data('widgetType');
				self.bindEvents();
				self.fetchData();
		}
	};
	_fd.container = container;
	_fd.widget_name = widget_name;
	_fd.group_by = group_by;
	_fd.widget_type = widget_type;
	_fd.list_limit = list_limit;
	return _fd;
}