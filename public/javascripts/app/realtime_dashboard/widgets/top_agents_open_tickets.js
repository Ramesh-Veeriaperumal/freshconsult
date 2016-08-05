RealtimeDashboard.Widgets = RealtimeDashboard.Widgets || {};
RealtimeDashboard.Widgets.OpenTickets = RealtimeDashboard.Widgets.OpenTickets || {};

RealtimeDashboard.Widgets.OpenTickets.Agent = function(container,widget_name,list_limit){
	var _fd = {
			constants : {
				endPoint : '/helpdesk/dashboard/top_agents_old_tickets '
			},
			fetchData : function(group_id) {
				var self = this;
				var data = {};
				if(!self.core.isAllSelected(group_id)) {
					data['group_id'] = group_id;
				}
				var opts = {
		            url: self.constants.endPoint,
		            data : data,
		            success: function (response) {
						_fd.resp = response.result;
		                self.parseResponse();
		                self.showTimeStamp();
		            }
		        };
		        self.core.makeAjaxRequest(opts);
			},
			parseResponse : function() {
				var self = this;
				if(_fd.resp.agents && _fd.resp.agents.length > 0){
					self.constructList('.' + _fd.container,true);
				} else {
					jQuery('.open_tickets_by_agent').html("<div class='no_data_to_display text-center muted mt20'><i class='ficon-no-data fsize-72'></i><div class='mt10'>No Data to Display </div></div>");
					jQuery('[rel=view_all_open_tickets_by_customer]').hide();
				}
			},
			constructList : function(targetContainer,isMainView) {
				var self = this;
					
				var data = _fd.resp.agents;
				spliced = data;
				if(isMainView && (data.length > _fd.list_limit)) {
					spliced = data.slice(0,_fd.list_limit);
				}

				if (data.length < 4) {
					jQuery('[rel=view_all_open_tickets_by_customer]').hide(); // hide the View All panel
				}

				self.core.Utils.renderTemplate(targetContainer,
					'app/realtime_dashboard/template/top_agents_by_open_tickets', spliced);
				
			},
			bindEvents : function() {	
				var self = this;
				jQuery(document).on('click.realtimeDashboard', '[rel=view_all_open_tickets_by_customer]', function (e) {
					self.constructList('.list_items',false);
					self.core.controls.showDashboardDetails(_fd.widget_name,I18n.t('helpdesk.realtime_dashboard.top_agents_by_open_tickets'),false,_fd.formated_time);
					jQuery("#graph_space").hide();
					jQuery(".list_items").show();
				});

				jQuery(document).on('group_change',function(ev,data){
					self.fetchData(data.group_id);
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
				self.fetchData('-');
				self.bindEvents();
			}
	};
	_fd.container = container;
	_fd.widget_name = widget_name;
	_fd.list_limit = list_limit;
	return _fd;
}