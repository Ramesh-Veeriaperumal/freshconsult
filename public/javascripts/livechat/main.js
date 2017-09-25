(function(){
	"use strict";
	window.showLoaderPage = function(){
		jQuery("#loading-box").show(); 
		jQuery("#livechat_archive_page").css('opacity','0'); 
		jQuery("#loading-box").css('background','transparent'); 
	};

	window.removeLoaderPage = function(){
		jQuery("#loading-box").hide(); 
		jQuery("#livechat_archive_page").css('opacity','1'); 
	};

	jQuery(document).ready(function() {

		/* In Multiple select drop down list, when the user clicks "All" , all other selected options should be removed.
		 * Similarly, If the user selects any other option, "All" option should be removed
		 */
		jQuery('#widget_filter,#agent_filter').on('change',function(event){
			if(event.added && event.added.id === "0"){
				jQuery(event.target).select2("val",["0"]);
			}else if(event.added && event.added.id !== "0"){
				var targetValues = jQuery(event.target).val();
				var filteredValues = _.filter(targetValues,function(value){
					return value !== "0";
				});
				jQuery(event.target).select2("val",filteredValues);
			}
		});
		

		 jQuery("#date_range").bind('keypress keyup keydown', function(ev) {
		   	ev.preventDefault();
		    return false;
		 });

		 // If filter is open and the user clicks any other element under div#report-page , it is hidden.
		 jQuery("#report-page").on('click',function(event){
		 	if(jQuery("#report-filter-edit").css('visibility') === 'visible' && event.target.id !== "sliding"){
			 	jQuery('#sliding').click();
			}
		 });

		 // export
		bindExport();
		showLoaderPage();
	});
	// There is conflict between pjax and backbone routing. So once pjax is loaded. we are stopping backbone routing
	// and removing all references.
	jQuery('#body-container').one("pjax:beforeReplace",function(event,options,tool){
		if(Backbone.History.started === true){
			window.archiveRouter.destroyAll();
			window.archiveRouter = null;
			
		}

	});
	/*	When the user navigates from archive page to any other PJAX based page and come backs again to archive page
	 *  with Back button, the current history state is changed to null.
	 */
	var pjaxCallback = function(event,xhr,options){
		if(options && options.url && options.url.match(/\/livechat\//gi)){
			jQuery.pjax.state = null
			window.history.replaceState(null,"");			
		}
	};
	
	jQuery(document).one('pjax:end',pjaxCallback);	

	var changeFilterHeader = function(filterName){
		var newFilterName = {};
            _.each(filterName,function(value,key){
                newFilterName[key] = _.escape(value);
            });
		// Keyword and Visitor ID can be empty. So using condition inside array
		var filterData = ["<li>Filter by:</li>",
					(newFilterName.keyword === undefined) ? null : "<li> Keyword: <strong>"+newFilterName.keyword+"</strong></li>",
			            "<li>Time Period: <strong>"+newFilterName.timePeriod+"</strong></li>",
			            "<li>Chat Type : <strong>"+newFilterName.type+"</strong></li>",
			            "<li>Widget: <strong>"+ newFilterName.widget+"</strong></li>",
			            "<li>Agent: <strong>"+newFilterName.agent+"</strong></li>",
			            (newFilterName.visitorId === undefined) ? null : "<li> Visitor ID: <strong>"+newFilterName.visitorId+"</strong></li>"
			            ].join("");

		jQuery("#filter_container").html(filterData);		  
		jQuery("#report_header_date").html(newFilterName.date);          
	};
	// Triggered when the user clicks cancel button
	jQuery("#cancel").on('click',function(){
	      jQuery('#sliding').click();
	});

  	//add the link which fire event on close button.
	jQuery("#filter-close-icon").on('click',function(){
		jQuery("#cancel").click();
	});
 	// Triggered when the user clicks submit button
 	jQuery("#submit").click(function(ev){
 		jQuery('#sliding').click();
 		getFilterValues(function(filterName, filterVal){
 			changeFilterHeader(filterName);
	 		if(window.archiveRouter){
	 			window.archiveRouter.archiveCollection.setFilter(filterVal);
	 			window.archiveRouter.archiveCollection.loadHomePage();
	 		}	
	 		checkAndHideExportButton(filterVal.type);
 		});
  	});	
	// Triggered when the user changes sorting
	jQuery('#sorting-filter').on('click',function(event){
		var $targetElement = jQuery(event.target);
		var type = $targetElement.data().sortType;
		var text = $targetElement.html();
		var filter = {
			sort : type
		};
		if(window.archiveRouter){
 			window.archiveRouter.archiveCollection.addFilter(filter);
 			window.archiveRouter.archiveCollection.loadHomePage();
 		}
		jQuery('#sorting-filter-head').html("<b>Sort Order</b> "+text).data('sortType',type);
	});

	var setVisitorPageNavigationEvents = function(routerInstance){
		jQuery("#returnVisitorCount").off('click').on('click',function(){
			routerInstance.navigate("/visitor/returnVisitor",{trigger : true});
		});
		jQuery("#newVisitorCount").off('click').on('click',function(){
			routerInstance.navigate("/visitor/newVisitor",{trigger : true});
		});
		jQuery("#inConversationCount").off('click').on('click',function(){
			routerInstance.navigate("/visitor/inConversation",{trigger : true});
		});
	};

	var chatLoadedCallback = function(archiveCollection, visitorCollection){

		/* While the page loads, the filter will be visible. To hide it.	
		 */
		if(jQuery("#report-filter-edit").css('visibility') === 'visible'){
		 	jQuery('#sliding').slide();
			jQuery('#report-page').hide();
		 	
		}
		var archiveRouter = window.liveChat.archiveRouter();
		var archiveView = window.liveChat.archiveView();
		var conversationView = window.liveChat.conversationView();
		var routerInstance = new archiveRouter({
			archiveCollection : archiveCollection,
			archiveView : archiveView,
			conversationView : conversationView,
			visitorListView : window.liveChat.visitorListView(),
			_visitorCollection : visitorCollection
		});

		//set navigation for visitor filter
		setVisitorPageNavigationEvents(routerInstance);

		if(Backbone.History.started === true){
			Backbone.history.stopListening();
			Backbone.history.stop();
		}

		Backbone.history.start({root:'/livechat',pushState: true});
		Backbone.emulateJSON = true;

		// Removing functions from global space 
		window.liveChat.archiveRouter = null;
		window.liveChat.archiveView = null;
		window.liveChat.conversationView = null;
				
	};
	/* There are two cases in loading chat archive. 1. through pjax 2. Full Page Loading.
	  *  If it is loaded through pjax, archive Collection will be available in window
	*/
	if(window.freshChat && window.freshChat.archiveCollection){
		chatLoadedCallback(window.freshChat.archiveCollection, window.freshChat.visitorCollection);
	}else{
		jQuery(document).on('chatLoaded',function(){
			chatLoadedCallback(window.freshChat.archiveCollection, window.freshChat.visitorCollection);
			jQuery(document).off('chatLoaded');
		});
	}

    var getFilterValues = function(callback){
    	var $filterForm = jQuery('#archive_filter');
 		var filterVal = {};
 		var filterName = {};

 		//Keyword 
 		var keyword = $filterForm.find('#filter_keyword').val();
 		if(keyword){
 			filterVal.keyword = keyword;
 			filterName.keyword = keyword;
 		}
 		// Widget
 		var widgetData = $filterForm.find('#widget_filter').select2('data');
 		if(widgetData.length === 0 ){
 			filterVal.widgetId = 0;
 			filterName.widget = "All";
 		}else{
 			filterVal.widgetId = _.pluck(widgetData,"id").join(',');
 			filterName.widget = _.pluck(widgetData,"text").join(',');
 		}

 		//Time Period 
 		var timePeriod = $filterForm.find("#date_range").val();
 		if(timePeriod){
 			// var accountTimeZoneOffsetInMin = parseInt(jQuery('#livechat_archive_page').attr("data-time-zone-offset"));
	 		// var currentTimeZoneOffetInMin = new Date().getTimezoneOffset();
	 		// var newOffsetInMin = accountTimeZoneOffsetInMin + currentTimeZoneOffetInMin;
			filterName.timePeriod = timePeriod;
			var fromDate = timePeriod.split('-')[0];
			var	toDate;
			if(timePeriod.split('-')[1]){
				toDate = timePeriod.split('-')[1];
			}else{
				filterVal.isOneDayFilter = true; 
				toDate = timePeriod.split('-')[0];
			}
			var frm = new Date(fromDate);
			frm.setHours(0, 0, 0, 0);
			var to = new Date(toDate);
			to.setHours(23, 59, 59, 999);

			// getting actual range for mail subject and content
			var actualFromMonth = frm.toString().split(" ")[1];
			var actualToMonth = to.toString().split(" ")[1];
			var actualFrm = frm.getDate() + ' '+ actualFromMonth + ', ' + frm.getFullYear();
			var actualTo = to.getDate() + ' '+ actualToMonth + ', ' + to.getFullYear(); 
			filterVal.actualRange = filterVal.isOneDayFilter ? actualFrm : actualFrm + ' - ' + actualTo;
			filterVal.frm = frm.toUTCString();
			filterVal.to = to.toUTCString(); 
			// var newFrom = new Date();
			// var newTo = new Date();
			// filterVal.frm = newFrom.setTime(frm.getTime() + (newOffsetInMin * 60 * 1000));
			// filterVal.to = newTo.setTime(to.getTime() + (newOffsetInMin * 60 * 1000));
 		}

 		//Agent 
 		var agentData = $filterForm.find('#agent_filter').select2('data');
 		if(agentData.length === 0 ){
 			filterVal.agentId = 0;
 			filterName.agent = "All";
 		}else{
 			filterVal.agentId = _.pluck(agentData,"id").join(',');
 			filterName.agent = _.pluck(agentData,"text").join(',');
 		}

 		//Chat Type 
 		var $chatType = $filterForm.find('#type_filter :selected');
 		filterVal.type = $chatType.val();
 		filterName.type = $chatType.html();

 		//Visitor ID 
 		var visitorId = $filterForm.find('#visitor_id').val();
 		if(visitorId){
 			filterVal.visitorId = visitorId;
 			filterName.visitorId = visitorId;
 		}

 		//Specific Agent to Agent Chats
 		var agentIds = $filterForm.find('#agent_ids').val();
 		if(agentIds){
 			filterVal.agentIds = agentIds;
 			filterVal.type = "4";
 		}

 		//Sorting Filter 
 		filterVal.sort = jQuery('#sorting-filter-head').data('sortType');
 		callback && callback(filterName, filterVal);
    };

	// Chat Archive Export

	var checkAndHideExportButton = function(type){
		var exportElement = jQuery('.chat_archive_export');
		if(type == '4' || type == '6'){  // 4 - agent to agent chat / 6 - spam chat
			exportElement.hide();
		}else{
			exportElement.show();
		}
	};

	var showExportAlerts = function(message) {
      jQuery("#noticeajax").html("<div>" + message + "</div>").show();
      setTimeout(function() {closeableFlash('#noticeajax');}, 3000);
    };

    var validateExportDateRange = function(fromDate){
    	if(!fromDate) return false;
    	fromDate = new Date(fromDate);
    	var dateLimit = jQuery('.chat_archive_export').attr("data-export-date-limit");
    	fromDate.setMonth(fromDate.getMonth() + parseInt(dateLimit));
	   	return (new Date() < fromDate);
    };

    var showProgress = function(progress) {
      	if (progress === undefined) { progress = 0 };
      	if (progress >= 1.0) { return; }
      	NProgress.set(progress);
      	showProgress(progress + 0.2);
    };

    var cleanupLoader = function() {
      	NProgress.done();
      	setTimeout(NProgress.remove, 500);
    };

    var bindExport = function () {
      var self = this;
      var $export_div = jQuery('.chat_archive_export');
      jQuery('#livechat_archive_page').on("click.export_button",".export_option",
        function(ev) {
			var format = jQuery(ev.target).attr('data-format');
			ev.preventDefault();
			showProgress();
			getFilterValues(function(filterName, filterVal){
				if(validateExportDateRange(filterVal.frm)){
					var data = { filters: filterVal };
					data.format = format;
					jQuery.ajax({
					    url   : '/livechat/export',
					    type  : "GET",
					    data  : data,
					    success : function( result, status, xhr ) {
							cleanupLoader();			
							showExportAlerts($export_div.attr("data-success-message"));
					    },
					    error : function( xhr, status, error ){
							cleanupLoader();
							showExportAlerts($export_div.attr("data-error-message"));
					    }
					});
				}else{
					cleanupLoader();
					showExportAlerts($export_div.attr("data-range-limit-message"));
				}
			});
        });
    };

})();