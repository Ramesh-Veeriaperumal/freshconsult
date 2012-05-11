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
    
 
   $.validator.addMethod("multiemail", function(value, element) {
       if (this.optional(element)) // return true on optional element
         return true;
       var emails = value.split( new RegExp( "\\s*,\\s*", "gi" ) );
       valid = true;
       $.each(emails, function(i, email){            
          valid=/^((([a-z]|\d|[!#\$%&'\*\+\-\/=\?\^_`{\|}~]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])+(\.([a-z]|\d|[!#\$%&'\*\+\-\/=\?\^_`{\|}~]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])+)*)|((\x22)((((\x20|\x09)*(\x0d\x0a))?(\x20|\x09)+)?(([\x01-\x08\x0b\x0c\x0e-\x1f\x7f]|\x21|[\x23-\x5b]|[\x5d-\x7e]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(\\([\x01-\x09\x0b\x0c\x0d-\x7f]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF]))))*(((\x20|\x09)*(\x0d\x0a))?(\x20|\x09)+)?(\x22)))@((([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])*([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])))\.)+(([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])*([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])))\.?$/i.test(email);                     
       });
       return valid;
   }, 'One or more email addresses are invalid.');
   $.validator.addClassRules("multiemail", { multiemail: true });
 
   $.validator.addMethod("hours", function(value, element) {
       hours = normalizeHours(value);
       element.value = hours;       
       return /^([0-9]*):([0-5][0-9])(:[0-5][0-9])?$/.test(hours);
   }, 'Please enter a valid hours.');
   $.validator.addClassRules("hours", { hours: true });
 	
	
	//Domain Name Validator 
   $.validator.addMethod("domain_validator", function(value, element) {
       if (this.optional(element)) // return true on optional element
         return true;
        if (value.length == 0) { return true; }       
     	if(/((http|https|ftp):\/\/)\w+/.test(value))
     	valid = false;
     	else if(/\w+[\-]\w+/.test(value))
     	valid = true;
        else if((/\W\w*/.test(value))) {
        valid = false;
        }
        else valid = true;
        if(/_+\w*/.test(value))
        valid = false;               
       return valid;
   }, 'Invalid URL format');
   $.validator.addClassRules("domain_validator", { domain_validator: true });
   
   //URL Validator
   $.validator.addClassRules("url_validator", { url : true });
   
       
	// App initialisation  
	$(document).ready(function() {
		var widgetPopup = null;   

		$("body").click(function(ev){
			if((widgetPopup != null) && !$(ev.target).parents().hasClass("popover")){
				widgetPopup.popover('hide');
				widgetPopup = null;
			}
		});
		
		$("a[rel=popover]")
			.popover({ 
				delayOut: 300,
				trigger: 'manual',
				offset: 5,
				html: true,
				reloadContent: false,
				template: '<div class="arrow"></div><div class="inner"><div class="content"><p></p></div></div>',
				content: function(){
					return $("#" + $(this).attr("data-widget-container")).html();
				}
			});
		
		$("a[rel=widget-popover]")
			.popover({ 
				delayOut: 300,
				trigger: 'manual',
				offset: 5,
				html: true,
				reloadContent: false,
				template: '<div class="arrow"></div><div class="inner"><div class="content"><p></p></div></div>',
				content: function(){
					return $("#" + $(this).attr("data-widget-container")).val();
				}
			})
			
		$("a[rel=popover], a[rel=widget-popover]").live("click", function(e){
				e.preventDefault();
				e.stopPropagation(); 
				$('[rel=widget-popover]').each(function(){
					$(this).popover('hide');
				});
 				widgetPopup = $(this).popover('show');
			});


      // - Labels with overlabel will act a Placeholder for form elements
      $("label.overlabel").livequery(function(){ $(this).overlabel(); });
 
      // - Custom select boxs will use a plugin called chosen to render with custom CSS and interactions
      $("select.customSelect").livequery(function(){ $(this).chosen(); });

      // - Quote Text in the document as they are being loaded
      $("div.request_mail").livequery(function(){ quote_text(this); }); 

      $("input.datepicker").livequery(function(){ $(this).datepicker($(this).data()) });
      
      // Any object with class custom-tip will be given a different tool tip
      $(".tooltip").twipsy({ live: true });
      // - jQuery Validation for forms with class .ui-form ( ...An optional dont-validate written for the form element will make the selectors ignore those form alone )
      validateOptions = {
         onkeyup: false,
         focusCleanup: true,
         focusInvalid: false
      };

      $(".form-tooltip").twipsy({ 
        live: true,
        trigger: 'focus',
        template: '<div class="twipsy-arrow"></div><div class="twipsy-inner big"></div>'
      });

      $('input[type=checkbox].iphone').each( function() {
        var el = $(this);
        var active_text = el.attr('data-active-text') || "Yes";
        var inactive_text = el.attr('data-inactive-text') || "No";
        el.wrap('<div class="stylised iphone" />');
        el = el.parent();
        el.append('<span class="text">' + active_text + '</span><span class="other"></span>');
        el.children('input[type=checkbox]').addClass('hide');

        el.bind('click', function(e) {
          e.preventDefault();
          e.stopPropagation(); 
          $(this).toggleClass('inactive');

          $(this).children('.text').text( $(this).hasClass('inactive') ? inactive_text : active_text);

          if ($(this).hasClass('inactive')) {
            $(this).children('input[type=checkbox]').removeAttr('checked');
          } else {
            $(this).children('input[type=checkbox]').attr('checked','checked');
          }
          
        });
      });
      
      $(".admin_list li")
         .hover(
            function(){ $(this).children(".item_actions").css("visibility", "visible"); }, 
            function(){ $(this).children(".item_actions").css("visibility", "hidden"); }
         );

      $("ul.ui-form").not(".dont-validate").parents('form:first').validate(validateOptions);
      $("div.ui-form").not(".dont-validate").find('form:first').validate(validateOptions); 
      $("form.uniForm").validate(validateOptions);
      $("form.ui-form").validate(validateOptions);

		$('.single_click_link').live('click',function(ev) {
			if (! $(ev.srcElement).is('a')) {
				window.location = $(this).find('a').first().attr('href');
			}
		});

    $("input[rel=companion]")
      .live({ 
        "keyup": function(ev){
          selector = $(this).data("companion");
          if($(this).data("companionEmpty")) $(selector).val(this.value);
        }, 
        "focus": function(ev){
          selector = $(this).data("companion");
          $(this).data("companionEmpty", ($(selector) && $(selector).val().strip() === ""));
        }
      });

		//Clicking on the row (for ticket list only), the check box is toggled.
		$('.tickets tbody tr').live('click',function(ev) {
      if (! $(ev.target).is('input[type=checkbox]') && ! $(ev.target).is('a')) {
				var checkbox = $(this).find('input[type=checkbox]').first();
				checkbox.prop('checked',!checkbox.prop('checked'));
			}
		});
		
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