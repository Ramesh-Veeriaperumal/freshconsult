!function($){

	"use strict"

	if(window['SearchResults']){ 
		return true; 
	}

	window.App.Search = {
		onFirstVisit: function() {},
		onVisit: function() {},
		onLeave: function() {
			if(window['search_page'] != undefined) {
				window['search_page'].destroy();	
			}
		},
	}

	window.SearchResults = Class.create();

	SearchResults.prototype = {
		BULK_ACTION_LIMIT : 30,
		initialize: function(){
			this.searchedTicketIds = []
			this.container = jQuery('#search-page-results')
			this.bindEvents()
			this.stickyHeader();
			NavSearchUtils.saveToLocalRecentSearches(jQuery('.search-input').val().trim());

		},
		namespace: function(){
			return '.search_results';
		},
		searchResultsData: function(){
			return window.SEARCH_RESULTS_PAGE.data;
		},
		pjaxifyUrl: function(ev){
			ev.preventDefault();
    		NavSearchUtils.saveToLocalRecentSearches(jQuery('.search-input').val());			
			var searchKey = encodeURIComponent(jQuery('.search-input').val());
			var url = jQuery('.search-form').attr('action')+'?term='+searchKey;
			pjaxify(url);
		},
		setActiveTab: function(){
			jQuery('.search-sorting-wrapper .nav-tabs li').removeClass('active');
		},
		processAndRenderResults: function(){
			var resultHtml = ""
			var data = this.searchResultsData()
			var $this = this
			for(var i=0;i<data.results.length;i++)
			{
				var result = data.results[i];
				if(result){
					var resultType = result.result_type,
						templateName = ["app/search/templates/", resultType].join("");
					if ((resultType == "helpdesk_ticket") || (resultType == "helpdesk_note")){
						var idKey = (resultType == "helpdesk_ticket") ? "id" : "notable_id";
						var ticketId = parseInt(result[idKey]); 
						//if(jQuery.inArray(ticketId, $this.searchedTicketIds) < 0){
							resultHtml += (JST[templateName](result));
							//$this.searchedTicketIds.push(ticketId);
						//}
					}
					else {
						resultHtml += (JST[templateName](result));
					}
				}
			}
			this.container.append(resultHtml);
		},
		afterComplete: function() {
			if(SEARCH_RESULTS_PAGE.is_tickets_page) {
				var total_pages  = SEARCH_RESULTS_PAGE.data.total_pages;
				var current_page = SEARCH_RESULTS_PAGE.data.current_page;
				if(total_pages > current_page) {
					jQuery('.loadmore-wrap').removeClass('hide');
				} else {
					jQuery('.loadmore-wrap').addClass('hide');
				}
			} else {
				jQuery('#load-more').button('reset');
				var loadmore = this.container.data('loadMore');
				if(loadmore != undefined && loadmore.opts != undefined) {
					loadmore.opts.currentPage = this.searchResultsData().current_page;
				}
			}
		},
		destroy: function(){
			jQuery('body').off(this.namespace());
			this.searchedTicketIds = [];
		},
		asyncRender: function(){
			  var $all_checked = jQuery('.selection input[type="checkbox"][selectable="true"]:checked');
			  var $all_unchecked = jQuery('.selection input[type="checkbox"][selectable="true"]:unchecked');
			if(this.searchResultsData().results.length){
				window.search_page.processAndRenderResults();
				window.search_page.afterComplete();
			}

			if($all_checked.length < this.BULK_ACTION_LIMIT) {
				$all_unchecked.removeAttr('disabled');	
				$all_unchecked.parent().each(function(i,item){
					jQuery(item).attr('data-original-title','');	
					var twipsy = jQuery(item).data('twipsy');
			    	if(twipsy != undefined) {
			   			twipsy.setContent();
			   		}
				});
			} else {
				$all_unchecked.attr('disabled',true);
				$all_unchecked.parent().each(function(i,item){
					jQuery(item).attr('data-original-title','you have selected max number of tickets');	
					var twipsy = jQuery(item).data('twipsy');
			    	if(twipsy != undefined) {
			   			twipsy.setContent();
			   		}
				});
			}		
		},
		bindEvents : function() {
			var _this = this;
			jQuery('body').on('submit'+_this.namespace(), '.search-form', function(ev){ _this.pjaxifyUrl(ev) });
			jQuery('body').on('click'+_this.namespace(), '.search-sorting-wrapper .nav-tabs li', function(){ 
				_this.setActiveTab() 
			});

			jQuery('#result-wrapper').on('change','.selection input[type="checkbox"]',function(){
				_this.verify_selection_limit();
			});	

			jQuery('#result-wrapper').on('change','.selection input[type="checkbox"]',function(){
				if(this.checked){
					jQuery(this).parents('li[rel=searched-tickets]').addClass('selected_');
				} else {
					jQuery(this).parents('li[rel=searched-tickets]').removeClass('selected_');
				}
			});

			jQuery(window).on('scroll',function(){
				var $all_tooltips = jQuery('.search-list-wrap .tooltip');
				$all_tooltips.each(function(idx,el){
					var tooltip = jQuery(el).data('twipsy');
					if(tooltip != undefined) {
						tooltip.hide();
					}
				});
			});

			var checkboxStore = null;
			jQuery(document).on('click', '.selection input[type="checkbox"]',function(e){
				var $checkboxes = jQuery('.selection input[type="checkbox"][selectable="true"]');
				
				// Add selection border on click
			    var index = jQuery(e.target).parent().parent().parent().index();
			    jQuery('#search-page-results').data('menuSelector').setCurrentElement(index);

				if(!checkboxStore) {
					checkboxStore = e.target;
					return;
				}
				if(e.shiftKey) {
					var end = $checkboxes.index(e.target);
					var start = $checkboxes.index(checkboxStore);
					var selected_set = $checkboxes.slice(Math.min(start,end), Math.max(start,end));
					$checkboxes.slice(Math.min(start,end), Math.max(start,end)+ 1).prop('checked', e.target.checked).change();
					
					var total_checked = jQuery('.selection input[type="checkbox"][selectable="true"]:checked').length;
					if(total_checked > _this.BULK_ACTION_LIMIT) {
						$checkboxes.slice(Math.min(start,end), Math.max(start,end)+ 1).prop('checked', false).change();
					}
				}
				checkboxStore = e.target;
			});
		},
		stickyHeader : function(){
			var scroll_top = $("#sticky_header").data('scrollTop');
			$("#sticky_header").sticky({
				elm_bottom : true
			});
			$("#sticky_header").on("sticky_kit:stick", function(e){
				if(scroll_top){
					if(!$('#scroll-to-top').length){
						$(this).append("<i id='scroll-to-top'></i>")
					}
					$('#scroll-to-top').addClass('visible');
				}
			})
			.on("sticky_kit:unstick", function(e){
				if(scroll_top){$('#scroll-to-top').removeClass('visible');}
			});
		},
		verify_selection_limit : function() {

			var $all_checked = jQuery('.selection input[type="checkbox"][selectable="true"]:checked');
			var $all_unchecked = jQuery('.selection input[type="checkbox"][selectable="true"]:unchecked');

			if($all_checked.length >= 1) {
				jQuery('.bulk-action-pane').removeClass('hide');
				jQuery('.search-filter-pane').addClass('hide');
			} else {
				jQuery('.bulk-action-pane').addClass('hide');
				jQuery('.search-filter-pane').removeClass('hide');
			}

			if($all_checked.length < this.BULK_ACTION_LIMIT) {
				$all_unchecked.removeAttr('disabled');	
				$all_unchecked.parent().each(function(i,item){
					jQuery(item).attr('data-original-title','');	
					var twipsy = jQuery(item).data('twipsy');
			    	if(twipsy != undefined) {
			   			twipsy.setContent();
			   		}
				});
			} else {
				$all_unchecked.attr('disabled',true);
				$all_unchecked.parent().each(function(i,item){
					jQuery(item).attr('data-original-title','you have selected max number of tickets');	
					var twipsy = jQuery(item).data('twipsy');
			    	if(twipsy != undefined) {
			   			twipsy.setContent();
			   		}
				});
			}		
		},
		renderFilterResults : function(is_load_more) {
			if(!is_load_more){
				this.container.html('');	
			}
			this.processAndRenderResults();
			this.afterComplete();
		},
		loadMoreRender: function(data){
			SEARCH_RESULTS_PAGE.data = data;
			this.processAndRenderResults();
			this.afterComplete();
			this.bindEvents();
		}
	}
}(window.jQuery);
