// File to make the single point of initialization of redactor editor. Please make sure you add further initializations through the same function.
    function invokeRedactor(element_id,type,attr){
    	if(attr == "class") element_id = "."+element_id;
    	else element_id ="#"+element_id;
    	switch(type){
    		case 'ticket':
         	jQuery(element_id).redactor({ 
         		focus: false, convertDivs: false, observeImages:true, autoresize:false, imageUpload:"/tickets_uploaded_images", allowTagsInCodeSnippet:true,
         		buttons:['bold','italic','underline','|','unorderedlist', 'orderedlist',  '|','fontcolor', 'backcolor', '|' ,'link', 'image', 'removeFormat']});
         	break;
    		case 'forum':
    			jQuery(element_id).redactor({autoresize:false,convertDivs: false, allowTagsInCodeSnippet:true, buttons:['bold','italic','underline','|','unorderedlist', 'orderedlist',  '|','fontcolor', 'backcolor', '|' ,'link','image', 'video']});
    			break;
	    	case 'cnt-reply':
	         	jQuery(element_id).redactor({
					focus: true, convertDivs: false, autoresize:false, observeImages:true, imageUpload:"/tickets_uploaded_images", allowTagsInCodeSnippet:true,
					buttons:['bold','italic','underline','|','unorderedlist', 'orderedlist',  '|','fontcolor', 'backcolor', '|' ,'link', 'image', 'removeFormat'],
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
	    	case 'cnt-fwd':
	         	jQuery(element_id).redactor({ 
	         		focus: false, convertDivs: false, observeImages:true, autoresize:false, imageUpload:"/tickets_uploaded_images", allowTagsInCodeSnippet:true,
	         		buttons:['bold','italic','underline','|','unorderedlist', 'orderedlist',  '|','fontcolor', 'backcolor', '|' ,'link', 'image', 'removeFormat']});
	         	break;
	        case 'cnt-note':
	         	jQuery(element_id).redactor({ 
	         		focus: true, convertDivs: false, observeImages:true, autoresize:false, imageUpload:"/tickets_uploaded_images", allowTagsInCodeSnippet:true,
	         		buttons:['bold','italic','underline','|','unorderedlist', 'orderedlist',  '|','fontcolor', 'backcolor', '|' ,'link', 'image', 'removeFormat']});
	         	break;
	        case 'signature':
	         	jQuery(element_id).redactor({ focus: false,convertDivs: false, autoresize:false, buttons:['bold','italic','underline','|','image',  '|','fontcolor', 'backcolor', '|' ,'link']});	
	        default:
	    	 	jQuery(element_id).redactor({ convertDivs: false,  autoresize:false, buttons:['bold','italic','underline','|','unorderedlist', 'orderedlist',  '|','fontcolor', 'backcolor', '|' ,'link']});
	     	}
 	}

