RealtimeDashboard.Widgets = RealtimeDashboard.Widgets || {};
RealtimeDashboard.Widgets.OpenTickets = RealtimeDashboard.Widgets.OpenTickets || {};

RealtimeDashboard.Widgets.OpenTickets.Customers = function(container,widget_name,list_limit){
	var _fd = {
			constants : {
				endPoint : '/helpdesk/dashboard/top_customers_open_tickets'
			},
			container_class : '.overdue_widget',
			fetchData : function() {
				var self = this;

				var opts = {
		            url: self.constants.endPoint,
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
				if(_fd.resp.customers && _fd.resp.customers.length > 0){
					self.constructList('.open_tickets_by_customer_list',true);
				} else {
					jQuery('.open_tickets_by_customer_list').html("<div class='no_data_to_display text-center muted mt20'><i class='ficon-no-data fsize-72'></i><div class='mt10'>No Data to Display </div></div>");
					jQuery('[rel=view_all_open_tickets_by_customer]').hide();
				}
			},
			constructList : function(targetContainer,isMainView) {
				var self = this;
					
				var data = _fd.resp.customers;
				spliced = data;
				if(isMainView && (data.length > _fd.list_limit)) {
					spliced = data.slice(0,_fd.list_limit);
				}

				if (data.length < 4) {
					jQuery('[rel=view_all_open_tickets_by_customer]').hide(); // hide the View All panel
				}

				self.core.Utils.renderTemplate(targetContainer,
					'app/realtime_dashboard/template/top_customers_by_open_tickets', spliced);
				
			},
			bindEvents : function() {	
				var self = this;
				jQuery(document).on('click.realtimeDashboard', '[rel=view_all_open_tickets_by_customer]', function (e) {
					self.constructList('.list_items',false);
					self.core.controls.showDashboardDetails(_fd.widget_name,I18n.t('helpdesk.realtime_dashboard.top_customers_by_open_tickets'),false,_fd.formated_time);
					jQuery(".list_items").show();
					jQuery('#graph_space').hide();
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
				self.fetchData();
				self.bindEvents();
			}
	};
	_fd.container = container;
	_fd.widget_name = widget_name;
	_fd.list_limit = list_limit;
	return _fd;
}