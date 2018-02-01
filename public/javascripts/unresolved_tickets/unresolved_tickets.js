var UnresolvedTickets = (function () {
	var CONST = {
		unresolved_url    : "/helpdesk/dashboard/unresolved_tickets_data",
		ticketlist_url	  : "/helpdesk/tickets?",
		dynamicWidth 	  :( jQuery('body')[0].clientWidth * 0.9 - 40 - 60 - 150 ),
		visibleColumn	  : 5,
		visibleRow		  : 10
	};
	CONST.calculatedWidth = (!jQuery.browser.msie) ? CONST.dynamicWidth : CONST.dynamicWidth - 15;
	var _FD = {
		events: function(){
			var $supervisorDashboard = jQuery("#supervisor-dashboard");
			// Listener for open filter
			$supervisorDashboard.on('click.unresolved', '[data-action="open-filter-menu"]',  function(){
					jQuery("#inner").addClass('openedit');
					jQuery(".fd-filter-container").show();
					
			});
			// Listener for close filter
			$supervisorDashboard.on('click.unresolved', '[data-action="close-filter-menu"]', function(){
					if(jQuery('#inner').hasClass('openedit')){
						jQuery('#inner').removeClass('openedit');
						setTimeout(function(){
							 jQuery(".fd-filter-container").hide();
						}, 100);
       			    }
			});
			// Listener for Generate
			$supervisorDashboard.on('click.unresolved', '[data-action="unresolved-submit"]', function(){
					 jQuery(".fd-filter-container").hide();
					_FD.triggerAjax(_FD.constructParams());
			});
			// Listener for tab click
			$supervisorDashboard.on('click.unresolved', "#unresolved-tab li", function(e){
				_FD.switchTab(e);
			});
			// Listener for showtickets link
			$supervisorDashboard.on('click.unresolved', '#unresolved-tickets tbody a', function(e){
				_FD.showTickets(e);
			});	
			// Filter transition
			$supervisorDashboard.on('focus.unresolved', '.dataTables_filter input', function(){
				jQuery(this).addClass('widelength');
				jQuery(this).parent().addClass('widelength');
			});
			// Filter transition
			$supervisorDashboard.on('blur.unresolved', '.dataTables_filter input', function(){
				jQuery(this).removeClass('widelength').attr('placeholder', "Search");
				jQuery(this).parent().removeClass('widelength');
			});

			//agent and group type filter events
			if(shared_ownership_enabled){
				jQuery('.agent_mode , .group_mode').on('click.unresolved', function(e){
					e.preventDefault();
					jQuery(this).closest(".fd-menu").css("display", "none");
					if(this.className == "agent_mode"){
						jQuery('.agent_text').text(jQuery(this).text());
						jQuery('.agent_text').attr('value',this.getAttribute('mode'));
						jQuery('.agent_mode .icon.ticksymbol').remove();
						jQuery(this).prepend("<span class='icon ticksymbol'></span>");
					}else{
						jQuery('.group_text').text(jQuery(this).text());
						jQuery('.group_text').attr('value',this.getAttribute('mode'));
						jQuery('.group_mode .icon.ticksymbol').remove();
						jQuery(this).prepend("<span class='icon ticksymbol'></span>");
					}
				});
			}
			
		},
		unbindEvents: function(){
			jQuery("#supervisor-dashboard").off('.unresolved');
		},
		getFilterData: function(){
			var filterData = [];
			var group_list = jQuery("[data-filterkey='group_id']").children("option:selected").map(function(){
					return jQuery(this).val();
			});
			var agent_list = jQuery("[data-filterkey='responder_id']").children("option:selected").map(function(){
					return jQuery(this).val();
			});
			filterData['group'] = group_list;
			filterData['agent'] = agent_list;
			return filterData;
		},
		showTickets: function(evt){
			var _currentData = jQuery(evt.currentTarget).data(),
				currentTab = jQuery("#unresolved-tab li.active").data('redirect'),
				metricurl, filteredData = _FD.getFilterData(), filterData;
			var agentType = jQuery('#responder-box .agent_text').attr('value') === 'responder_id' ? 'agent' : 'internal_agent';
			var groupType = jQuery('#group-box .group_text').attr('value') === 'group_id' ? 'group' : 'internal_group';
			//checking for group filter type
			if(currentTab === 'group'){
				currentTab = groupType;
			}else {
				currentTab = agentType;
			}
			if( _currentData.id === 'unassigned' ){
				//Marking it as -1 as its per norm in custom ticket filter for unassigned.
				metricurl = currentTab+"=-1"+"&status="+_currentData.status;
			}else{
				var agentQuery = (filteredData.agent.length ? "&"+ agentType +"="+Array.prototype.slice.call(filteredData.agent).join(',') : '');
				var groupQuery = (filteredData.group.length ? "&"+ groupType +"="+Array.prototype.slice.call(filteredData.group).join(',') : '');
				// metricurl = ( agentQuery.length === 0 && groupQuery.length === 0 ) ? (currentTab+"="+_currentData.id+"&status="+_currentData.status) : ("status="+_currentData.status+agentQuery+groupQuery)
				filterData = (currentTab === 'agent' || currentTab === 'internal_agent') ? groupQuery : agentQuery;
				metricurl = "status="+_currentData.status+"&"+currentTab+"="+_currentData.id+filterData
			}
			window.open(CONST.ticketlist_url+metricurl, '_blank');
		},
		switchTab: function(e){
			if(!jQuery(e.currentTarget).hasClass('active')){
				jQuery("#unresolved-tab li").removeClass('active');
				jQuery(e.currentTarget).addClass('active');
				var tab_switch_param = jQuery("#unresolved-tab li.active").data('groupby');
				jQuery(".no-data-section").hide();
				_FD.triggerAjax(_FD.constructParams(), "in-loader");
			}
		},
		resetfilterselect2: function(){
			jQuery(".reset-select2").select2("val", "");
		},
		constructParams: function(){
			var currentTab = jQuery("#unresolved-tab li.active").data('redirect');
			if(currentTab == 'agent'){
				jQuery("#unresolved-tab li.active").data('groupby', jQuery('.agent_text').attr('value'));
				jQuery("#unresolved-tab li.active").attr('data-groupby', jQuery('.agent_text').attr('value'));
			}else{
				jQuery("#unresolved-tab li.active").data('groupby', jQuery('.group_text').attr('value'));
				jQuery("#unresolved-tab li.active").attr('data-groupby', jQuery('.group_text').attr('value'));
			}
			var group_by =  jQuery("#unresolved-tab li.active").data('groupby'),
				param = {"group_by":group_by};
			if(jQuery('.agent_text').attr('value') === 'responder_id'){
				var agent_key = jQuery("[data-filterkey='responder_id']").val() || [];
				param.responder_id = agent_key.join(',');
			}else{
				var internal_agent_key = jQuery("[data-filterkey='responder_id']").val() || [];
				param.internal_agent_id = internal_agent_key.join(',');
			}

			if(jQuery('.group_text').attr('value') === 'group_id'){
				var group_key = jQuery("[data-filterkey='group_id']").val() || [];
				param.group_id = group_key.join(',');
			}else{
				var internal_group_key = jQuery("[data-filterkey='group_id']").val() || [];
				param.internal_group_id = internal_group_key.join(',');
			}

			_FD.saveFilterData(param);
			_FD.setFilterData(param);
			return param;
		},
		checkEmptyParams: function(data){
			var requestParams = {};
			requestParams.group_by = data.group_by;
			if(data.group_id && data.group_id !== ""){
				requestParams.group_id = data.group_id;
			}
			if(data.internal_group_id && data.internal_group_id !== ""){
				requestParams.internal_group_id = data.internal_group_id;
			}
			if(data.responder_id && data.responder_id != ""){
				requestParams.responder_id = data.responder_id;
			}

			if(data.internal_agent_id && data.internal_agent_id != ""){
				requestParams.internal_agent_id = data.internal_agent_id;
			}

			return requestParams;
		},
		triggerAjax: function(data, loaderType){
			var request = _FD.checkEmptyParams(data);

			jQuery.ajax({
				url: CONST.unresolved_url,
				type: 'GET',
				dataType: 'JSON',
				data: request,
				timeout: 60000,
				beforeSend: function(){
					_FD.destroyTable();
					_FD.showLoader(loaderType);
				},
				success: function(data){
					_FD.showWrapper();
					if(data.tickets_data.data.length <= CONST.visibleColumn + 1){
						_FD.constructStandardTable(data);
					}else{
						_FD.constructTable(data);
					}
					_FD.hideLoader(loaderType);
				},
				error: function(){
					_FD.showWrapper();
					_FD.errorSection();
					_FD.hideLoader(loaderType);
				}
			});
		},
		showWrapper: function(){
			 jQuery(".breadcrumb").removeClass('hide');
			 jQuery(".unresolved-data-tab").removeClass('hide');
			 jQuery("#unresolved-tab").show();
			 jQuery(".unresolved-tickets-wrapper").show();
			 jQuery(".detailed-header").removeClass('hide');
		},
		errorSection: function(){
			jQuery("#unresolved-tab").hide();
			jQuery(".unresolved-tickets-wrapper").hide();
			if(jQuery(".no-data-section i").hasClass("ficon-no-data")){
				jQuery(".no-data-section i").removeClass("ficon-no-data").addClass("ficon-went-wrong");
			}
			jQuery(".no-data-section h4").text(connection_error);
			jQuery(".no-data-section").show();
		},
		destroyTable: function(){
			if(jQuery('#unresolved-tickets').hasClass('dataTable')){
				jQuery('#unresolved-tickets').dataTable().fnDestroy();
			}
		},
		showLoader: function(type){
			var loaderType = (type === "in-loader") ? "in-loader" : "full-loader";
			jQuery(".unresolved-tickets-wrapper").addClass("visualhide");
			jQuery("#"+loaderType).show();
		},
		hideLoader: function(type){
			var loaderType = (type === "in-loader") ? "in-loader" : "full-loader";
			jQuery(".unresolved-tickets-wrapper").removeClass("visualhide");
			jQuery("#"+loaderType).hide();
		},
		setFilterText: function(){
			//remove existing select marks
			jQuery("#agentSort .icon.ticksymbol").remove();
			jQuery("#groupSort .icon.ticksymbol").remove();
			//setting defeult values for filter type selection
			jQuery('.agent_text').attr('value', 'responder_id');
			jQuery('.agent_text').text(jQuery("#agentSort a[mode='responder_id']").text());
			jQuery("#agentSort a[mode='responder_id']").prepend("<span class='icon ticksymbol'></span>");
			jQuery('.group_text').attr('value', 'group_id');
			jQuery('.group_text').text(jQuery("#groupSort a[mode='group_id']").text().trim());
			jQuery("#groupSort a[mode='group_id']").prepend("<span class='icon ticksymbol'></span>");
		},
		handleFilterSelection: function(filter, textSelector, dropSelector){
			if(shared_ownership_enabled){
				var filterMapping = {
					"responder_id" : "internal_agent_id",
					"internal_agent_id" : "responder_id",
					"group_id" : "internal_group_id",
					"internal_group_id" : "group_id"
				}
				jQuery('.' + textSelector).attr('value', filter);
				jQuery('.' + textSelector).text(jQuery("#"+ dropSelector +" a[mode='"+ filter +"']").text());
				jQuery("#"+ dropSelector +" a[mode='"+ filterMapping[filter] +"'] .icon.ticksymbol").remove();
				jQuery("#"+ dropSelector +" a[mode='"+ filter +"']").prepend("<span class='icon ticksymbol'></span>");
			}
		},
		retainFilters: function(localStorage_obj){
			if(localStorage_obj.group_by == 'internal_agent_id' || localStorage_obj.group_by == 'responder_id'){
				jQuery("#unresolved-tab li[data-redirect = 'agent']").data('groupby', localStorage_obj.group_by);
				jQuery("#unresolved-tab li[data-redirect = 'agent']").attr('data-groupby', localStorage_obj.group_by);
			}else{
				jQuery("#unresolved-tab li[data-redirect = 'group']").data('groupby', localStorage_obj.group_by);
				jQuery("#unresolved-tab li[data-redirect = 'group']").attr('data-groupby', localStorage_obj.group_by);
			}
			jQuery("[data-groupby = '"+localStorage_obj.group_by+"']").addClass('active');
		},
		setFilterData: function(data){
			var templateData;
			var group_data = jQuery("[data-filterkey='group_id']").children("option:selected").map(function(){
					return jQuery(this).text();
			});
			var agent_data = jQuery("[data-filterkey='responder_id']").children("option:selected").map(function(){
					return jQuery(this).text();
			});
			var agentfilterlabel = jQuery('.agent_text').text();
			var groupfilterlabel = jQuery('.group_text').text();
			var all = I18n.t('helpdesk.realtime_dashboard.all')
			if(group_data.length <= 0 && agent_data.length <= 0){
				templateData = {
					"agentfilter" : [all], 
					"groupfilter" : [all],
					"agentfilterlabel" : agentfilterlabel,
					"groupfilterlabel" : groupfilterlabel
				};
			}else{	
				var group_filter = ((group_data.length !== 0) ? group_data : [all]);
				var agent_filter = ((agent_data.length !== 0) ? agent_data : [all]);
				templateData = {
					"agentfilter" : agent_filter, 
					"groupfilter" : group_filter,
					"agentfilterlabel" : agentfilterlabel,
					"groupfilterlabel" : groupfilterlabel
				};
			}
			
			var templatedata  = jQuery.tmpl(jQuery("#filter-data-template").template(), templateData);
			jQuery("#filter_text").html(templatedata);
			
		},
		saveFilterData: function(data){
			if (typeof (Storage) !== "undefined") {
				window.localStorage.setItem('unresolved-tickets-filters', Browser.stringify(data));
			}
		},
		columnDefs_des: function(data, lastRow){
			var selectedTab = jQuery("#unresolved-tab li.active").data('redirect');
			return data.tickets_data.data.map(function(val, i){
				return {
					"render": function ( data, type, row ) {
						var _data;
						if(i === 0) {
							var _store = DataStore.get(selectedTab),
							_data = jQuery.capitalize(data);
							if(_store.findById(data)['name']){
								_data = _store.findById(data)['name'];
							}	
						} else if(i === row.length - lastRow) {
							_data = data;
						} else {	
							var data_url = "<a data-id="+(row[0])+" data-status="+status_filtered_array[i][0]+" href='javascript:void(0)'>"+data+"</a>";
							_data = (data === 0) ? data : data_url;
						}
						return _data;
					},
					"targets": i
				};
			});
		},
		tableDrawCallback: function(dataLength){
			if(jQuery('#unresolved-tickets tbody .dataTables_empty').length === 1){
				jQuery(".DTFC_ScrollWrapper, .dataTables_paginate, .standard-table").hide();
				jQuery(".no-data-section h4").text(no_data);
				if(jQuery(".no-data-section i").hasClass("ficon-went-wrong")){
					jQuery(".no-data-section i").removeClass("ficon-went-wrong").addClass("ficon-no-data");
				}
				jQuery(".no-data-section").show();
			}else{
				jQuery(".DTFC_ScrollWrapper, .dataTables_paginate, .standard-table").show();
				jQuery(".no-data-section").hide();
			}
			if(dataLength <= CONST.visibleRow){
				jQuery(".dataTables_paginate").hide();
			}else{
				jQuery(".dataTables_paginate").show();
			}
			if(jQuery.browser.msie){
				var currentHeight = jQuery(".DTFC_LeftBodyLiner").height();
				setTimeout(function(){
					jQuery(".DTFC_LeftBodyWrapper , .DTFC_LeftBodyLiner").height(currentHeight + 15);
					jQuery(".DTFC_RightBodyWrapper , .DTFC_RightBodyLiner").height(currentHeight + 15);
				}, 10);	
			}
		},
		constructStandardTable: function(data){
			_FD.destroyTable();
			var columnWidth = parseInt(CONST.dynamicWidth + 60 / CONST.visibleColumn);
			var column_titles = data.tickets_data.data.map(function(val, i) {
					return {
						'sWidth': (i === 0) ? "15%" : columnWidth+"px",
						'sTitle': val,
						'sClass': "center",
						"asSorting": [ "desc", "asc" ]
					};
			});
			columnDefs_des = _FD.columnDefs_des(data, 1);
			var unresolved_ticket = jQuery('#unresolved-tickets').dataTable({	
				"sDom": 'f<"standard-table"t>p',
				"bAutoWidth": false,
				"aaData": data.tickets_data.content,
				"aoColumns": column_titles,
				"columnDefs" : columnDefs_des,
				"paging": true,
				"bInfo": false,
				"bLengthChange" :false,
				"aaSorting": [],
				"iDisplayLength" : CONST.visibleRow,
				"oLanguage": {
					"oPaginate": {
						"sNext": ">",
						"sPrevious": "<"
					},
					"sSearch": '<i class="ficon-search"></i>',
					"sSearchPlaceholder": I18n.t('helpdesk.realtime_dashboard.search')
                },
                "fnDrawCallback" : function(){
                	_FD.tableDrawCallback(data.tickets_data.content.length);
                }
			});
		},
		constructTable: function(data){
			_FD.destroyTable();
			var arrowtemplate = '<div class="next-set-data"><span class="agent-details-prev show-metrics disabled"><i class="ficon-arrow-left fsize-14 " size="14"></i></span><span class="agent-details-next show-metrics"><i class="ficon-arrow-right fsize-14 " size="14"></i></span></div>';
			var finalData = data.tickets_data.content.each(function(val, key){
				val.push("");			
			});
			var columnWidth = parseInt(CONST.calculatedWidth / CONST.visibleColumn);
			var column_titles = data.tickets_data.data.map(function(val, i) {
				return {
					'sWidth': (i === 0) ? "150px" : columnWidth+"px",
					'sTitle': val,
					'sClass': "center",
					"asSorting": [ "desc", "asc" ]
				};
			});
			column_titles.push({
					'sWidth': '60px',
					'sTitle': arrowtemplate,
					'sClass': "center"
			});
			var columnDefs_des = _FD.columnDefs_des(data, 2);

			columnDefs_des.push({
				"targets": data.tickets_data.data.length,
				"bSortable": false
			});
		
			var unresolved_ticket = jQuery('#unresolved-tickets').dataTable({
				"bAutoWidth": false,
				"aaData": data.tickets_data.content,
				"aoColumns": column_titles,
				"columnDefs" : columnDefs_des,
				"paging": true,
				"bInfo": false,
				"bLengthChange" :false,
				"sScrollX": "100%",   
				"sScrollXInner": "200%",
				"aaSorting": [],
				"iDisplayLength" : CONST.visibleRow,
				"fixedColumns":   {
					leftColumns: 1,
					rightColumns: 1
        		},
				"oLanguage": {
					"oPaginate": {
						"sNext": ">",
						"sPrevious": "<"
					},
					"sSearch": '<i class="ficon-search"></i>',
					"sSearchPlaceholder": "Search"
                },
                "fnDrawCallback" : function(){
                	_FD.tableDrawCallback(data.tickets_data.content.length);
                }
			});
			var translateTable = function(datatable_body,current_scroll_position,max_scroll_left,left_nav_btn,right_nav_btn){
				jQuery(datatable_body).animate({ scrollLeft : current_scroll_position } , 500,function(){
				if(current_scroll_position === 0){
					jQuery(left_nav_btn).addClass('disabled');
					jQuery(right_nav_btn).removeClass('disabled');
					jQuery(".DTFC_RightBodyWrapper").addClass('shadow');
					jQuery(".DTFC_LeftBodyWrapper").removeClass('shadow');
				} else if (current_scroll_position == max_scroll_left){
					jQuery(right_nav_btn).addClass('disabled');
					jQuery(left_nav_btn).removeClass('disabled');
					jQuery(".DTFC_RightBodyWrapper").removeClass('shadow');
					jQuery(".DTFC_LeftBodyWrapper").addClass('shadow');
				} else{
					jQuery(right_nav_btn).removeClass('disabled');
					jQuery(left_nav_btn).removeClass('disabled');
					jQuery(".DTFC_RightBodyWrapper").addClass('shadow');
					jQuery(".DTFC_LeftBodyWrapper").addClass('shadow');
				}           
				});
			};

			var datatable_body = jQuery(".dataTables_scrollBody");
			var left_nav_btn = jQuery(".agent-details-prev");
			var right_nav_btn = jQuery(".agent-details-next");
			var table = jQuery(".dataTables_scrollBody")[0];
			max_scroll_left = table.scrollWidth - table.clientWidth;
			//bind scroll events
			current_scroll_position = 0;
			jQuery(left_nav_btn).click(function(e){
				e.preventDefault();
				e.stopImmediatePropagation();
				if(current_scroll_position !== 0){
					var move_x = current_scroll_position - ((CONST.calculatedWidth / CONST.visibleColumn) * 4);
				if( move_x < 0){
					current_scroll_position = 0;
				}else{
					current_scroll_position = move_x;
				} 
				}
				translateTable(datatable_body,current_scroll_position,max_scroll_left,left_nav_btn,right_nav_btn);                        
			});

			jQuery(right_nav_btn).click(function(e){
				e.preventDefault();
				e.stopImmediatePropagation();
				if(current_scroll_position != max_scroll_left){
					var move_x = current_scroll_position + ((CONST.calculatedWidth / CONST.visibleColumn) * 4);
				if( move_x > max_scroll_left){
					current_scroll_position = max_scroll_left;
				}else{
					current_scroll_position = move_x;
				} 
				}
				translateTable(datatable_body,current_scroll_position,max_scroll_left,left_nav_btn,right_nav_btn);
			});
		}
	};
	return {
		init: function(param){
			if(shared_ownership_enabled){
				_FD.setFilterText();
			}
			_FD.setFilterData(param);
			_FD.saveFilterData(param);
			_FD.triggerAjax(param);
			_FD.events();
		},
		hasLocalData: function(localStorage_obj){
			_FD.events();
			//var localStorage_obj = JSON.parse(window.localStorage.getItem('unresolved-tickets-filters'));
			jQuery("#unresolved-tab li").removeClass('active');
			if(shared_ownership_enabled){
				_FD.setFilterText();	
			}
			_FD.retainFilters(localStorage_obj);

			if("responder_id" in localStorage_obj){
				_FD.handleFilterSelection("responder_id", "agent_text", "agentSort");
				if(localStorage_obj.responder_id.split(",").length !== 0)
					jQuery("[data-filterkey = 'responder_id']").val(localStorage_obj.responder_id.split(",")).trigger('change');
			}
			if("internal_agent_id" in localStorage_obj){
				_FD.handleFilterSelection("internal_agent_id", "agent_text", "agentSort");
				if(localStorage_obj.internal_agent_id.split(",").length !== 0)
					jQuery("[data-filterkey = 'responder_id']").val(localStorage_obj.internal_agent_id.split(",")).trigger('change');
			}

			if("group_id" in localStorage_obj){
				_FD.handleFilterSelection("group_id", "group_text", "groupSort");
				if(localStorage_obj.group_id.split(",").length !== 0)
					jQuery("[data-filterkey = 'group_id']").val(localStorage_obj.group_id.split(",")).trigger('change');
			} 
			if("internal_group_id" in localStorage_obj){
				_FD.handleFilterSelection("internal_group_id", "group_text", "groupSort");
				if(localStorage_obj.internal_group_id.split(",").length !== 0)
					jQuery("[data-filterkey = 'group_id']").val(localStorage_obj.internal_group_id.split(",")).trigger('change');
			}			
			_FD.setFilterData(localStorage_obj);
			_FD.triggerAjax(localStorage_obj);
		},
		showLoader: function(loaderType){
			_FD.showLoader(loaderType);
		},
		unbindEvents: function(){
			_FD.unbindEvents();
		}
	};
})();