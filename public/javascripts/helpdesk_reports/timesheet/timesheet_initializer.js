
Helpkit.TimesheetInitializer = (function () {
	var _FD = {
		group_columns : {
			"customer_name" : 1,
			"agent_name" : 5,
			"group_name" : 6,
			"product_name" : 7,
			"workable" : 1,
			"group_by_day_criteria" : 4,
		},
		COLUMN_LIMIT_FOR_PDF : 10,
		initDataTable : function() {

			 var self = this;
			 self.flushDataTable();

			 var $table_container = jQuery("#timesheet_table");
			 var params = {};
			 var pagination = Helpkit.locals.pagination;
			 /*
			 params['totaltime'] = pagination['totaltime'];
          	 params['previous_group_id'] = pagination['previous_group_id'];
          	 params['group_by'] = jQuery('#group_by_field').val(),
          	 params['previous_entry_id'] = pagination['previous_entry_id'];
          	 params['latest_timesheet_id'] = pagination['latest_timesheet_id'];
          	 params['load_time'] = pagination['load_time'];
			 */
			 self.final_params = jQuery.extend(Helpkit.locals.current_params, Helpkit.locals.pagination);

			 jQuery.fn.dataTableExt.sErrMode = 'throw';
			 var config = {
 					"ordering" : false,
			        "bLengthChange" : false,
			        "bFilter" : false,
			        "dom" : 'tsSp',
			        "bAutoWidth": false,
			        "sScrollX": "100%",
			        "sScrollXInner": "200%",
			        "aoColumnDefs": [
			          {"aTargets" : 0 , 'width' : '180px'},
			          {"aTargets" : ['priority_name','status_name'] , 'width' : '60px'},
			          {"aTargets" : 'note','width' : '180px'},
			          {"aTargets": '_all', "width": "120px"}
			        ],
			        "oLanguage": {
			            "oPaginate": {
			              "sNext": ">",
			              "sPrevious": "<"
			            }
			        },
			        "pageLength": 30,
			        "scrollDistance" : 500,
			        "serverSide": true,
			        "ajax" : function( data, callback, settings ) {
			        	self.final_params['scroll_position'] = data['start'] / 30;
				        //self.final_params['current_group'] = self.final_params['group_by'] = jQuery('#group_by_field').val()
				      	self.final_params['columns'] = Helpkit.locals.columns;

			        	jQuery.ajax({
			        		url: Helpkit.locals.pagination['endpoint'],
				            method : "POST",
				            data : self.final_params,
				            dataType : "json",
				            success: function(json) {
				            		var array = [];
								      for( key in json['time_sheets']) {
								      	array = array.concat(json['time_sheets'][key]);
								      }
								      if(array.length != 0) {
								         	array = array.map(function(el,i) {
									      	var row = el;
									      	row['workable_id'] = el["display_id"];
									      	row['workable_desc'] = el['subject'];
									      	var subject = el['subject'];
									      	if(subject.length > 73){
									      		subject = subject.substr(0,73) + '...';
									      	}
									      	row['workable'] = '<a href="/helpdesk/tickets/' + el["display_id"] + '" target="_blank">' + subject + ' (#' + el['display_id'] +')</a>';
									      	row['priority_name'] =  el["priority_name"];
									      	row['status_name'] = el["status_name"];
									      	row['group_by_day_criteria'] = (new moment(el["executed_at"])).format("ddd, Do MMM,YYYY");
									      	row['group_name'] = el["group_name"] != null ? el["group_name"] : '-';
									      	row['hours'] = self.hour_markup(row);
									      	row['ticket'] = el['subject'];
									      	row['product_name'] = el['product_id'] != null ? el['product_name'] : '-';
									      	var note = el['note'];
									      	if(note != null && note.length > 73) {
									      		note = note.substr(0,73) + '...'
									      	}
									      	row['note'] = el['note'] != null ? note : '-';
									      	//loop through headers array and check for custom columns
									      	var custom_columns = Helpkit.locals.columns;

											jQuery.each(custom_columns,function(idx,col) {
												row[col] = el[col] == null ? '-' : el[col];
											});
									      	return row;
									    });
								      }
								      callback({
							                recordsTotal: Helpkit.locals.pagination['total_row_count'],
							                recordsFiltered: Helpkit.locals.pagination['total_row_count'],
							                data: array
							            });
								}
			        	});
			        },
			        "deferLoading" : Helpkit.locals.pagination['total_row_count'],
			        "drawCallback": function ( settings ) {

			            var api = this.api();
			            var rows = api.rows( {page:'current'} ).nodes();
			            var last = null;
			 			var current_group_by = Helpkit.locals.current_group_by == undefined ? "customer_name" : Helpkit.locals.current_group_by;
			 			var group_count = Helpkit.locals.pagination['group_count'];
			 			var group_names  = Helpkit.locals.pagination['group_names'];

			            api.column(self.group_columns[current_group_by], {page:'current'} ).data().each( function ( group, i ) {

			                if ( last !== group ) {
			                	var group_id;
			                	var row = jQuery(rows).eq(i);

			                	if(group == '-') {
			                		group_id = 0;
			                	} else {
			                		jQuery.each(_.keys(group_names),function(idx,el) {
					            		// For date and ticket title, we format before putting it to table
					            		// So we apply same formatting and validate
					            		if(current_group_by == "group_by_day_criteria") {
					            			 var group_name  = el;
					            			 //converting to date format
					            			 var is_same = moment(group_name).isSame(row.attr('data-executed-at'),'day');
					            			 if(is_same){
					            			 	group_id = group_name;
					            			 }
					            		} else if( current_group_by == "workable") {
					            			//ticket id will be fetched from dom
					            		} else {
					            			if(group_names[el] == group){
						            			group_id = el;
						            		}
					            		}
				            		});
			                	}

			                	if(current_group_by == "workable") {
			                		var fr_group_count = group_count[row.attr('data-workable-id')];
			                		var mkup = '<tr class="group" data-group="' + row.attr('data-workable-desc') +'"><td colspan="' + (Helpkit.locals.colspan + 1) +'" >'+'</td><td class="hours"><strong>'+ fr_group_count +'</strong></td></tr>';
			                		row.before(mkup);
			                	} else {
			                		var fr_group_count = group_count[group_id];
			                		jQuery(rows).eq( i ).before(
			                      	  '<tr class="group" data-group="' + group +'"><td colspan="' + (Helpkit.locals.colspan) +'" >'+'</td><td class="hours"><strong>'+ fr_group_count +'</strong></td></tr>'
			                    	);
			                	}

			                    last = group;
			                }
			            });
			            fixedColumn.init({},"#timesheet_table");
			        },
			        "createdRow": function ( row, data, index ) {
			        	jQuery(row).attr({
		        			'data-workable-id': data['workable_id'],
		        			'data-workable-desc': data['workable_desc'],
		        			'data-group-id' : data['group_id'],
		        			'data-user-id' : data['user_id'],
		        			'data-executed-at' : data['executed_at']
		        		});
			        }
			 };
			//Hide current groupby column
			var current_group_by = Helpkit.locals.current_group_by == undefined ? "customer_name" : Helpkit.locals.current_group_by;
			var hide_row = { "aTargets":  self.group_columns[current_group_by] , "visible" : false }
			if(current_group_by != "workable"){
				config.aoColumnDefs.push(hide_row);	
			}
			var headers = Helpkit.locals.headers;

			jQuery.each(headers,function(idx,col) {
				var row = { "aTargets" : idx , "mData" : col , "sClass": col};
				config.aoColumnDefs.push(row);
			});

			var oTable = $table_container.dataTable(config);
	        if($table_container.length == 1) {

				if (jQuery.browser.safari) {
					setTimeout(function(){
					 oTable.columns.adjust().draw();
					}, 0 );
	 			}
	        }
		},
		hour_markup : function(row) {
			//Attach indicator
	      	if(row['billable']) {
	      		return '<span class="billable-block" title="billable">&nbsp;</span>' + row['timespent'];
	      	} else {
	      		return'<span class="non-billable-block" title="non-billable">&nbsp;</span>' + row['timespent'];
	      	}
		},
		flushDataTable : function(){
	        fixedHeader.flush();
	    },
	    toggleExportPdf : function(){
	    	if(this.COLUMN_LIMIT_FOR_PDF >= (Helpkit.locals.colspan + 1)){
	    		jQuery("#export_pdf").show();
	    	} else {
	    		jQuery("#export_pdf").hide();
	    	}
	    }
	};
	return  {
		init: function(){
			_FD.toggleExportPdf();
			_FD.initDataTable();
		}
	}
})();
