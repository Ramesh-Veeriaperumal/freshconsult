var NavSearchUtils = NavSearchUtils || (function(){
	var navSearchUtils = {};
	navSearchUtils.localRecentSearchKey = getLocalRecentSearchKey();
	navSearchUtils.localRecentTicketKey = getLocalRecentTicketsKey();
	navSearchUtils.localRecentTimestampKey = getLocalRecentTimestampKey();

	navSearchUtils.tryClearLocalRecents = function(){
		var storedTimestamp = getFromLocalStorage(navSearchUtils.localRecentTimestampKey);
		var currentTimestamp = new Date().getTime();
		var eightHoursSeconds = 8 * 60 * 60;
		if(storedTimestamp){
			var timeElapsed = currentTimestamp - storedTimestamp;
			timeElapsed = Math.round(timeElapsed / 1000);
			if (timeElapsed > eightHoursSeconds){
				navSearchUtils.clearLocalRecents();
				storeBrowserLocalStorage(navSearchUtils.localRecentTimestampKey, currentTimestamp);
			}
		}else{
			navSearchUtils.clearLocalRecents();
			storeBrowserLocalStorage(navSearchUtils.localRecentTimestampKey, currentTimestamp);
		}

	}

	navSearchUtils.clearLocalRecents = function(){
		removeFromLocalStorage(navSearchUtils.localRecentSearchKey);
		removeFromLocalStorage(navSearchUtils.localRecentTicketKey);
	}

	navSearchUtils.clearLocalRecentTimestamp = function(){
		removeFromLocalStorage(navSearchUtils.localRecentTimestampKey);
	}


	navSearchUtils.saveServerRecents = function(recents, isRecentSearches){
		var lrs = queue(5);
		if (recents){
			for(var i = 0; i < recents.length; i++){
				var recentItem = recents[i];
				if(isRecentSearches){
					recentItem = recentItem.length > 100 ? recentItem.substring(0, 100) + '...' : recentItem;
				}else{
					recentItem['subject'] = recentItem['subject'].length > 100 ? recentItem['subject'].substring(0, 100) + '...' : recentItem['subject'];			
				}
				lrs.push(recentItem);
			}			
		}
		if (isRecentSearches){
			navSearchUtils.localRecentSearches = lrs;
			navSearchUtils.setLocalRecentSearches(navSearchUtils.localRecentSearchKey);
		}else{
			navSearchUtils.localRecentTickets = lrs;
			navSearchUtils.setLocalRecentTickets(navSearchUtils.localRecentTicketKey);
		}
		
	}
	
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
				// remove the item from its place
				navSearchUtils.localRecentSearches.splice(i, 1);
				//insert it at the top
				navSearchUtils.localRecentSearches.splice(4, 0, fullSearchString);
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

	navSearchUtils.deleteRecentTicketById = function(displayId){
		if(!displayId) return;
		navSearchUtils.localRecentTickets = navSearchUtils.getLocalRecentTickets(navSearchUtils.localRecentTicketKey);
		for(var i = 0; i < navSearchUtils.localRecentTickets.length; i++){
			if(navSearchUtils.localRecentTickets[i].displayId == displayId){
				// remove the item from its place
				navSearchUtils.localRecentTickets.splice(i, 1);
				navSearchUtils.setLocalRecentTickets(navSearchUtils.localRecentTicketKey);				
				break;
			}			
		}
	}


	navSearchUtils.saveToLocalRecentTickets = function(TICKET_DETAILS_DATA){
		if (TICKET_DETAILS_DATA['ticket_deleted'] == true || TICKET_DETAILS_DATA['ticket_spam'] == true) return;
		var isLocalRecentTicket = false;
		navSearchUtils.localRecentTickets = navSearchUtils.getLocalRecentTickets(navSearchUtils.localRecentTicketKey);
		for(var i = 0; i < navSearchUtils.localRecentTickets.length; i++){
			isLocalRecentTicket = navSearchUtils.localRecentTickets[i].displayId == TICKET_DETAILS_DATA['displayId'];
			if(isLocalRecentTicket){
				// remove the item from its place
				navSearchUtils.localRecentTickets.splice(i, 1);
				//insert it at the top
				navSearchUtils.localRecentTickets.splice(4, 0, {displayId: TICKET_DETAILS_DATA['displayId'], subject: TICKET_DETAILS_DATA['ticket_subject'], path: TICKET_DETAILS_DATA['ticket_path']});
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

	function getLocalRecentSearchKey(){
		return 'local_recent_searches_' + window.current_account_id + '_' + window.current_user_id;
	}

	function getLocalRecentTicketsKey(){
		return 'local_recent_tickets_' + window.current_account_id + '_' + window.current_user_id;
	}

	function getLocalRecentTimestampKey(){
		return 'local_recent_searches_tickets_timestamp_' + window.current_account_id + '_' + window.current_user_id;
	}

	return navSearchUtils;

})();

