/*jslint browser: true, devel: true */
/*global  App:true */

window.App = window.App || {};

(function ($) {
	"use strict";

	App.RealtimeDashboard = {
		tickets_data : {},
		interval:0,
		intervalPeriod: 300000, // 5min interval
		isGlobalView: false,
		requestData: {},
		isResponder: false,

		Constants: {
			summaryURL: "/helpdesk/tickets_summary",
			achievementsURL: "/helpdesk/achievements"
		},

		Utils: {
			nameSpace: 'realtimeDashboard',
			arrayDeepClone: function (object) {
				return object.map(function( value ) { return value; });
			},
			bindEvent: function (event, selector, callback) {
				$(document).on([ event, this.nameSpace ].join('.'), selector, callback);
			},
			renderChart: function (chartType, chartOptions) {

				if (chartType == "Bar") {
					if ($(chartOptions.renderTo).data('barChart')) {
						$(chartOptions.renderTo).data('barChart').updateChartData(chartOptions);
					} else {
						$(chartOptions.renderTo).barChart(chartOptions);
					}
					
				} else if (chartType == "Progress") {
					$.progressChart(chartOptions)
				}
			},
			renderTemplate: function (selector, url, data) {
				jQuery(selector).empty()
								.append( JST[ url ]({ renderData : data }) );
			},
			destroy: function () {
				$(document).off('.' + this.nameSpace);
			}
		},
		onFirstVisit: function (data) {
			this.onVisit(data);
		},
		onVisit: function (data) {
			// Call Old Dashboard init function

			setTimeout(function() {
			  $('#quests-section-container, #mini-leaderboard, #Activity, #sales-manager-container, #moderation-stats').trigger('afterShow');
			},50);

			$('#sales-manager-container').on('remoteLoaded', function(e){	
			  if($('#sales-manager-container').find('.details-container')){
			    $(this).show();
			  }
			});

			var options = {
                width: 3,
                cell_height: 250,
                vertical_margin: 20,
                float: false,
                static_grid: true
            };

            $('#grid-stack').gridstack(options);

			this.isGlobalView = $('#realtime-dashboard-content').data('widgetType'); //view_type;
			
			this.getTicketSummaryData();
			// this.getSummaryOnInterval();
			this.bindEvents();
		},
		onLeave: function (data) {
			this.destroy();
		},
		bindEvents: function () {
			var self = this;

			this.Utils.bindEvent('click', '.view_all_link', function (e) {
				$('.unresolved_tickets').barChart('destroy');
				self.sidebarModalChart( $(e.currentTarget).data('content') );
			});

			this.Utils.bindEvent('click', '.db-group-filter', function (e) {
				$("#unresolved_tickets").modal('hide');
				$('#filter_by_group_dropdown').addClass('disabled sloading');
				self.changeDropdownText(e, "#group-filter .widget-filter", "#group-filter-text");
				self.getTicketSummaryData($(this).data('groupId'));
			})

			this.Utils.bindEvent('click', '.summery-filter', function (e) {
				var queryString = $(this).attr('href').split(/[?#]/)[0];
				var groupId = self.requestData['group_id'];

				if (self.isGlobalView){
					queryString += ( groupId != undefined && groupId != '-' ) ? '?group=' + groupId : ''
				} else {

					queryString += ($(this).data('origName') != "new") ? '?agent=' + DataStore.get('current_user').currentData.user.id : '?group=0' ; //current_user has took from DataStore object
				} 

				$(this).attr('href', queryString);
			})

			this.Utils.bindEvent('click', '.group_vs_status', function() {
				var requestData = {}

				if (self.isResponder){
					requestData['group_id'] = (self.requestData['group_id']).toString();
					requestData['group_by'] = "responder_id";
				} else {
					requestData['group_by'] = "group_id";
				};

				storeInLocalStorage('unresolved-tickets-filters', requestData);
			})
		},
		getSummaryOnInterval: function () {
			this.interval = setInterval($.proxy(this.getTicketSummaryData, this),
								this.intervalPeriod);
		},
		getTicketSummaryData: function (group_id) {
			var self = this, 
				data = {};
				
			if (this.isGlobalView){
				var groupId = group_id || this.requestData['group_id'];
				
				data['global'] = true;
				if (groupId != undefined && groupId != "-") {
					data['group_id'] = groupId;
					data['group_by'] = "responder_id";
				}
			} 

			this.requestData = data;

			$.ajax({
                data: data,
                url: self.Constants.summaryURL,
                success: function (response) {
                    self.tickets_data = response.tickets_data;
                    self.onSuccess();
                }
            });
		},
		onSuccess: function () {
			this.renderTicketSummary();
			// this.renderChartData();
			// this.checkIsSidebarViewing();
			$('#filter_by_group_dropdown').removeClass('disabled sloading');
		},
		getAchievements: function () {
			var self = this;
			$.ajax({
               
                url: self.Constants.achievementsURL,
                success: function (response) {
                	var badges = self.getBadges(response.badges);
                	var object = {
                		badges: badges,
                		chartData : response
                	}

                	self.Utils.renderTemplate("#achievements", "app/realtime_dashboard/template/achievements", object);
                	self.renderProgresschart(response);
                }
            });
		},
		getBadges: function (badgeIds) {
			var badges = [],
				badgeIds = (badgeIds != "") ? badgeIds.split(',') : "";

			$.each(badgeIds, function(i, val) {
				badges.push(DataStore.get('badges').findById(parseInt(val)));
			})

			return badges;
		},
		renderProgresschart: function (achievementData) {
			var options = {
				renderTo : "#achievementsChart",
				data: {
					label : achievementData.current_level_name,
					value : achievementData.points,
					total : achievementData.points + achievementData.points_needed
				},
				width: 80,
        		height: 80
			}
			this.Utils.renderChart('Progress', options);
		},
		renderTicketSummary: function () {
			if (!$.isEmptyObject(this.tickets_data.ticket_trend)) {
				this.Utils.renderTemplate('#ticket-summary', 
				'app/realtime_dashboard/template/ticket_summary', this.tickets_data.ticket_trend);
			}
		},
		changeDropdownText: function (event, parentSelector, appendSelctor) {
			$(parentSelector).removeClass('active');
			$(event.currentTarget).parent().addClass('active');
			$(appendSelctor).empty().text($(event.currentTarget).text());
		},
		constructChart: function (chartType, chartname, selector, chartData, sliceData) {
			var self = this;
			var options = {
				renderTo: selector,
				data: chartData,
				sliceDataAfter: sliceData,
				name: chartname,
				isRtl: ($("html").attr("dir") == "rtl") ? true : false,
				callback: function(id) { 
					var chartname = {
						"unresolved_tickets_by_priority"	: "priority",
						"unresolved_tickets_by_ticket_type"	: "type",
						"unresolved_tickets_by_status"		: "status",
						"unresolved_tickets_by_group_id"	: "group",
						"unresolved_tickets_by_responder_id": "agent"
					}

					var queryString = chartname[this.options.name] +"="+ id;

					if (self.isResponder) {
						queryString += '&group=' + self.requestData['group_id'];
					} 

					if (!self.isGlobalView) {
						queryString += '&agent=' + DataStore.get('current_user').currentData.user.id;
					}

					window.open("/helpdesk/tickets?"+ queryString, '_blank');
				}
			}

			this.Utils.renderChart(chartType, options);
		},
		renderChartData: function () {
			var self = this;

			$.each(this.tickets_data.widgets, function(key, object){
				self.checkDataAndconstructChart(key, object);
			});
		},
		checkDataAndconstructChart: function (key, object) {
			var chartname = key;

			if (key == "unresolved_tickets_by_responder_id") {
				key = "unresolved_tickets_by_group_id";
				chartname = "unresolved_tickets_by_responder_id";

				this.isResponder = true;
				$('.tickets_by_group').addClass('hide');
				$('.tickets_by_agent').removeClass('hide');
			} else {
				this.isResponder = false;
				$('.tickets_by_group').removeClass('hide');
				$('.tickets_by_agent').addClass('hide');
			}

			$('[data-content="' + key + '"]').hide(); // Default Hide the View All panel

			if (object.length > 4) {
				$('[data-content="' + key + '"]').show(); // Show the View All panel
			}

			this.constructChart('Bar', chartname ,'#' + key, object, 4);
		},
		checkIsSidebarViewing: function () {
			if($('.slider-modal').is(":visible")) {
				var chartName = $('.unresolved_tickets').data('chartName');
				this.sidebarModalChart(chartName);
			}
		},
		sidebarModalChart: function (key) {
			if (this.isResponder && key == 'unresolved_tickets_by_group_id') {
				key = 'unresolved_tickets_by_responder_id';
			}

			$('.unresolved_tickets').data('chartName', key);
			this.constructChart('Bar', key, '.unresolved_tickets', this.tickets_data.widgets[key], 0);
		},
		scrollTopOnLoadMore: function (){
			var ele 		 = $(".activityfeed"),
				docTop 	     = $(ele).scrollTop(),
				frameEle 	 = ele,
			    frame 		 = $(frameEle).height() + docTop,
			    percent 	 = 40,
			    scrollTo 	 = Math.floor($(frameEle).height() * percent / 100);

			   	$(ele).animate({
			        scrollTop: (docTop + scrollTo)
			    })
		},
		destroy: function () {
			clearInterval(this.interval);
			$("#unresolved_tickets").remove();
			this.Utils.destroy();
		}
	};
}(window.jQuery));