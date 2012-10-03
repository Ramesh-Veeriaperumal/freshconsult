// File to make the single point of initialization of redactor editor. Please make sure you add further initializations through the same function.
    function invokeRedactor(element_id,type){
    	switch(type){
    		case 'forum':
    			jQuery('#'+element_id).redactor({autoresize:false,convertDivs: false, buttons:['bold','italic','underline','|','unorderedlist', 'orderedlist',  '|','fontcolor', 'backcolor', '|' ,'link','image', 'video']});
    			break;
	    	case 'cnt-reply':
	         	jQuery('#'+element_id).redactor({ focus: true, convertDivs: false, autoresize:false, buttons:['bold','italic','underline','|','unorderedlist', 'orderedlist',  '|','fontcolor', 'backcolor', '|' ,'link'],execCommandCallback: function(obj, command) { isDirty=true; } , keyupCallback: function(obj, event) {isDirty=true;} });
	         	break;
	        case 'signature':
	         	jQuery('#'+element_id).redactor({ focus: true,convertDivs: false,  autoresize:false, buttons:['bold','italic','underline','|','image',  '|','fontcolor', 'backcolor', '|' ,'link']});	
	        default:
	    	 	jQuery('#'+element_id).redactor({ focus: true,convertDivs: false,  autoresize:false, buttons:['bold','italic','underline','|','unorderedlist', 'orderedlist',  '|','fontcolor', 'backcolor', '|' ,'link']});
	     	}
 	}


