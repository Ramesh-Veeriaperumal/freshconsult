HelpdeskReports.ReportUtil = HelpdeskReports.ReportUtil || {};

HelpdeskReports.ReportUtil.TimeSpent = (function($){
	var _FD = {
		bindEvents: function () {
				var $doc = $(document);
				var $wrapper = $('#reports_wrapper');

	            $wrapper.on('click.helpdesk_reports', "[data-action='reports-submit']", function () {
	                _FD.submitReports();
	            });
	            
	            $('#reports_wrapper').on('click.helpdesk_reports.timespent', "[data-container='view-more']", function (event) {
	                HelpdeskReports.CoreUtil.actions.hideTicketList();
	                HelpdeskReports.CoreUtil.actions.closeFilterMenu();
	                _FD.renderViewMore(this);
	            });
	            
	            $doc.on('click.helpdesk_reports.timespent', "[data-action='close-view-more-pane']", function (event) {
	                _FD.closeViewMorePane();
	            });

	            $doc.on('click.helpdesk_reports.timespent', "[data-action='navback-drill-down-pane']", function (event) {
	               //Clear the ticket list view
	               $("#time_spent_ticket_list").html("");
	               $('[data-action="navback-drill-down-pane"]').addClass('hide');
	               _FD.showDrillDownPane(_FD.breadcrum_data);
	            });

				$doc.on('click.helpdesk_reports.timespent', "[data-action='navback-drill-down-pane-title']", function (event) {
	               //Clear the ticket list view
	               if(!$("[data-action=navback-drill-down-pane]").hasClass('hide')) {
						$("#time_spent_ticket_list").html("");
						$('[data-action="navback-drill-down-pane"]').addClass('hide');
	              		 _FD.showDrillDownPane(_FD.breadcrum_data);
				   }
	            });

	            $doc.on('click.helpdesk_reports.timespent', "[data-action='close-drill-down-pane']", function (event) {
	                _FD.closeDrillDownPane();
	            });

	            $doc.keyup(function(e) {
		             if (e.keyCode == 27) { 
		                // escape key maps to keycode `27`
		                _FD.closeViewMorePane();
		                _FD.closeDrillDownPane();
		            }
		        }); 

	            $doc.on('click.helpdesk_reports', '[data-table="ticket-data"] tr[data-action="ticket-list"]', function () {
	                var flag = true;//HelpdeskReports.locals.ticket_list_flag;
	                if (flag) {
	                	
	                	$("#table_content").html("");
	                	$('[data-action="navback-drill-down-pane"]').removeClass('hide');
						var el = this;
	                    HelpdeskReports.locals.ticket_list_flag = true;
	                    $pane = $("#drill_down_pane");
			        	$pane.find(".view_title").html($(el).attr('data-title'));
			        	$pane.find("[data-action=navback-drill-down-pane]").removeClass('hide');
	                    _FD.constructTicketListParams(el);
	                }
	            });

	            $doc.on("bar_chart_point_click",function(e,data){
					jQuery("#time_spent_ticket_list").html('');
					jQuery(".back-nav").addClass('hide');
	            	_FD.showDrillDownPane(data);
	            });

	            $doc.on("change","[name=group_by]",function(){
	            	HelpdeskReports.locals.current_group_by = $("[name=group_by]").val();
					HelpdeskReports.locals.params[0]['group_by'] = [HelpdeskReports.locals.current_group_by];
	            	_FD.closeViewMorePane();
	            	_FD.closeDrillDownPane();
	            	setTimeout(function(){
	            		_FD.submitReports();
	            	},300);
	            });
		},
		closeViewMorePane : function() {
			$("#view_more_pane").removeClass('show');
		},
		showViewMorePane : function(){
			$("#view_more_pane").addClass('show')
		},
		closeDrillDownPane : function() {
			$("#table_content").html("");
			$("#time_spent_ticket_list").html("");
			$("#drill_down_pane").removeClass('show');
		},
		showDrillDownPane : function(e){
			$pane = $("#drill_down_pane");
			$pane.addClass('show');
			$pane.find(".view_title").html(e.point.name + " ( " + e.point.category + " )");
			_FD.breadcrum_data = e;
			this.constructTable(e);
		},
		constructTable : function(e){

			var locals = HelpdeskReports.locals;

			var date = locals.date_range;
			var merge_hash = {
				model  : 'TICKET_LIFECYCLE',
				metric : 'LIFECYCLE_STATUS',
				filter : [],
				date_range: date,
				group_by: [],
				reference : false,
				time_trend : false
			}

			var param = jQuery.extend({}, _FD.constants.params, merge_hash);
			param.filter.push({
				condition : locals.current_group_by =='group_id' ? 'agent_id' : 'group_id',
				operator : 'is_in',
				value : e.point.id,
				drill_down_filter : true
			});

			param.filter.push({
				condition : locals.current_group_by,
				operator : 'is_in',
				value : e.point.condition_id,
				drill_down_filter : true
			});
			param.filter = param.filter.concat(locals.query_hash);
			param.group_by.push(locals.current_group_by);
			
			var request = [];
			request.push(param);
			
			$("#table_content").show().html("");
			$("#table_content").addClass('sloading loading-small');

			var opts = {
				url: _FD.core.CONST.base_url + locals.report_type + _FD.core.CONST.fetch_active_metric,
				type: 'POST',
				dataType: 'json',
				contentType: 'application/json',
				data: Browser.stringify(request),
				timeout: _FD.core.timeouts.main_request,
				success: function (data) {
					/*
					data = {
						"status_category" :{
							"category_sort_by_total":[
								null,
								"Pending"
							],
							"category_sort_by_avg":[
								null,
								"Pending"
							],
							"Open":{
								"id":"1",
								"tkt_count":"2",
								"total_time":"2747",
								"no_of_times":"2",
								"avg_time":1373.5,
								"percent_time":79.12
							},
							"Pending":{
								"id":"3",
								"tkt_count":"1",
								"total_time":"725",
								"no_of_times":"2",
								"avg_time":725,
								"percent_time":20.88
							}
						}
					}
					*/
					if(!$.isEmptyObject(data)){
						var status = data['status_category'];
						var template_data = {
							stats : status,
							point : e.point,
							keys : _.keys(status).filter(function(val){
								if(val.indexOf("category_sort_by") > -1){
									return false;
								} else {
									return true;
								}
							})
						}
						var tmpl = JST["helpdesk_reports/templates/time_spent_drill_down_tmpl"](template_data);
						
						$("#table_content").removeClass('sloading loading-small');
						$("#table_content").html(tmpl);
					} else {
						var div = ["table_content"];
						HelpdeskReports.CoreUtil.populateEmptyChart(div, 'No Data');
					}
					
				},
				error: function (data) {
					var div = ["table_content"];
					HelpdeskReports.CoreUtil.populateEmptyChart(div, 'No Data');
					jQuery("#table_content").removeClass('sloading loading-small');
				}
			}
			_FD.core.makeAjaxRequest(opts);
		},
		constructTicketListParams: function (el) {
			var level1 = jQuery(el).data('level1');
			var level2 = jQuery(el).data('level2');
			var level3 = jQuery(el).data('level3');

			HelpdeskReports.locals.list_params = [];
			var list_params = HelpdeskReports.locals.list_params;

			var list_hash = {
				model: 'TICKET_LIFECYCLE',
				metric: 'LIFECYCLE_TICKET_LIST',
				date_range: HelpdeskReports.locals.date_range,
				filter: HelpdeskReports.locals.query_hash,
				list: true,
				group_by:[],
				list_conditions: [],
				reference : false,
				time_trend : false
			}

			var list_params = jQuery.extend({}, _FD.constants.params, list_hash);
			list_params.list_conditions.push({
				condition : HelpdeskReports.locals.current_group_by =='group_id' ? 'agent_id' : 'group_id',
				operator : 'is_in',
				value : String(level2),
			});

			list_params.list_conditions.push({
				condition : HelpdeskReports.locals.current_group_by,
				operator : 'is_in',
				value : String(level1)
			});

			list_params.group_by.push(HelpdeskReports.locals.current_group_by);
			list_hash.list_conditions.push({
				condition: 'status',
				operator: 'is_in',
				value: String(level3)
			});

			var req_arr = [];
			req_arr.push(list_params);

			$("#time_spent_ticket_list").addClass('sloading loading-small');
			$("#table_content").hide();
			_FD.core.fetchTickets(req_arr);
		},
		submitReports: function () {
			var flag = _FD.core.refreshReports();
			
			if(flag) {
				_FD.flushEvents();
				_FD.core.resetAndGenerate();
			}
		},
		setDefaultValues: function () {
			var current_params = [];
			var date = _FD.core.setReportFilters();
			var merge_hash = {
				filter: [],
				date_range: date,
				group_by: [],
				reference : false,
				time_trend : false
			}
			merge_hash.group_by.push(HelpdeskReports.locals.current_group_by);
			var param = jQuery.extend({}, _FD.constants.params, merge_hash);
			current_params.push(param);
			HelpdeskReports.locals.params = current_params.slice();
			HelpdeskReports.SavedReportUtil.applyLastCachedReport();
			_FD.submitReports();
		},
		flushEvents: function () {
			jQuery('#reports_wrapper').off('.agent');
		},
		recordAnalytics : function(){
		
			jQuery(document).on("script_loaded", function (ev, data) {
				if( HelpdeskReports.locals.report_type != undefined && HelpdeskReports.locals.report_type == "agent_summary"){
					App.Report.Metrics.push_event("Timespent Report Visited", {});
				}
			});
			
			//Ticket List Exported
				jQuery(document).on("analytics.export_ticket_list", function (ev, data) {
				App.Report.Metrics.push_event("Timespent Report : Ticket List Exported");
				});

			//pdf export
			jQuery(document).on("analytics.export_pdf",function(ev,data){
				App.Report.Metrics.push_event("Timespent Report : PDF Exported",{});
			});
		},
		renderViewMore : function(trigger) {
			var self = this;
			self.showViewMorePane();
			_FD.redraw(true,$(trigger).attr('data-group'));
			var group_title = HelpdeskReports.locals.chart_hash.data[$(trigger).attr('data-group')].name;
			$("#view_more_pane .view_title").html(group_title);
		},
		hideScheduleUntilExportIsReady : function(){
			jQuery("[data-action=schedule-saved-report]").remove()
		}
	}

	return {
		init : function(){
		    _FD.core = HelpdeskReports.CoreUtil;
            _FD.constants = HelpdeskReports.Constants.TimeSpent;
            _FD.bindEvents();
            _FD.core.ATTACH_DEFAULT_FILTER = true;
            HelpdeskReports.locals.current_group_by = 'ticket_type';
            _FD.setDefaultValues();
            _FD.recordAnalytics();
			_FD.hideScheduleUntilExportIsReady();
            _FD.redraw = HelpdeskReports.ChartsInitializer.TimeSpent.redraw
		}
	}
})(jQuery);