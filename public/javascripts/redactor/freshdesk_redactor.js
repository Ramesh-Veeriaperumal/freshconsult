// File to make the single point of initialization of redactor editor. Please make sure you add further initializations through the same function.
    function invokeRedactor(element_id,type){
    	switch(type){
    		case 'forum':
    			jQuery('#'+element_id).redactor({autoresize:false,convertDivs: false, buttons:['bold','italic','underline','|','unorderedlist', 'orderedlist',  '|','fontcolor', 'backcolor', '|' ,'link','image', 'video']});
    			break;
	    	case 'cnt-reply':
	         	jQuery('#'+element_id).redactor({
					focus: true, convertDivs: false, autoresize:false, 
					buttons:['bold','italic','underline','|','unorderedlist', 'orderedlist',  '|','fontcolor', 'backcolor', '|' ,'link'],
					execCommandCallback: function(obj, command) { 
						if (typeof(TICKET_DETAILS_DATA) != 'undefined') {
							if (typeof(TICKET_DETAILS_DATA['draft']['clearingDraft']) == 'undefined' || !TICKET_DETAILS_DATA['draft']['clearingDraft']) {
								TICKET_DETAILS_DATA['draft']['hasChanged'] = true; 
							} else {
								TICKET_DETAILS_DATA['draft']['clearingDraft'] = false;
							}
						} else {
							isDirty=true; 
						}
					} , 
					keyupCallback: function(obj, event) {
						if (typeof(TICKET_DETAILS_DATA) != 'undefined') {
							if (typeof(TICKET_DETAILS_DATA['draft']['clearingDraft']) == 'undefined' || !TICKET_DETAILS_DATA['draft']['clearingDraft']) {
								isDirty=true; 
								TICKET_DETAILS_DATA['draft']['hasChanged'] = true;
							} else {
								TICKET_DETAILS_DATA['draft']['clearingDraft'] = false;
							}
						} else {
							isDirty=true; 
						}
					} 
				});
	         	break;
	        case 'signature':
	         	jQuery('#'+element_id).redactor({ focus: false,convertDivs: false,  autoresize:false, buttons:['bold','italic','underline','|','image',  '|','fontcolor', 'backcolor', '|' ,'link']});	
	        default:
	    	 	jQuery('#'+element_id).redactor({ convertDivs: false,  autoresize:false, buttons:['bold','italic','underline','|','unorderedlist', 'orderedlist',  '|','fontcolor', 'backcolor', '|' ,'link']});
	     	}
 	}


