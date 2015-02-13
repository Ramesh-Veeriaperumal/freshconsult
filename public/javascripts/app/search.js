!function($){

	"use strict"

	if(window['SearchResults']){ 
		return true; 
	}

	window.App.Search = {
		onFirstVisit: function() {},
		onVisit: function() {},
		onLeave: function() {
			window['search_page'].destroy();
		},
	}

	window.SearchResults = Class.create();

	SearchResults.prototype = {
		initialize: function(){
			this.searchedTicketIds = []
			this.container = jQuery('#search-page-results')
			this.bindEvents()
		},
		namespace: function(){
			return '.search_results';
		},
		searchResultsData: function(){
			return window.SEARCH_RESULTS_PAGE.data;
		},
		bindEvents: function(){
			var $this = this;
			jQuery('body').on('submit'+$this.namespace(), '.search-form', function(ev){ $this.pjaxifyUrl(ev) });
			jQuery('body').on('click'+$this.namespace(), '.search-sorting-wrapper .nav-tabs li', function(){ 
				$this.setActiveTab() 
			});
		},
		pjaxifyUrl: function(ev){
			ev.preventDefault();
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
					var resultType = result.result_type
					if ((resultType == "helpdesk_ticket") || (resultType == "helpdesk_note")){
						var idKey = (resultType == "helpdesk_ticket") ? "id" : "notable_id";
						var ticketId = parseInt(result[idKey]); 
						if(jQuery.inArray(ticketId, $this.searchedTicketIds) < 0){
							resultHtml += (JST[resultType](result));
							$this.searchedTicketIds.push(ticketId);
						}
					}
					else {
						resultHtml += (JST[resultType](result));
					}
				}
			}
			this.container.append(resultHtml);
		},
		afterComplete: function(){
			jQuery('#load-more').button('reset');
			var loadmore = this.container.data('loadMore');
			loadmore.opts.currentPage = this.searchResultsData().current_page;
		},
		destroy: function(){
			jQuery('body').off(this.namespace());
			this.searchedTicketIds = [];
		},
		asyncRender: function(){
			if(this.searchResultsData().results.length){
				window.search_page.processAndRenderResults();
			}
		},
		loadMoreRender: function(data){
			SEARCH_RESULTS_PAGE.data = data;
			this.processAndRenderResults();
			this.afterComplete();
		}
	}
}(window.jQuery);