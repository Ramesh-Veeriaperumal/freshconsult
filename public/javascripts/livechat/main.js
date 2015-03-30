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

	var changeFilterHeader = function($filterElem,filterName){
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
 			filterName.timePeriod = timePeriod;
 			filterVal.frm = timePeriod.split('-')[0];
 			filterVal.to  = timePeriod.split('-')[1];
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

 		//Sorting Filter 
 		filterVal.sort = jQuery('#sorting-filter-head').data('sortType');

 		changeFilterHeader($filterForm,filterName);

 		if(window.archiveRouter){
 			window.archiveRouter.archiveCollection.setFilter(filterVal);
 			window.archiveRouter.archiveCollection.loadHomePage();
 		}
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
})();





