// File to make the single point of initialization of redactor editor. Please make sure you add further initializations through the same function.
    function invokeRedactor(element_id,type,attr){
    	if(attr == "class") element_id = "."+element_id;
    	else element_id ="#"+element_id;
    	switch(type){
    		case 'ticket':
         	jQuery(element_id).redactor({ 
         		focus: false, convertDivs: false, observeImages:true, autoresize:false, imageUpload:"/tickets_uploaded_images", clipboardImageUpload:"/tickets_uploaded_images/create_file", setFontSettings:true, wrapFontSettings:Helpdesk.settings, allowTagsInCodeSnippet:true,
         		buttons:['bold','italic','underline','|','unorderedlist', 'orderedlist',  '|','fontcolor', 'backcolor', '|' ,'link', 'image', 'removeFormat'],
         		imageUploadCallback: inlineImageUploadCallback
         	});
         	break;
        case 'anonymous-ticket':
           jQuery(element_id).redactor({ clipboardImageUpload:"/tickets_uploaded_images/create_file", convertDivs: false,  autoresize:false, setFontSettings:true, wrapFontSettings:Helpdesk.settings, buttons:['bold','italic','underline','|','unorderedlist', 'orderedlist',  '|','fontcolor', 'backcolor', '|' ,'link']});
           break;
			case 'template':
				jQuery(element_id).redactor({ 
					focus: false, convertDivs: false, observeImages:true, autoresize:false, imageUpload:"/ticket_templates_uploaded_images", clipboardImageUpload:"/ticket_templates_uploaded_images/create_file", setFontSettings:true, wrapFontSettings:Helpdesk.settings, allowTagsInCodeSnippet:true,
					buttons:['bold','italic','underline','|','unorderedlist', 'orderedlist',  '|','fontcolor', 'backcolor', '|' ,'link', 'image', 'removeFormat']});
				break;
    		case 'forum':
    			jQuery(element_id).redactor({autoresize:false,convertDivs: false, allowTagsInCodeSnippet:true, buttons:['bold','italic','underline','|','unorderedlist', 'orderedlist',  '|','fontcolor', 'backcolor', '|' ,'link','image', 'video'],  imageUpload: "/forums_uploaded_images", clipboardImageUpload: "/forums_uploaded_images/create_file", imageGetJson: "/forums_uploaded_images", imageUploadCallback: inlineImageUploadCallback});
    			break;
    		case 'solution':
    			jQuery(element_id).redactor({autoresize:true,convertDivs: false, allowTagsInCodeSnippet:true, tabindex: 2, imageUpload: "/solutions_uploaded_images", clipboardImageUpload: "/solutions_uploaded_images/create_file", imageGetJson: "/solutions_uploaded_images"});
    			break;
	    	case 'cnt-reply':
	         	jQuery(element_id).redactor({
					focus: true, convertDivs: false, autoresize:false, observeImages:true, imageUpload:"/tickets_uploaded_images", clipboardImageUpload:"/tickets_uploaded_images/create_file", setFontSettings:true, wrapFontSettings:Helpdesk.settings, allowTagsInCodeSnippet:true,
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
					},
					imageUploadCallback: inlineImageUploadCallback
				});
	    	case 'cnt-fwd':
	         	jQuery(element_id).redactor({ 
	         		focus: false, convertDivs: false, observeImages:true, autoresize:false, imageUpload:"/tickets_uploaded_images", clipboardImageUpload:"/tickets_uploaded_images/create_file", setFontSettings:true, wrapFontSettings:Helpdesk.settings, allowTagsInCodeSnippet:true,
	         		buttons:['bold','italic','underline','|','unorderedlist', 'orderedlist',  '|','fontcolor', 'backcolor', '|' ,'link', 'image', 'removeFormat'],
	         		imageUploadCallback: inlineImageUploadCallback
	         	});
	         	break;
	        case 'automation':
	         	jQuery(element_id).redactor({ 
	         		focus: false, convertDivs: false, observeImages:true, autoresize:false, imageUpload:"/tickets_uploaded_images", clipboardImageUpload:"/tickets_uploaded_images/create_file", setFontSettings:true, wrapFontSettings:Helpdesk.settings, allowTagsInCodeSnippet:true,
	         		buttons:['bold','italic','underline','|','unorderedlist', 'orderedlist',  '|','fontcolor', 'backcolor', '|' ,'link', 'image', 'removeFormat']	         		
	         	});
	         	break;
	        case 'cnt-note':
	         	jQuery(element_id).redactor({ 
	         		focus: true, convertDivs: false, observeImages:true, autoresize:false, imageUpload:"/tickets_uploaded_images", clipboardImageUpload:"/tickets_uploaded_images/create_file", setFontSettings:true, wrapFontSettings:Helpdesk.settings, allowTagsInCodeSnippet:true,
	         		buttons:['bold','italic','underline','|','unorderedlist', 'orderedlist',  '|','fontcolor', 'backcolor', '|' ,'link', 'image', 'removeFormat'],
	         		imageUploadCallback: inlineImageUploadCallback
	         	});
	         	break;
	        case 'cnt-broadcast':
	         	jQuery(element_id).redactor({ 
	         		focus: true, convertDivs: false, observeImages:true, autoresize:false, imageUpload:"/tickets_uploaded_images", clipboardImageUpload:"/tickets_uploaded_images/create_file", setFontSettings:true, wrapFontSettings:Helpdesk.settings, allowTagsInCodeSnippet:true,
	         		buttons:['bold','italic','underline','|','unorderedlist', 'orderedlist',  '|','fontcolor', 'backcolor', '|' ,'link', 'image', 'removeFormat'],
	         		imageUploadCallback: inlineImageUploadCallback
	         	});
	         	break;
	        case 'bulk-reply':
				jQuery(element_id).redactor({
					focus: false, convertDivs: false, observeImages:true, autoresize:false, imageUpload:"/tickets_uploaded_images", setFontSettings:true, wrapFontSettings:Helpdesk.settings, allowTagsInCodeSnippet:true,
					buttons:['bold','italic','underline','|','unorderedlist', 'orderedlist',  '|','fontcolor', 'backcolor', '|' ,'link', 'image', 'removeFormat'],
					imageUploadCallback: inlineImageUploadCallback
				});
				break;
	        case 'signature':
	         	jQuery(element_id).redactor({ focus: false,convertDivs: false, autoresize:false, buttons:['bold','italic','underline','|','image',  '|','fontcolor', 'backcolor', '|' ,'link']});	
	        default:
	    	 	jQuery(element_id).redactor({ convertDivs: false,  autoresize:false, setFontSettings:true, wrapFontSettings:Helpdesk.settings, buttons:['bold','italic','underline','|','unorderedlist', 'orderedlist',  '|','fontcolor', 'backcolor', '|' ,'link']});
	     	}
 	}

var inlineImageUploadCallback = function(editor, data) {
	var currentForm = editor.$el.parents('form');
	// Replacing all [<enclosing content>] with empty spaces to arrive at scoper
	var inlineAttachmentScoper = editor.$el.attr('name').replace(/\[.*\]/g, "");
	var inlineAttachmentInput = jQuery('<input type="hidden">').attr({
		name: inlineAttachmentScoper + '[inline_attachment_ids][]',
		value: data.fileid,
		class: "inline-attachment-input"
	});
	currentForm.append(inlineAttachmentInput);
}

