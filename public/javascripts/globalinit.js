/**
 * @author venom
 */
var jQ = jQuery.noConflict(); 

(function($){
	// Global initialisation  
	jQuery(document).ready(function() {
		// - Labels with overlabel will act a Placeholder for form elements 
	    jQuery("label.overlabel").overlabel();
	
		// - jQuery Validation for forms with class .ui-form ( ...An optional dont-validate written for the form element will make the selectors ignore those form alone )
		jQuery("ul.ui-form").not(".dont-validate").parents('form:first').validate();
		jQuery("div.ui-form").not(".dont-validate").find('form:first').validate(); 
		
		flash = $("div.flash_info");
		if(flash.get(0)){
			close =	$("<a />").addClass("close")
							  .attr("href", "#")
							  .appendTo(flash)
							   .click(function(ev){
									flash.fadeOut(600);
								});
				
					flash.find('a.show-list')
					  	 .click(function(ev){
						  	flash.find('div.list').slideDown(300);
							$(this).hide();
						 });			
		}
		
	});
	
})(jQuery)
