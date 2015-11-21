HelpdeskReports.ChartsInitializer = HelpdeskReports.ChartsInitializer || {};

HelpdeskReports.ChartsInitializer.AgentSummary = (function () {
	var _FD = {
		populatetemplate: function(data){
			var metricsData = JST["helpdesk_reports/templates/agent_summary_tmpl"]({
				'data':  data,
				'report' : "agent"
			});
			jQuery("[data-table='ticket-data']").html(metricsData);
		},
		calculateAverage : function(data){
			var metrics_list = HelpdeskReports.Constants.AgentSummary.metrics;
			var average = {};
			var column_data_count = {};

			for (i = 0; i < metrics_list.length; i++) { 
			    average[metrics_list[i]] = 0;
			    column_data_count[metrics_list[i]] = 0;
			}
			for( row = 0; row < data.length ; row ++ ){
				var row_data = data[row];
				for (i = 0; i < metrics_list.length; i++) { 
					var value = row_data[metrics_list[i]];
					if( value != 0 && value != '-'){
						average[metrics_list[i]] += value;
						column_data_count[metrics_list[i]] += 1	
					} 
				}
			}
			for (i = 0; i < metrics_list.length; i++) { 
			    if(column_data_count[metrics_list[i]] != 0){
                    average[metrics_list[i]] = Math.round(average[metrics_list[i]] / column_data_count[metrics_list[i]]);
                }
			}
			//Populate Average Data Template
			var averageData = JST["helpdesk_reports/templates/average_tmpl"]({
				'average':  average,
				'report' : "agent"
			});
			jQuery(".metric-average-header").html(averageData);
		},
		initDataTable : function(row_count) {
				var oTable = jQuery("#agent-summary").dataTable({
					"dom" : 'frtSp',
                    "bSortCellsTop": true,
                    "bAutoWidth": false,
                    "sScrollX": "100%",   
					"sScrollXInner": "200%",
                    "bFilter" : false, 
                    "bLengthChange" : false,
                    "scrollDistance" : 850,
                    "aoColumns": [
                        { "sWidth": "100px" ,"orderSequence": [ "desc" , "asc" ]},
                        { "sWidth": "130px" ,"orderSequence": [ "desc" , "asc" ]},
                        { "sWidth": "130px" ,"orderSequence": [ "desc" , "asc" ]},
                        { "sWidth": "150px" ,"orderSequence": [ "desc" , "asc" ]},
                        { "sWidth": "150px" ,"orderSequence": [ "desc" , "asc" ]},
                        { "sWidth": "130px" ,"orderSequence": [ "desc" , "asc" ]},
                        { "sWidth": "100px" ,"orderSequence": [ "desc" , "asc" ]},
                        { "sWidth": "100px" ,"orderSequence": [ "desc" , "asc" ]},
                        { "sWidth": "80px"  ,"orderSequence": [ "desc" , "asc" ]},
                        { "sWidth": "160px" ,"orderSequence": [ "desc" , "asc" ]},
                        { "sWidth": "150px" ,"orderSequence": [ "desc" , "asc" ]},
                        { "sWidth": "150px" ,"orderSequence": [ "desc" , "asc" ]}
                      ],
					  "fixedColumns":   true,
					  "oLanguage": {
						"oPaginate": {
						"sNext": ">",
						"sPrevious": "<"
						},
						"sSearch": '<i class="ficon-search"></i>',
						"sSearchPlaceholder": "Search"
					  },
					  "fnDrawCallback": function(oSettings) {
					        if (row_count < 11) {
					            jQuery('.dataTables_paginate').hide();
					        }
					  }
                });
 				if (jQuery.browser.safari) { 
 					setTimeout(function(){
 					 oTable.fnAdjustColumnSizing(); 
 					}, 0 ); 
 				}
		}	
	};
	return  {
		init: function(data){
			_FD.populatetemplate(data);
			//_FD.calculateAverage(data);
			_FD.initDataTable(data.length);
		}
	}
})();