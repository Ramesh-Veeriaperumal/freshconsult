var chatReport = function(){

	var $ = jQuery;

	var CLASSES = {"UP_RED":  "report-arrow report-arrow-up report-arrow-red", "UP_GREEN": "report-arrow report-arrow-up report-arrow-green",
				   "DOWN_RED": "report-arrow report-arrow-down report-arrow-red", "DOWN_GREEN": "report-arrow report-arrow-down report-arrow-green"};

	var METRIC_ICONS = { 'no_of_chats': ['DOWN_GREEN', 'UP_RED'], 'answered_chats': ['UP_GREEN', 'DOWN_RED'], 
						 'missed_chats': ['UP_RED', 'DOWN_GREEN'], 'avg_time': ['UP_RED', 'DOWN_GREEN'], 'transferred_chats': ['DOWN_GREEN', 'UP_RED']
						};

	var constructFilter = function(date){
		var select_hash = [];
		var filters = "<li>"+freshchat_i18n.filter_title+": </li><li>"+freshchat_i18n.time_period+": <strong>"+date+"</strong></li>";
		filters += "<li>"+freshchat_i18n.widget+": <strong>"+$("#widget_id option:selected").text()+"</strong></li>";
		var $group = $("#group_id option:selected");
		if($group.length){
			var values = [];
			$group.each(function(){
				values.push($(this).text());
			});
			filters += "<li>"+freshchat_i18n.group+": <strong>"+values.join(", ")+"</strong></li>";
			select_hash.push({
				name : freshchat_i18n.group,
				value : values.join(", ")
			});
		}
		filters += "<li>"+freshchat_i18n.type+": <strong>"+$("#chat_type option:selected").text()+"</strong></li>";
		$("#filter_container").html(filters);

		
		select_hash.push({
			name : freshchat_i18n.widget,
			value : $("#widget_id option:selected").text()
		});
		select_hash.push({
			name : freshchat_i18n.type,
			value : $("#chat_type option:selected").text()
		});
		Helpkit.select_hash = select_hash;
	}

	var groupBy = function(data, group_key){
		var result = _.chain(data)
					.groupBy(group_key)
					.value();
		return result;
	}

	var getChartData = function(data){
		function chartData(data) {
			var total = 0, missed = 0, answered = 0, transfer = [];
			$.map(data, function(chat){
				if(chat.missed){
					missed++;
				}
				if(chat.transfer_id){
					transfer.push(chat.transfer_id);
				}
			});

			total = data.length;
			var transfers = transfer.length - $.unique(transfer).length;
			answered = total - missed - transfers;
			return [total, answered, missed];
		}

		var total_chats = [], answered_chats = [], missed_chats = [];
		$.map(data, function(value, key) {
			var result = chartData(value);
			var tempDate = new Date(key);
			var id = Date.UTC(tempDate.getFullYear(), tempDate.getMonth(), tempDate.getDate());

			total_chats.push([id, result[0]]);
			answered_chats.push([id, result[1]]);
			missed_chats.push([id, result[2]]);
		});

		return [total_chats, answered_chats, missed_chats];
	}

	var showReport = function(){
		$("#loading-box").hide();
		$("#freshchat_summary_report").css('opacity', 1);
		if($("#report-filter-edit").css('visibility') == 'visible'){
			$('#sliding').click();
		}
	}

	var generateChart = function(resp){
		var grouped = groupBy(resp, 'new_created_at');
		var chartVal = getChartData(grouped);

		var chart = new Highcharts.Chart({
			chart: {
				defaultSeriesType: 'column',
				margin: [50, 50, 50, 100],
				renderTo: 'freshchat_line_chart',
				marginBottom: 50,
				marginTop: 10,
				marginLeft: 70,
				marginRight: 30,
				zoomType: 'x',
				borderColor: 'rgba(0,0,0,0)',
				height: 200
			},
			credits: {
				enabled: false
			},
			legend: {
				layout: 'horizontal',
				style: {
					left: 'auto',
					bottom: 0,
					right: '50px',
					top: 'auto',
					fontWeight: 'normal'
				},
				align: 'center',
				y: 15,
				verticalAlign: 'bottom',
				floating: false
			},
			plotOptions: {
				column: {
					showInLegend: false,
					borderWidth: 0,
					shadow: false,
					dataLabels: {
						enabled: false
					}
				}
			},
			series: [{
					name: freshchat_i18n.total_chats,
					data: chartVal[0],
					type: 'line',
					color: '#1A58AB'
				},{
					name: freshchat_i18n.answered_chats,
					data: chartVal[1],
					type: 'line',
					color: '#8BAC2B'
				},{
					name: freshchat_i18n.missed_chats,
					data: chartVal[2],
					type: 'line',
					color: '#AC2F2A'
				}
			],
			title: {
				text: ''
			},
			tooltip: {
				formatter: function() {
					return  Highcharts.dateFormat('%b %e', this.x)+ '<br><strong>' + this.y + ' ' + this.series.name + ' </strong>';
				}
			},
			xAxis: {
				title: {
					text: ''
				},
				type: 'datetime',
				allowDecimals: false,
				dateTimeLabelFormats: {month: '%e. %b', year: '%b'},
				gridLineWidth: 0,
				startOnTick: true,
				endOnTick: true
			},
			yAxis: {
				title: {
					text: freshchat_i18n.num_of_chats,
					style: {
            			color: '#C7C7C7'
            		}
				},
				min: 0,
				gridLineWidth: 1,
				allowDecimals: false,
				gridLineDashStyle: 'ShortDot',
				showFirstLabel: false
			}
		});
	}

	var compareMetric = function(new_val, old_val, type){
		if(new_val == 0 || old_val == 0){
			return '<small><small>';
		}

		var percentage_val = (((new_val - old_val)/old_val) * 100).toFixed(2);
		var icon_class = '';
		if(percentage_val > 0){
			icon_class = METRIC_ICONS[type][0];
		}else{
			icon_class = METRIC_ICONS[type][1];
		}

		return '<small><span class="'+CLASSES[icon_class]+'"></span>'+Math.abs(percentage_val)+'%</small>';
	}

	var TimeFormat = function(milliseconds){
		//format will be hrs:mins:sec
		var duration_formatted = '00:00:00';
		var duration = moment.duration(milliseconds, 'milliseconds');
		var mins = Math.floor(duration.asMinutes());
		var sec = Math.floor(duration.asSeconds());
		if(mins > 60){
			var hours = Math.floor(duration.asHours());
			duration_formatted = (hours >= 10 ? hours : '0'+hours) + ':';
			mins -= hours*60;
			mins >= 1 ? mins : 0;
			sec -= (((hours)*60)+mins)*60;
			sec < 0 ? sec : 0;
			duration_formatted = duration_formatted + (mins >= 10 ? mins : '0'+mins) + ':' + (sec >= 10 ? sec : '0'+sec);
		}else{
			duration_formatted = '00:'+(mins >= 10 ? mins : '0'+mins) + ':';
			sec = sec - (mins*60);
			sec >= 1 ? sec : 0;
			duration_formatted = duration_formatted + (sec >= 10 ? sec : '0'+sec);
		}
		return duration_formatted ;
	}

	var showMetrics = function(data, chatType){
		var current = data.current;
		var previous = data.previous;

		var cur_len = current.length;
		var prev_len = previous.length;

		var cur_missed = 0, prev_missed = 0, cur_queueTime = 0, prev_queueTime = 0;
		var cur_answered = 0, prev_answered = 0;
		var cur_avg = 0, prev_avg = 0, avg_count = 0, pavg_count = 0;
		var cur_transfer = [], prev_transfer = [], cur_transfer_count = 0, prev_transfer_count = 0;

		var modifiedData = [];
		$.map(current, function(chat){
			if(chat.missed){
				cur_missed++;
			}

			cur_queueTime += chat.queue_time;

			if(chat.last_msg_at && !chat.missed){
				var endTime = new Date(chat.last_msg_at).getTime();
				var startTime = new Date(chat.created_at).getTime();
				cur_avg += endTime - startTime;
				avg_count++;
			}

			if(chat.transfer_id){
				cur_transfer.push(chat.transfer_id);
			}

			chat.new_created_at = moment(chat.created_at).format('MM/DD/YYYY');
			modifiedData.push(chat)
		});

		$.map(previous, function(pchat){
			if(pchat.missed){
				prev_missed++;
			}

			prev_queueTime += pchat.queue_time;

			if(pchat.last_msg_at && !pchat.missed){
				var pendTime = new Date(pchat.last_msg_at).getTime();
				var pstartTime = new Date(pchat.created_at).getTime();
				prev_avg += pendTime - pstartTime;
				pavg_count++;
			}

			if(pchat.transfer_id){
				prev_transfer.push(pchat.transfer_id);
			}
		});

		if(cur_queueTime > 0 && (cur_len - cur_missed > 0)){
			cur_queueTime = Math.floor(cur_queueTime / (cur_len-cur_missed));
		}
		if(prev_queueTime > 0 && (prev_len - prev_missed > 0)){
			prev_queueTime = Math.floor(prev_queueTime / (prev_len - prev_missed));
		}

		if(cur_avg > 0 && avg_count > 0){
			cur_avg = Math.floor(cur_avg/avg_count);
		}
		if(prev_avg > 0 && pavg_count > 0){
			prev_avg = Math.floor(prev_avg/pavg_count);
		}

		cur_transfer_count = cur_transfer.length - $.unique(cur_transfer).length;
		prev_transfer_count = prev_transfer.length - $.unique(prev_transfer).length;

		cur_answered = current.length - cur_missed - cur_transfer_count;
		prev_answered = previous.length - prev_missed - prev_transfer_count;

		var cur_chats = cur_answered + cur_missed;
		var prev_chats = prev_answered + prev_missed;

		var metrics = [];
		metrics.push('<div class="report-summary-header"><ul class="inline">');
		metrics.push('<li><h1>'+cur_chats+'</h1></li><li><h1>'+cur_answered+'</h1></li>');
		if(chatType != 2){
			metrics.push('<li><h1>'+cur_missed+'</h1></li>');	
		}
		metrics.push('<li><h1>'+TimeFormat(cur_avg)+'</h1></li><li><h1>'+TimeFormat(cur_queueTime)+'</h1></li><li><h1>'+cur_transfer_count+'</h1></li></ul></div>');
		metrics.push('<div class="report-summary-data"><ul class="inline">');
		metrics.push('<li>'+compareMetric(cur_chats, prev_chats, 'no_of_chats')+'</li>');
		metrics.push('<li>'+compareMetric(cur_answered, prev_answered, 'answered_chats')+'</li>');
		if(chatType != 2){
			metrics.push('<li>'+compareMetric(cur_missed, prev_missed, 'missed_chats')+'</li>');
		}
		metrics.push('<li>'+compareMetric(cur_avg, prev_avg, 'avg_time')+'</li>');
		metrics.push('<li>'+compareMetric(cur_queueTime, prev_queueTime, 'avg_time')+'</li>');
		metrics.push('<li>'+compareMetric(cur_transfer_count, prev_transfer_count, 'transferred_chats')+'</li></ul></div>');
		metrics.push('<div class="report-summary-footer"><ul class="inline">');
		metrics.push('<li><label>'+freshchat_i18n.num_of_chats+'</label></li><li><label>'+freshchat_i18n.answered_chats+'</label></li>');
		if(chatType != 2){
			metrics.push('<li><label>'+freshchat_i18n.missed_chats+'</label></li>');
		}
		metrics.push('<li><label>'+freshchat_i18n.avg_handle_time+'</label></li>');
		metrics.push('<li><label>'+freshchat_i18n.avg_time_queue+'</label></li><li><label>'+freshchat_i18n.num_of_transfer+'</label></li></ul></div>');

		$("#chat_metrics").html(metrics.join(''));
		generateChart(modifiedData);
		showReport();
	}

	var getAgentData = function(data){
		function handleTime(agent, key) {
			var count = 0, time = 0;
			$.map(agent, function(chat) {
				if(chat.last_msg_at){
					count++;
					time += (new Date(chat.last_msg_at).getTime() - new Date(chat.created_at).getTime());
				}
			});
			return {'count': count, 'time': time};
		}

		var list = {};
		$.map(data, function(value, key) {
			if(key != "null"){
				var res = handleTime(value, key);
				list[key] = {answered: value.length, count: res['count'], handleTime: res['time']};
			}
		});

		return list;
	}

	var agentSummary = function(resp){
		var data = groupBy(resp.current, 'agent_id');
		var agent_list = getAgentData(data);
		$("#agent_summary tr:gt(0)").remove();

		var list = [], len = 0;
		for(var k in agent_list){
			var answered = agent_list[k].answered;
			var duration = agent_list[k].handleTime;
			var count = agent_list[k].count;
			var handleTime = 0;
			if(duration > 0 && count > 0){
				handleTime = (duration/count);
			}
			if(freshchat_agents[k]){
				list.push('<tr class="odd"><td><strong>'+freshchat_agents[k]+'</strong></td><td>'+answered+'</td>');
				list.push('<td>'+TimeFormat(handleTime)+'</td><td>'+TimeFormat(duration)+'</td></tr>');
				len++;
			}
		}

		if(len == 0){
			var col = $("#agent_summary tr:first th").length;
			list.push("<tr><td colspan='"+col+"'><div class='list-noinfo'>"+freshchat_i18n.no_data+"</div></td></tr>");
		}
		$("#agent_summary").append(list.join(''));
	}

	var generateReport = function(){
		var dateRange = $("#date_range").val();
		var widget_id = $("#widget_id option:selected").val();
		var chatType = $("#chat_type option:selected").val();

		$("#loading-box").show();
		$("#freshchat_summary_report").css('opacity','0.2');
		$("#loading-box").css('background','transparent');
		$(".reports-loading").css('margin-top','330px');

		constructFilter(dateRange);

		if(dateRange){
			var fromDate = dateRange.split('-')[0];
			var	toDate;
			if(dateRange.split('-')[1]){
				toDate = dateRange.split('-')[1];
			}else{
				toDate = dateRange.split('-')[0];
			}
			var frm = new Date(fromDate);
			frm.setHours(0, 0, 0, 0);
			var to = new Date(toDate);
			to.setHours(23, 59, 59, 999);
			var fromDateUTC = frm.toUTCString();
			var toDateUTC = to.toUTCString();
 		}

		var data = {site_id: SITE_ID, fromDateUTC: fromDateUTC, toDateUTC: toDateUTC, chat_type: chatType, 
									auth_token: LIVECHAT_TOKEN, user_id: CURRENT_USER.id};

		if(widget_id == "deleted") {
			data.deleted_widgets = "1";
		} else if(widget_id != "all") {
			data.widget_id = widget_id;
		}

		$.ajax({
			type: "GET",
			url: window.csURL + "/chat/reports",
			data: data,
			dataType: "jsonp",
			crossDomain: true,
			cache: false,
			success: function(resp){
				showMetrics(resp, chatType);
				agentSummary(resp);
				if(savedReportUtil.filterChanged) {
                     savedReportUtil.save_util.controls.hideDeleteAndEditOptions();
                     savedReportUtil.save_util.controls.showSaveOptions(savedReportUtil.last_applied_saved_report_index); 
                }
			}
		});
	}

	var exportTableToCSV = function($table, filename) {
		var $headers = $table.find('tr:has(th)')
			, $rows = $table.find('tr:has(td)')
			, tmpColDelim = String.fromCharCode(11)
			, tmpRowDelim = String.fromCharCode(0)
			, colDelim = '","'
			, rowDelim = '"\r\n"';

		var csv = '"';
		csv += formatRows($headers.map(grabRow));
		csv += rowDelim;
		csv += formatRows($rows.map(grabRow)) + '"';

		// Data URI
		var csvData = 'data:application/csv;charset=utf-8,' + encodeURIComponent(csv);

		$(this).attr({
				'download': filename
				,'href': csvData
			});

		//------------------------------------------------------------
		// Helper Functions 
		//------------------------------------------------------------
		function formatRows(rows){
			return rows.get().join(tmpRowDelim)
						.split(tmpRowDelim).join(rowDelim)
						.split(tmpColDelim).join(colDelim);
		}

		function grabRow(i,row){
			var $row = $(row);
			var $cols = $row.find('td'); 
			if(!$cols.length) $cols = $row.find('th');  

			return $cols.map(grabCol)
						.get().join(tmpColDelim);
		}

		function grabCol(j,col){
			var $col = $(col),
			$text = $col.text();

			return $text.replace('"', '""'); // escape double quotes
		}
	}

	var init = function(){
		$("#widget_id").val(CURRENT_ACCOUNT.widget_id);

		$("#date_range").daterangepicker({
			earliestDate: Date.parse('12/01/2014'),
			latestDate: new Date(),
			presetRanges: [
				{text: freshchat_i18n.today, dateStart: 'Today', dateEnd: 'Today' },
  			{text: freshchat_i18n.yesterday, dateStart: 'Today-1', dateEnd: 'Today-1' },
  			{text: freshchat_i18n.this_week, dateStart: 'Today-6', dateEnd: 'Today' },
  			{text: freshchat_i18n.this_month, dateStart: 'Today-29', dateEnd: 'Today'},
  			{text: freshchat_i18n.three_months, dateStart: 'Today-89',  dateEnd: 'Today'}
			],
			presets: {
				dateRange: freshchat_i18n.custom_days
			},
			dateFormat: getDateFormat('datepicker'),
			closeOnSelect: true,
			onChange : function() {
                trigger_event("filter_changed",{});
            },
            presetRangesCallback : true
		});

		jQuery(document).on("presetRangesSelected", function(event,status) {
            Helpkit.presetRangesSelected = status;
        });

		$("#cancel, #filter-close-icon").on('click', function(){
			$('#sliding').click();
		});

		$("#submit").on('click', function(){
			generateReport();
		});

		$("#date_range").on('keypress keyup keydown', function(ev) {
			ev.preventDefault();
			return false;
		});

		if($("#report-filter-edit").css('visibility') == 'visible'){
			$('#sliding').slide();
			$('#loading-box').hide();
		}

		$("#export_as_csv").on('click', function(){
			exportTableToCSV.call(this, $('#agent_summary'), 'agent_chat_summary.csv');
		});
	}

	var ieVersionCompatability = function(){
		var nav = navigator.userAgent.toLowerCase();
		if(nav.indexOf('msie') == -1){
			return false;
		}

		var version = parseInt(nav.split('msie')[1]);
		return (version == 8 || version == 9);
	}
	
	var savedReportUtil = (function() {
		
		var _FD = {
	   		last_applied_saved_report_index : -1,
		    CONST: {
		        base_url : "/reports/freshchat/summary_reports",
		        save_report   : "/save_reports_filter",
		        delete_report : "/delete_reports_filter",
		        update_report : "/update_reports_filter"
		    },
		    save_util : Helpkit.commonSavedReportUtil,
		    filterChanged : false,
		   	bindSavedReportEvents : function() {
		        var _this = this;
		        jQuery(document).on('change', '.filter_item,.ff_item', function () { 
		             _this.filterChanged = true;
		        });

		        jQuery(document).on("save.report",function() {
		          _this.saveReport();
		        });
		        jQuery(document).on("delete.report",function() { 
		          _this.deleteSavedReport();
		        })
		        jQuery(document).on("edit.report",function(ev,data) {
		          _this.updateSavedReport(data.isNameUpdate);
		        });
		        jQuery(document).on("discard_changes.report",function() {
		          _this.discardChanges();
		        });
		        jQuery(document).on("apply.report",function(ev,data) {
		          jQuery('[data-action="pop-report-type-menu"]').trigger('click');
		          _this.applySavedReport(data.index);
		        });
		        jQuery(document).on("filter_changed",function(ev,data){
	        		_this.filterChanged = true;
	        	});
		    },
		    saveReport : function() {
		          var _this = this;
		          var opts = {
		              url: _this.CONST.base_url + _this.CONST.save_report,
		              callbacks : {	
	              		 success: function () {
		                      //update the last applied filter
		                      _this.last_applied_saved_report_index = this.new_id;
		                      _this.filterChanged = false;
	                 	 },error: function () {}
		              },
		              params : _this.getParams()
		             };
		              
		          _this.save_util.saveHelper(opts);
		    },
		    getParams : function() {
		    	  var _this = this;
		    	  var params = {};
		          params.data_hash = {};
		        
		          var dateRange = $("#date_range").val();
				  var widget_id = $("#widget_id option:selected").val();
				  var chatType = $("#chat_type option:selected").val();

		          params.data_hash.date = {};
		          if(Helpkit.presetRangesSelected) {
		        	params.data_hash.date.date_range = _this.save_util.dateRangeDiff(dateRange);
		        	params.data_hash.date.presetRange = true;
		          } else {
		        	params.data_hash.date.date_range = dateRange;
		        	params.data_hash.date.presetRange = false;
		          }		                
		          params.data_hash.report_filters = [];

		          params.data_hash.report_filters.push({
		          		name : "widget_id",
		          		value : widget_id
		          });
		          params.data_hash.report_filters.push({
		          		name : "chat_type",
		          		value : chatType
		          });
		          params.data_hash.select_hash = Helpkit.select_hash;
		          return params;
		    },
		    updateSavedReport : function(isUpdateTitle) {
		          var _this = this;
		          
		          var current_selected_index = parseInt(jQuery(".reports-menu li.active a").attr('data-index'));
		          var params = _this.getParams();

		          if(isUpdateTitle) {
		            params.filter_name =  _this.save_util.escapeString(jQuery("#filter_name_edit").val());
		          } else {
		            params.filter_name = Helpkit.report_filter_data[current_selected_index].report_filter.filter_name;
		          }
		          params.id = Helpkit.report_filter_data[current_selected_index].report_filter.id;

		          var opts = {
		          	  current_selected_index : current_selected_index,
		              url: _this.CONST.base_url + _this.CONST.update_report,
		              callbacks : {
	              		 success: function () {
	                      _this.filterChanged = false
	             		 },
			             error: function (data) {
			              }
		              },
		              params : params
		          };
		          _this.save_util.updateHelper(opts);
		    },
		    deleteSavedReport : function() {
		          var _this = this;
		          var current_selected_index = parseInt(jQuery(".reports-menu li.active a").attr('data-index'));
		          _this.flushAppliedFilters();

		          var opts = {
		          	  current_selected_index : current_selected_index,
		              url: _this.CONST.base_url + _this.CONST.delete_report,
		              callbacks : {
		              	success: function (resp) {
		                  _this.applySavedReport(-1);
		                },
			            error: function (data){}
		              }
		          };
		          _this.save_util.deleteHelper(opts);
		    },
		    discardChanges : function() {
		      this.applySavedReport(this.last_applied_saved_report_index);
		      this.save_util.controls.hideSaveOptions(); 
		    },
		    applySavedReport : function(index) {

		        var hash = Helpkit.report_filter_data;
		        var _this = this;
		        var invalid_params_found = false;

		        _this.flushAppliedFilters();
		        _this.last_applied_saved_report_index = index;

		        if(index != -1) {

		            var filter_hash = hash[index].report_filter;

		            //Set the date range from saved range
		            var date_hash = filter_hash.data_hash.date;
		            var daterange;
		            //Set the date range from saved range
		            if(date_hash.presetRange) {
		            	daterange = _this.save_util.convertDateDiffToDate(date_hash.date_range);
		            } else {
		            	daterange = date_hash.date_range;
		            }
		            jQuery('#date_range').val(daterange);
		            
		            if(filter_hash.data_hash.report_filters != null) {
		               
		                jQuery.each(filter_hash.data_hash.report_filters, function(index, filter_row) {

		                  var condition = filter_row.name;
		                  //populate the value
		                  var is_saved_param_valid = _this.checkValidityOfSavedParams(condition,filter_row.value);
		                  
		                  if (is_saved_param_valid) {
		                     jQuery('#' + condition).select2('val',filter_row.value);
		                  } else {
		                    filter_hash.data_hash.report_filters.splice(index,1);
		                    invalid_params_found = true;
		                  }
		              });
		            }
		        } else {
		             var default_date_range = _this.save_util.convertDateDiffToDate(7);
		             jQuery('#date_range').val(default_date_range);
		         }

		        _this.save_util.setActiveSavedReport(jQuery(".reports-menu li a[data-index=" + index +"]"));
		        _this.save_util.cacheLastAppliedReport(index);
		         _this.filterChanged = false;
		        jQuery("#submit").trigger('click');

		        _this.save_util.controls.hideSaveOptions();
		        if(index != -1) {
		            _this.save_util.controls.showDeleteAndEditOptions();
		        } else{
		          _this.save_util.controls.hideDeleteAndEditOptions();
		        }
		        if(invalid_params_found) {
		          //update the filter , removing the invalid params done in above loop
		          _this.updateSavedReport(false);
		        }
		    },
		    checkValidityOfSavedParams : function() {
		        return true;
		    },
		    flushAppliedFilters : function() {
		    	jQuery("#widget_id").val(CURRENT_ACCOUNT.widget_id);
		        jQuery("#chat_type").val("0");
		        
		    },
		    initSavedReports : function(){
		       _FD.bindSavedReportEvents();
		       _FD.save_util.init();
		       _FD.save_util.applyLastCachedReport();
		    }
		}
	    return _FD;
	})();

	return {

		initializeReport : function(CHAT_ENV, URL, FC_HTTP_ONLY){
			if(typeof CHAT_ENV != 'undefined' && CHAT_ENV == 'development'){
				window.csURL = "http://"+URL+":4000"; 
			}else{
				window.csURL = "https://"+URL+":443";
				if(window.location && window.location.protocol=="http:" && (ieVersionCompatability() || FC_HTTP_ONLY)){
					window.csURL = "http://"+URL+":80";
				} 
			}

			init();
			generateReport();
			savedReportUtil.initSavedReports();
		}
	}
}();