jQuery(document).ready(function(){
	var currentactive,	  
	position   		= -1, 
	insideSearch 	= false,
	focusedOnSearch = true,
	currentString = "",
	fullSearchString = "";	
	NavSearchUtils.localRecentSearches = NavSearchUtils.getLocalRecentSearches(NavSearchUtils.localRecentSearchKey);
	NavSearchUtils.localRecentTickets = NavSearchUtils.getLocalRecentTickets(NavSearchUtils.localRecentTicketKey);

	callbackToSearch = function(string, search_url){
		jQuery('#SearchBar').addClass('sloading loading-small loading-right');
		jQuery('.results').hide().find('li.spotlight_result').remove();
  	    jQuery.ajax({ url: search_url+string,
  	    				dataType: 'json', 
						success: function(data){
							if(string == encodeURIComponent($("header_search").value)) {
								jQuery("#SearchResultsBar").css("display", "inline"); 
								position   = -1;
								appendResults(data);
                			}
							jQuery('#SearchBar').removeClass('sloading loading-small loading-right');    
						}});
    }

    appendResults = function(data){
    	var resultHtml = {}
    	var search_results = data.results
    	if(search_results.length == 0){
    		jQuery('.results_info').html('<li class="spotlight_result"><div>'+data.no_results_text+'</div></li>');
    	}
    	for(i=0; i<15; i++){
    		var result = search_results[i];
    		if(result){
    			var result_type = result.result_type
    			resultHtml[result_type] = (typeof(resultHtml[result_type]) == "undefined" ? "" : resultHtml[result_type] ) + 
									    	JST["app/search/templates/spotlight_result"](result)
    		}
		}
    	
    	for(var key in resultHtml){
    		jQuery('#SearchResultsBar .'+key+'_results').append(resultHtml[key]);
    	}
    	if(data.more_results_text || search_results.length > 30){ 
    		var more_results_html = '<a href="/search/all?term='+data.term+'">'+data.more_results_text+'</a>'
    		jQuery('.results_info').html('<li class="spotlight_result">'+more_results_html+'</li>');
    	}
    	jQuery("ul.results").filter(function(){return jQuery(this).find('li.spotlight_result').length > 0; }).show();

    	jQuery('ul.results').on('click.add_to_recent_search', 'li.spotlight_result a' , function(ev){
    		NavSearchUtils.saveToLocalRecentSearches(fullSearchString);
    	});

    }

    var handleFullSearch = function() {
      var searchKey = encodeURIComponent(jQuery('#header_search').val());
      var url = jQuery('.nav_search').attr('action')+'?term='+searchKey;
      window.pjaxify(url);
    }
		
	var hideSearchBar = function() {
		$J("#SearchResultsBar").hide();
		$J("#SearchBar").removeClass("active");
		$J("#header_search").attr("placeholder", "");
		//reset search bar by removing search query
		//and removing appended search results
		$J('#header_search').val('');
		$J('ul.results li.spotlight_result').remove();
		jQuery("ul.results").filter(function(){return jQuery(this).find('li.spotlight_result').length == 0; }).hide();
	}

	$J("#SearchResultsBar a").die('hover');
	$J("#SearchResultsBar a").live({
		hover: function(){
			$J(currentactive).removeClass("active");
			currentactive = $J(this).addClass("active");
		},
		click: function(){
			hideSearchBar();
		}
	});
			
	$J("#SearchResultsBar").live({
		mouseenter:
		   function()
		   {
		   	focusedOnSearch = false
		   	insideSearch = true;
		   },
		mouseleave:
		   function()
		   {
		   	insideSearch = false;
		   }
	});
			
	$J("#header_search").bind("focusout", function(ev){ 
		focusedOnSearch = false;
		if(!insideSearch){
			hideSearchBar();					
		}
	});
			
	$J("#header_search").bind("focusin", function(ev){
		focusedOnSearch = true;
		searchString = this.value.replace(/^\s+|\s+$/g, "");
		$J("#SearchBar").addClass("active");
		$J("#header_search").attr("placeholder", "Search");
		$J('#SearchBar').twipsy('hide');
		NavSearchUtils.localRecentSearches = NavSearchUtils.getLocalRecentSearches(NavSearchUtils.localRecentSearchKey);
		NavSearchUtils.localRecentTickets = NavSearchUtils.getLocalRecentTickets(NavSearchUtils.localRecentTicketKey);
		if(NavSearchUtils.localRecentSearches || NavSearchUtils.localRecentTickets){
			if(NavSearchUtils.localRecentSearches.length > 0){				
				jQuery('.recent_searches_li').remove();
				// Show most recent search to least recent
				for(var j = NavSearchUtils.localRecentSearches.length - 1; j > -1; j--){
					var searchItem = JST["app/search/templates/spotlight_result_recent_search"](
						{
							id: j, 
							path:'/search/all?term=' + NavSearchUtils.localRecentSearches[j], 
							content: NavSearchUtils.localRecentSearches[j]
						});
					jQuery('#SearchResultsBar .recent_searches_results').append(searchItem);
				}			
				
			}
			if(NavSearchUtils.localRecentTickets.length > 0){				
				jQuery('.recent_tickets_li').remove();
				//Show most recently viewed to least recently viewed
				for(var j = NavSearchUtils.localRecentTickets.length - 1; j > -1; j--){
					var searchItem = JST["app/search/templates/spotlight_result_recent_ticket"](
					{
						id: j, 
						displayId: NavSearchUtils.localRecentTickets[j].displayId, 
						path: NavSearchUtils.localRecentTickets[j].path, 
						subject: NavSearchUtils.localRecentTickets[j].subject
					});
					jQuery('#SearchResultsBar .recent_tickets_results').append(searchItem);
				}
			}
			// this is to hide/show recent searches/tickets in case of first load etc.
			$J("#SearchResultsBar").css("display", "inline");
			jQuery("ul.results").filter(function(){return jQuery(this).find('li.spotlight_result').length == 0; }).hide();
			jQuery("ul.results").filter(function(){return jQuery(this).find('li.spotlight_result').length > 0; }).show();

			jQuery('.recent_search_cross_icon').bind('click.remove_recent_search', function(ev){
				ev.stopPropagation();
				ev.preventDefault();
				var recentSearchId = jQuery(ev.currentTarget).parents('li.spotlight_result').attr('id');
				var searchIndex = parseInt(recentSearchId.replace('recent_search_',''));

				NavSearchUtils.localRecentSearches.splice(searchIndex, 1);
				NavSearchUtils.setLocalRecentSearches(NavSearchUtils.localRecentSearchKey);

				if(searchIndex === 0 && NavSearchUtils.localRecentSearches.length === 0){
					jQuery(ev.currentTarget).parents('#recent_search_' + searchIndex).remove();
					jQuery("ul.results").filter(function(){return jQuery(this).find('li.spotlight_result').length == 0; }).hide();
				}				
				jQuery('#header_search').focus();
			});

			
		}
		if(searchString != '' && jQuery('#SearchResultsBar li').hasClass('spotlight_result')){
			$J("#SearchResultsBar").css("display", "inline");
		}
	});
			
	var move = function(diff){
		searchlist 	= $J("#SearchResultsBar a");
		for(var i = 0 ; i < searchlist.length; i++){
			if(jQuery(searchlist[i]).hasClass('active')){
				position = i;
				break;
			}
		}
		$J(currentactive).removeClass("active");
		position = Math.min((searchlist.size()-1), Math.max(0, position + diff)); 
		currentactive = $J(searchlist.get(position)).addClass("active"); 
	};
			
	var executeAction = function (keyCode){
		focusedOnSearch = false;
		 switch (keyCode) {
			case 40:
				move(1);
				break;
			case 38:
				move(-1);
				break;
			case 13:
				focusedOnSearch = true
				$J(currentactive).trigger("click");
				break; 
		}
	} 
			
	$J("#header_search").bind("keyup", function(e){
		 switch (e.keyCode) {
		 	case 40:
			case 38:
			case 13:
				executeAction(e.keyCode);
				e.preventDefault();
			break;
			default:
				var self = this;
				searchString = self.value.replace(/^\s+|\s+$/g, "");
				search_url = "/search/home/suggest?term=";
				if(searchString != '' && searchString.length > 1 && currentString != searchString){
					delay(function(){
						fullSearchString = self.value;
						callbackToSearch(encodeURIComponent(searchString), search_url);
						currentString = searchString;
				    }, 450 ); 
				}else if(currentString == searchString){
					if(searchString != '' && jQuery('#SearchResultsBar li').hasClass('spotlight_result')){
						$J("#SearchResultsBar").css("display", "inline"); 
						$J("ul.results").filter(function(){return jQuery(this).find('li.spotlight_result').length > 0; }).show();
					}
				}else{
					jQuery("#SearchResultsBar").hide();				
				}
			break;
		}
	});


	jQuery('body').on('submit', '.nav_search', function(ev){ 
		if(!focusedOnSearch){
			return false;
		} else {
			ev.preventDefault(); 
			handleFullSearch();
		}

	});

	jQuery("[data-domhelper-name='ticket-delete-btn'], li a.spam").bind('click.remove_recent_ticket', function(ev){				
		if(TICKET_DETAILS_DATA){
			NavSearchUtils.deleteRecentTicketById(TICKET_DETAILS_DATA['displayId']);
		}
	});
});


