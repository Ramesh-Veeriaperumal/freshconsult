/*
 * @author venom
 */
var $J = jQuery.noConflict();

(function($){
   // Global Jquery Plugin initialisation
   $.fn.qtip.baseIndex = 10000;

   // Tweet custom class
   $.validator.addMethod("tweet", $.validator.methods.maxlength, "Your Tweet was over 140 characters. You'll have to be more clever." );   
   $.validator.addMethod("facebook", $.validator.methods.maxlength, "Your Facebook reply was over 8000 characters. You'll have to be more clever." );   
   $.validator.addClassRules("tweet", { tweet: 140 });
   $.validator.addClassRules("facebook", { tweet: 8000 });
      
   // App initialisation  
   $(document).ready(function() {
      // SyntaxHighlighter.all();

      // - Labels with overlabel will act a Placeholder for form elements 
      $("label.overlabel").overlabel();
      
      $(".customSelect").chosen();
	  
	  quote_text();

      // - jQuery Validation for forms with class .ui-form ( ...An optional dont-validate written for the form element will make the selectors ignore those form alone )
      validateOptions = {
         onkeyup: false,
         focusCleanup: true,
         focusInvalid: false
      };

      $(".admin_list li")
         .hover(
            function(){ $(this).children(".item_actions").css("visibility", "visible"); }, 
            function(){ $(this).children(".item_actions").css("visibility", "hidden"); }
         );
	
      $("ul.ui-form").not(".dont-validate").parents('form:first').validate(validateOptions);
      $("div.ui-form").not(".dont-validate").find('form:first').validate(validateOptions); 
      $("form.uniForm").validate(validateOptions);

      // Make Textareas to expand automatically when editing it
      // Auto Resize in IE seems to be screwing up the horizontal scroll bar... hence removing it
      if(!$.browser.msie)
         $("textarea.auto-expand").autoResize();
		
		sidebarHeight = $('#Sidebar').height();
		if(sidebarHeight !== null && sidebarHeight > $('#Pagearea').height())
			$('#Pagearea').css("minHeight", sidebarHeight);
		
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
		
		$(".custom-tip-bottom").qtip({
			 position: {
			      my: 'top center',  // Position my top left...
			      at: 'bottom center', // at the bottom right of...
			      viewport: jQuery(window) 
			 }, 
			 style : {
				classes: 'ui-tooltip-rounded ui-tooltip-shadow'
			 }
		});
		
		$(".nav-trigger").showAsMenu();
		
		menu_box_count = 0;
		fd_active_drop_box = null;
		
		function hideMenuItem(){
			$(".nav-drop .menu-box").hide();
			$(".nav-drop .menu-trigger").removeClass("selected");
		}
		
		$(".nav-drop .menu-trigger")
			.live('click', function(ev){
				ev.preventDefault();
				
				$(this).toggleClass("selected").next().toggle();
				
				if( !$(this).attr("data-menu-name") )
						$(this, $(this).next())
							.attr("data-menu-name", "page_menu_"+menu_box_count++);
				
				if($(this).attr("data-menu-name") !== $(fd_active_drop_box).attr("data-menu-name") ){
					$(fd_active_drop_box).removeClass("selected").next().hide();
				}
				fd_active_drop_box = $(this);
			});
		
		$(".nav-drop li.menu-item a").bind("click", function(){
			hideMenuItem();
		});

		$(document).bind('click', function(e) {
			var $clicked = $(e.target);
			if (! $clicked.parents().hasClass("nav-drop"))
				hideMenuItem();

			if (! $clicked.parent().hasClass("request_form_options")){
			  $("#canned_response_container").hide();
		  }
		});

      flash = $("div.flash_info");
      if(flash.get(0)){
         try{ closeableFlash(flash); } catch(e){}
      }
   });

})(jQuery);

function closeableFlash(flash){
   flash = jQuery(flash);
   jQuery("<a />").addClass("close").attr("href", "#").appendTo(flash).click(function(ev){
      flash.fadeOut(600);
   });
   setTimeout(function() {
      if(flash.css("display") != 'none')
         flash.hide('blind', {}, 500);
    }, 20000);
}