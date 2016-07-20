var NavSearchUtils = NavSearchUtils || (function(){
	var navSearchUtils = {};

	navSearchUtils.saveToLocalRecentSearches= function (fullSearchString){
		navSearchUtils.localRecentSearches = navSearchUtils.getLocalRecentSearches(navSearchUtils.localRecentSearchKey);
		//check if search stirng is already part of local recent searches
		var isLocalRecentSearch = false;

		var reducedString = fullSearchString.replace(/^\s+|\s+$/g, "").toLowerCase();

		if(reducedString.length === 0) return;

		for(var i = 0; i < navSearchUtils.localRecentSearches.length; i++){
			var reducedLocalSearchString = navSearchUtils.localRecentSearches[i].replace(/^\s+|\s+$/g, "").toLowerCase();
			isLocalRecentSearch = reducedLocalSearchString == reducedString;
			if(isLocalRecentSearch){
				//replace positions of the search strings
				var last = navSearchUtils.localRecentSearches[navSearchUtils.localRecentSearches.length - 1];
				navSearchUtils.localRecentSearches[navSearchUtils.localRecentSearches.length - 1] = fullSearchString;
				navSearchUtils.localRecentSearches[i] = last;
				break;
			}			
		}
		if(!isLocalRecentSearch){
			navSearchUtils.localRecentSearches.push(fullSearchString);
		}
		navSearchUtils.setLocalRecentSearches(navSearchUtils.localRecentSearchKey);

	}

	navSearchUtils.getLocalRecentSearches = function (key){
		var lrs = queue(5);
		var parsedSearches = getFromLocalStorage(key);
		if(!parsedSearches) return lrs;
		for(var i = 0; i < parsedSearches.length; i++){			
			lrs.push(parsedSearches[i]);
		}		
		return lrs;
	};

	navSearchUtils.setLocalRecentSearches = function (key){
		storeBrowserLocalStorage(key, navSearchUtils.localRecentSearches);		
	};

	navSearchUtils.saveToLocalRecentTickets = function(TICKET_DETAILS_DATA){
		var isLocalRecentTicket = false;
		navSearchUtils.localRecentTickets = navSearchUtils.getLocalRecentTickets(navSearchUtils.localRecentTicketKey);
		for(var i = 0; i < navSearchUtils.localRecentTickets.length; i++){
			isLocalRecentTicket = navSearchUtils.localRecentTickets[i].displayId == TICKET_DETAILS_DATA['displayId'];
			if(isLocalRecentTicket){
				//replace positions of the tickets
				var last = navSearchUtils.localRecentTickets[navSearchUtils.localRecentTickets.length - 1];
				navSearchUtils.localRecentTickets[navSearchUtils.localRecentTickets.length - 1] = {displayId: TICKET_DETAILS_DATA['displayId'], subject: TICKET_DETAILS_DATA['ticket_subject'], path: TICKET_DETAILS_DATA['ticket_path']};
				navSearchUtils.localRecentTickets[i] = last;
				break;
			}			
		}
		if(!isLocalRecentTicket){
			navSearchUtils.localRecentTickets.push({displayId: TICKET_DETAILS_DATA['displayId'], subject: TICKET_DETAILS_DATA['ticket_subject'], path: TICKET_DETAILS_DATA['ticket_path']});
		}
		navSearchUtils.setLocalRecentTickets(navSearchUtils.localRecentTicketKey);

	}

	navSearchUtils.getLocalRecentTickets = function (key){
		var lrs = queue(5);
		var parsedTickets = getFromLocalStorage(key);
		if(!parsedTickets) return lrs;
		for(var i = 0; i < parsedTickets.length; i++){			
			lrs.push(parsedTickets[i]);
		}		
		return lrs;
	};

	navSearchUtils.setLocalRecentTickets = function (key){
		storeBrowserLocalStorage(key, navSearchUtils.localRecentTickets);		
	}

	function queue (len){
		var ret = [];

	    ret.push = function(a) {
	        if(ret.length == len) ret.shift();
	        return Array.prototype.push.apply(this, arguments);
	    };

	    return ret;
	}

	return navSearchUtils;

})();

