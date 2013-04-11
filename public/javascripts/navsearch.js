jQuery(document).ready(function(){
	var currentactive,
      position   		= -1, 
      insideSearch 	= false;
      currentString = "";
      
  callbackToSearch = function(string, search_url){    
    jQuery.ajax({ url: search_url+string, 
                  success: function(data){
                           if(string == $("header_search").value){
                              //console.log(currentString);
                              $J("#SearchResultsBar").css("display", "inline"); 
                              position   = -1;
                              $J("#SearchResultsBar .results").html(data);
                           }
                          }});
                        }
			
			
			$J("#SearchResultsBar a").live("click", function(){
				window.location = this.href; 
			});
			$J("#SearchResultsBar a").die('hover');
			$J("#SearchResultsBar a").live("hover", function(){
				$J(currentactive).removeClass("active");
				currentactive = $J(this).addClass("active");
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
					$J("#SearchResultsBar").hide();
				  $J("#SearchBar").removeClass("active");					
				}
			});
			
			$J("#header_search").bind("focusin", function(ev){
				searchString = this.value.replace(/^\s+|\s+$/g, "");
				$J("#SearchBar").addClass("active");
				if(searchString != ''){
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
				es_enabled = jQuery(e.target).data('esEnabled');
				 switch (e.keyCode) {
				 	case 40:
					case 38:
					case 13:
						executeAction(e.keyCode);
						e.preventDefault();
					break;
					default:
						searchString = this.value.replace(/^\s+|\s+$/g, "");
						search_url = es_enabled ? "/search/home/suggest?search_key=" : "/search/suggest?search_key=";
						if(searchString != '' && searchString.length > 1 && currentString != searchString){
							delay(function(){
						      callbackToSearch(searchString, search_url);
						      currentString = searchString;
						    }, 100 ); 
						}else{
							jQuery("#SearchResultsBar").hide();				
						}
					break;
				}
			});
})