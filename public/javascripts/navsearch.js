jQuery(document).ready(function(){
	var currentactive,
      position   		= -1, 
      insideSearch 	= false;
      currentString = "";
      
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
           	insideSearch = true;
           },
        mouseleave:
           function()
           {
           	insideSearch = false;
           }
       });
			
			$J("#header_search").bind("focusout", function(ev){ 
				if(!insideSearch){
					hideSearchBar();					
				}
			});
			
			$J("#header_search").bind("focusin", function(ev){
				searchString = this.value.replace(/^\s+|\s+$/g, "");
				$J("#SearchBar").addClass("active");
				$J("#header_search").attr("placeholder", "Search");
				$J('#SearchBar').twipsy('hide')
				if(searchString != '' && jQuery('#SearchResultsBar li').hasClass('spotlight_result')){
					$J("#SearchResultsBar").css("display", "inline");
				}
			}); 
			
			var move = function(diff){
				searchlist 	= $J("#SearchResultsBar a");
				$J(currentactive).removeClass("active");
				position = Math.min((searchlist.size()-1), Math.max(0, position + diff)); 
				currentactive = $J(searchlist.get(position)).addClass("active"); 
			};
			
			var executeAction = function (keyCode){
				 switch (keyCode) {
					case 40:
						move(1);
						break;
					case 38:
						move(-1);
						break;
					case 13:
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
						searchString = this.value.replace(/^\s+|\s+$/g, "");
						search_url = "/search/home/suggest?term=";
						if(searchString != '' && searchString.length > 1 && currentString != searchString){
							delay(function(){
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
        ev.preventDefault(); handleFullSearch();
      });
})