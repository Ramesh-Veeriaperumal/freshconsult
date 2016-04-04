var active_email_body = null;

(function($){
	$.fn.groupPlaceholders = function(options) {
		var defaults = {
			groupingParent : '.placeholder-category-list',
			btnPrefix : 'placeholder-btn-',
			tabContainer : '.placeholder-category-title-container',
			ignorePhs : "",
			activateTab : function() { activateTab.call(this) }
		};
		var settings = $.extend({},defaults, options);
		var ignorePlaceholders = function(options) {
			options = $.extend({}, settings, options);	
			//toggle automations -> webhooks/email placeholders & tabs
            $(options.tabContainer).find('li').show();
			$(options.groupingParent).find('li').removeClass('hidden');
		 	options.ignorePhs.split(",").each(function(item){
		 		var element = "#"+ options.btnPrefix + item;
		 		$(element).addClass('hidden');
		 		if($(element).parent().children('li:not(.hidden)').length == 0) {
		 			var parent = $(element).parents(options.groupingParent);
		 			var category = $(parent).data("category");
		 			var categoryTab = $(options.tabContainer+' li[data-category="'+category+'"]');
		 			$(categoryTab).hide();
		 		}
		 	});
		 	settings.activateTab();
		};

		var activateTab = function(options) {
			if($(settings.tabContainer).children("li.active:visible").length==0) {
			    $(settings.tabContainer+" li:first-child a").tab("show");
			}  
		};

		this.init = function() {
			ignorePlaceholders({
			 	'ignorePhs' : jQuery(active_email_body).data('ignorePlaceholders') || ""
			});
			settings.activateTab();
			return this;
		}
		return this.init();
	};

}(jQuery));


jQuery(document).ready(function(){
	jQuery('body').on('focus',".insert-placeholder-target", function(){
		active_email_body = jQuery(this);
		jQuery('#place-dialog').groupPlaceholders();
	});

	jQuery('.redactor_editor').live('click', function(){
		active_email_body = jQuery(this).siblings('textarea');	
		jQuery('#place-dialog').groupPlaceholders();
    });
	
	jQuery(".placeholder-list button, .placeholder-list a.ph-btn").click(function(ev){  
		preventDefault(ev);
		if(jQuery(this).parent().hasClass('ph-more-less')) {
			return false;
		}
      	if(active_email_body){
	        var placeHolderText = jQuery(this).data("placeholder"); 
	        if(active_email_body.hasClass("desc_info") || active_email_body.hasClass("ca_content_body")){
	        	active_email_body.data('redactor').insertOnCursorPosition('inserthtml',placeHolderText);
	        } else if(active_email_body.hasClass("paragraph-redactor")){
		        active_email_body.data('redactor').insertOnCursorPosition('inserthtml',placeHolderText);
	        }
	        else{
	          insertTextAtCursor(active_email_body.get(0), placeHolderText);
	        }
	        var editor = active_email_body.data("CodeMirrorInstance");
	        if (editor){
		    	editor.replaceRange(placeHolderText, editor.getCursor());   
		    }
		}
	});
	
	jQuery('#placeholder_close').click(function(){
		jQuery('#place-dialog').hide();	
	});

	jQuery('#place-dialog').draggable({
		cancel : '.placeholder-list'
	});

});