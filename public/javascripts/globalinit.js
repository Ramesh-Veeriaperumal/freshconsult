/**
 * @author venom
 */
var jQ = jQuery.noConflict();

(function($){
	// Global Jquery Plugin initialisation
	$.fn.qtip.baseIndex = 10000;
	  
	// App initialisation  
	$(document).ready(function() {
		// - Labels with overlabel will act a Placeholder for form elements 
	    $("label.overlabel").overlabel();
	
		// - jQuery Validation for forms with class .ui-form ( ...An optional dont-validate written for the form element will make the selectors ignore those form alone )
		validateOptions = {
			onkeyup: false,
			focusCleanup: true,
			focusInvalid: false
		} 
		
		$("ul.ui-form").not(".dont-validate").parents('form:first').validate(validateOptions);
		$("div.ui-form").not(".dont-validate").find('form:first').validate(validateOptions); 
		$("form.uniForm").validate(validateOptions);
		
		// Make Textareas to expand automatically when editing it
		// Auto Resize in IE seems to be screwing up the horizontal scroll bar... hence removing it
		if(!$.browser.msie)
			$("textarea.auto-expand").autoResize();
		
		// Any object with class custom-tip will be given a different tool tip
		$(".custom-tip").qtip({
			 position: {
			      my: 'center right',  // Position my top left...
			      at: 'center left', // at the bottom right of...
			      viewport: jQuery(window) 
			 }, 
			 style : {
			 	classes: 'ui-tooltip-rounded ui-tooltip-shadow'
			 }
		});
		
		$(".custom-tip-top").qtip({
			 position: {
			      my: 'bottom center',  // Position my top left...
			      at: 'top center', // at the bottom right of...
			      viewport: jQuery(window) 
			 }, 
			 style : {
			 	classes: 'ui-tooltip-rounded ui-tooltip-shadow'
			 }
		});
		 
		flash = $("div.flash_info");
		if(flash.get(0)){
			try {
				close = $("<a />").addClass("close").attr("href", "#").appendTo(flash).click(function(ev){
					flash.fadeOut(600);
				});
				setTimeout(function() {
			        flash.hide('blind', {}, 500)
			    }, 20000);
				flash.find('a.show-list').click(function(ev){
					flash.find('div.list').slideDown(300);
					$(this).hide();
				});
			} catch(e){
				
			}			
		}
		
	});
	
})(jQuery)
