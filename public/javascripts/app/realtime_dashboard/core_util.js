window.RealtimeDashboard = window.RealtimeDashboard || {};
RealtimeDashboard.CoreUtil = RealtimeDashboard.CoreUtil || {};

(function ($) {
	RealtimeDashboard.CoreUtil = {
		intervalPeriod: 600000, // 10min interval
		locale_prefix : 'helpdesk.realtime_dashboard.',
		time_format : 'D MMM YYYY,hh:mm A',
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
		bindEvents: function () {
			var self = this;

			this.Utils.bindEvent('click.realtimeDashboard', '.db-group-filter', function (e) {
				self.controls.hideUnresolvedSideBar();
				self.controls.disableGroupSelection();
				self.changeDropdownText(e, "#group-filter .widget-filter", "#group-filter-text");
				jQuery(document).trigger('group_change',{ group_id : $(this).data('groupId')});
			});

			jQuery(document).on('click.realtimeDashboard', '[data-action="hide-dashboard-details"]', function () {
            	self.controls.hideDashboardDetails();
		    });
		    jQuery(document).keyup(function(e) {
		         if (e.keyCode == 27) {
		            // escape key maps to keycode `27`
		            	self.controls.hideDashboardDetails();
		        }
		    });
		    jQuery(document).on('mousemove.realtimeDashboard', '.dashboard-details-wrapper', function(event) {
		        event.preventDefault();
		        jQuery('body').addClass('preventscroll');
		    });
		    jQuery(document).on('mouseleave.realtimeDashboard', '.dashboard-details-wrapper', function(event) {
		        event.preventDefault();
		        jQuery('body').removeClass('preventscroll');
		    });

		    jQuery(document).on('click.realtimeDashboard', '[data-action="next-page"]', function () {
            	jQuery(document).trigger('next_page',{ chart_name : $('#dashboard_details_wrapper').attr('chart_name')});
		    });

		    jQuery(document).on('click.realtimeDashboard', '[data-action="prev-page"]', function () {
            	jQuery(document).trigger('prev_page',{ chart_name : $('#dashboard_details_wrapper').attr('chart_name')});
		    });
		},
		autorefresh: function () {
			var self = this;
			if(RealtimeDashboard.reloader == undefined) {
				RealtimeDashboard.reloader = setInterval(function() {
					var current_tab = jQuery(".header-tabs li.active").data('tab-name');
					if(!document.hidden && current_tab == 'dashboard') {
						//For full page refresh
						//location.reload(true);
						if(RealtimeDashboard.type == 'supervisor') {
							jQuery(document).trigger('group_change',{ group_id : jQuery('.widget-filter.active .db-group-filter').data('groupId') });
						} else {
							jQuery(document).trigger('group_change',{ group_id : '-'});
						}

					}
				},self.intervalPeriod);
			}
		},
		changeDropdownText: function (event, parentSelector, appendSelctor) {
			$(parentSelector).removeClass('active');
			$(event.currentTarget).parent().addClass('active');
			$(appendSelctor).empty().text($(event.currentTarget).text());
		},
		controls : {
			disableGroupSelection : function() {
				$('#filter_by_group_dropdown').addClass('disabled sloading');
			},
			enableGroupSelection : function() {
				$('#filter_by_group_dropdown').removeClass('disabled sloading');
			},
			hideUnresolvedSideBar : function() {
				$("#unresolved_tickets").modal('hide');
			},
			showUnresolvedSideBar : function() {
				$("#unresolved_tickets").modal('show');
			},
			showDashboardDetails : function (chart_id,title,showPager,title_sub_level) {
				var self = this;
	            self.hideDashboardDetails();
	            //Construct Title
	            jQuery(".list-title .level1").empty().html(title);
	            jQuery(".list-title .level2").empty().html(title_sub_level);
	            if(title_sub_level == undefined || title_sub_level == '') {
	            	jQuery(".list-title .level1").addClass('center-title');
	            } else {
	            	jQuery(".list-title .level1").removeClass('center-title');
	            }
	            jQuery('#graph_space').show();
	            jQuery(".graph_details").empty().removeClass('incoming-trend');//.addClass('sloading loading-small');
	            jQuery(".list_items").hide();
	            jQuery('.setup-details-wrapper').removeClass("active");
	            jQuery('#dashboard_details_wrapper').addClass('active').removeClass('hide').attr('chart_name',chart_id);

	        	if(!showPager){
	        		jQuery('.report-pager').addClass('hide');
	        	} else {
	        		jQuery('.report-pager').removeClass('hide');
	        	}

	        	//Record kissmetrics
	        	RealtimeDashboard.CoreUtil.kissmetrics.push_event('DB : Detail view ' + title , {});
	        },
	        hideDashboardDetails: function () {
	            if(jQuery('#dashboard_details_wrapper').hasClass('active')) {
	                jQuery('#dashboard_details_wrapper').removeClass('active');
	                //Always hide the export section & based on availability of tickets unhide
	                jQuery(".export_title").addClass('hide');
	                //Always hide the sla tabs & based on active metric it will be unhidden
	                jQuery(".trend-toggle-tab").addClass('hide');
	        	}
       	 	}
		},
		init : function() {
			var self = this;

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
                cell_height: 270,
                vertical_margin: 18,
                float: false,
                static_grid: true
            };

			if(RealtimeDashboard.type == 'standard') {
					options.width = 3;
					jQuery('.grid-stack').addClass('grid-stack-3');
			} else if(RealtimeDashboard.type == 'agent') {
					options.width = 6;
					jQuery('.grid-stack').addClass('grid-stack-6');
			} else if(RealtimeDashboard.type == 'admin') {
					options.width = 6;
					jQuery('.grid-stack').addClass('grid-stack-6');
			} else {
					options.width = 6;
					jQuery('.grid-stack').addClass('grid-stack-6');
			}
			//Set the page title
			var page_title = RealtimeDashboard.snapshot_label + " : " + unescapeHtml(RealtimeDashboard.helpdesk_name);
			jQuery(document).attr('title',page_title);

			trigger_event("dashboard_visited",{ type : RealtimeDashboard.type });
			$('#grid-stack').gridstack(options);
			$(".widget-scroll").mCustomScrollbar();

			self.autorefresh();
			self.bindEvents();
			self.initWidgets();
			self.dropDown();
			self.refresh.storeLastUpdatedTime();
			//Track custom dashboard visits
			self.kissmetrics.push_event( 'DB :' + RealtimeDashboard.type + ' snapshot viewed', {});
		},
		dropDown : function() {
			var no_of_options = jQuery("#dashboard-filter li").length;
			if(no_of_options == 1) {
				jQuery(".snapshot_menu").hide();
				jQuery(".ticket_summary_title").show();
			} else {
				jQuery(".snapshot_menu").show();
				jQuery(".ticket_summary_title").hide();
			}
		},
		initWidgets : function() {
			var Widgets = RealtimeDashboard.Widgets;
			Widgets.Recent_activity.init();
			if(jQuery('.setup-widget-wrapper').get(0) !== undefined) {
				Widgets.AccountSetup.init();
			}
		},
		makeAjaxRequest: function (args) {
	        args.url = args.url;
	        args.type = args.type ? args.type : "POST";
	        args.dataType = args.dataType ? args.dataType : "json";
	        args.data = args.data;
	        args.success = args.success ? args.success : function () {};
	        args.error = args.error ? args.error : function () {};
	        var _request = jQuery.ajax(args);
    	},
    	showLoader : function(container) {
    		jQuery(container + ' .widget-content').append('<div class="sloading loading-small loading-block"></div>');
    	},
    	hideLoader : function(container){
    		jQuery(container + ' .widget-content .sloading').remove();
    	},
    	appendNoData : function(container) {
    		var mkup = "<div class='no_data_to_display text-center muted mt20'><i class='ficon-no-data fsize-72'></i><div class='mt10'>" + I18n.t('no_date_to_display') +" </div></div>";
    		if(jQuery('.' + container + ' .widget-content').length == 0) {
    			jQuery('.' + container + ' .widget-inner').html(mkup);
    		} else {
    			jQuery('.' + container + ' .widget-content').html(mkup);
    		}

    	},
		destroy: function () {
			clearInterval(this.interval);
			$("#unresolved_tickets").remove();
			this.Utils.destroy();
			RealtimeDashboard.Widgets.AccountSetup.destroy();
		},
		refresh : {
			storeLastUpdatedTime : function() {
				var self = RealtimeDashboard.CoreUtil;
				self.addToLocalStorage('lastUpdatedTime',Date.now());
			},
			getLastUpdatedTime : function() {
				var self = RealtimeDashboard.CoreUtil;
				RealtimeDashboard.locals.lastUpdatedTime = self.readFromLocalStorage('lastUpdatedTime');
			},
			did_time_expire : function() {
				var last_time = this.getLastUpdatedTime();
				var now = Date.now();
				var self = RealtimeDashboard.CoreUtil;
				if(now-last_time > self.intervalPeriod ){
					return true;
				}
				return false;
			}
		},
		addToLocalStorage : function(key,value) {
			if (typeof (Storage) !== "undefined") {
					localStorage.setItem(key,Browser.stringify(value));
				}
		},
		readFromLocalStorage : function(key) {
			if (typeof (Storage) !== "undefined" && localStorage.getItem(key) !== null) {
				return localStorage.getItem(key);
			} else{
				return false;
			}
		},
		shortenLargeNumber: function(num, digits) {
	        var original = num;
	        if (num <= 9999) //Start using abbreviations from 10,000
	            return num;
	        var units = ['k', 'M', 'G', 'T', 'P', 'E', 'Z', 'Y'],
	            decimal;

	        for(var i=units.length-1; i>=0; i--) {
	            decimal = Math.pow(1000, i+1);

	            if(num <= -decimal || num >= decimal) {
	                return +(num / decimal).toFixed(digits) + units[i];
	            }
	        }
	        return num;
    	},
    	isAllSelected : function(value){
    		return value == '-' ? true : false;
    	},

    	kissmetrics : {
    		recordIdentity: function(){
				if(typeof (_kmq) != 'undefined' ){
					_kmq.push(['identify', RealtimeDashboard.full_domain]);
				}
			},
			push_event: function (event,property) {
				var self = RealtimeDashboard.CoreUtil;
				if(typeof (_kmq) != 'undefined' ){
					self.kissmetrics.recordIdentity();
	    			_kmq.push(['record',event,property]);
				}
			}
    	}
	}
}(window.jQuery));
