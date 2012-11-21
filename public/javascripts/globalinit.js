/*
 * @author venom
 */
var $J = jQuery.noConflict();
 
(function($){
   // Global Jquery Plugin initialisation
   // $.fn.qtip.baseIndex = 10000;   
       
  // App initialisation  
  $(document).ready(function() {
    var widgetPopup = null;
    var hoverPopup =  false;
    var hidePopoverTimer;

    $("body").click(function(ev){
      hideWidgetPopup(ev);
    });

    hideWidgetPopup = function(ev) {
      if((widgetPopup != null) && !$(ev.target).parents().hasClass("popover")){
        widgetPopup.popover('hide');
        widgetPopup = null;
      }
    }

    hidePopover = function (ev) {  
      if(!$.contains(this, ev.relatedTarget) ) { 
        if(hoverPopup && !$(ev.relatedTarget).is('[rel=contact-hover]')) {
          hidePopoverTimer = setTimeout(function() {widgetPopup.popover('hide'); hoverPopup = false;},1000);
        }
      }
    };

    $('div.popover').live('mouseleave',hidePopover).live('mouseenter',function (ev) {
      clearTimeout(hidePopoverTimer);
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
      });

    $("[rel=contact-hover]").livequery(function(){ 
      $(this).popover({ 
        delayOut: 300,
        trigger: 'manual',
        offset: 5,
        html: true,
        reloadContent: false,
        template: '<div class="dbl_left arrow"></div><div class="hover_card inner"><div class="content"><p></p></div></div>',
        content: function(){
          var container_id = "user-info-div-"+$(this).data('contactId');
          return jQuery("#"+container_id).html() || "<div class='loading-box' id='"+container_id+"' rel='remote-load' data-url='"+$(this).data('contactUrl')+"'></div>";
        }
      }); 
    });

    $("[rel=hover-popover]").livequery(function(){ 
       $(this).popover({ 
         delayOut: 300,
         trigger: 'manual',
         offset: 5,
         html: true,
         reloadContent: false,
         template: '<div class="dbl_left arrow"></div><div class="hover_card inner"><div class="content"><p></p></div></div>',
         content: function(){
           return $(this).data("content") || $("#" + $(this).attr("data-widget-container")).val();
         }
        }); 
      });

    $("[rel=remote-load]").livequery(function(){ 
      if(!document.getElementById('remote_loaded_dom_elements'))
        $("<div id='remote_loaded_dom_elements' class='hide' />").appendTo("body");

        $(this)
        .load($(this).data("url"), function(){
          $(this).attr("rel", "");
          $(this).removeClass("loading-box");
          $(this).clone().prependTo('#remote_loaded_dom_elements');          
        });
    });

      $("a[rel=contact-hover]").live('mouseenter',function(ev) {
        ev.preventDefault();
        hideWidgetPopup(ev);
        widgetPopup = $(this).popover('show');
        hoverPopup = true;
      }).live('mouseleave',function(ev) {
          hidePopoverTimer = setTimeout(function() {widgetPopup.popover('hide'); hoverPopup = false;},1000);
      });

      $("[rel=hover-popover]").live('mouseenter',function(ev) {
        ev.preventDefault();
        hideWidgetPopup(ev);
        widgetPopup = $(this).popover('show');
        hoverPopup = true;
      }).live('mouseleave',function(ev) {
          hidePopoverTimer = setTimeout(function() { widgetPopup.popover('hide'); hoverPopup = false;},1000);
      });

    $("a[rel=widget-popover]").live("click", function(e){
        e.preventDefault();
        e.stopPropagation(); 
        clearTimeout(hidePopoverTimer);
        hoverPopup = false;
        $('[rel=widget-popover],[rel=contact-hover],[rel=hover-popover]').each(function(){
          $(this).popover('hide');
        });
        widgetPopup = $(this).popover('show');
      });

      // - Labels with overlabel will act a Placeholder for form elements
      $("label.overlabel").livequery(function(){ $(this).overlabel(); });
      $(".nav-trigger").livequery(function(){ $(this).showAsMenu(); });
      $("input[rel=toggle]").livequery(function(){ $(this).itoggle(); });
 
      // - Custom select boxs will use a plugin called chosen to render with custom CSS and interactions
      $("select.customSelect").livequery(function(){ $(this).chosen(); });

      // - Quote Text in the document as they are being loaded
      $("div.request_mail").livequery(function(){ quote_text(this); }); 

      $("input.datepicker").livequery(function(){ $(this).datepicker($(this).data()) });

      $('.quick-action.ajax-menu').livequery(function() { $(this).showAsDynamicMenu();});
      $('.quick-action.dynamic-menu').livequery(function() { $(this).showAsDynamicMenu();});

      // - Tour My App 'Next' button change
      $(".tourmyapp-toolbar .tourmyapp-next_button").livequery(function(){ 
        if($(this).text() == "Next »")
           $(this).addClass('next_button_arrow').text('Next');
      });

      // - Tour My App 'slash' replaced by 'of'
      $('.tourmyapp-step-index').livequery(function() { 
        $(this).text($(this).text().replace('/',' of '));
      });

      // !PULP to be moved into the pulp framework as a sperate util or plugin function
      $("[rel=remote]").livequery(function(){
        $(this).bind("afterShow", function(ev){
          var _self = $(this);
          if(_self.data('remoteUrl'))
            _self.append("<div class='loading-box'></div>");
            _self.load(_self.data('remoteUrl'), function(){
                _self.data('remoteUrl', false);
            });
        });
      });
      
      // Any object with class custom-tip will be given a different tool tip
      $(".tooltip").twipsy({ live: true });

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

      // - jQuery Validation for forms with class .ui-form ( ...An optional dont-validate written for the form element will make the selectors ignore those form alone )
      validateOptions = {
         onkeyup: false,
         focusCleanup: true,
         focusInvalid: false,
         ignore:":not(:visible)"
      };
      
      $("ul.ui-form").not(".dont-validate").parents('form:first').validate(validateOptions);
      $("div.ui-form").not(".dont-validate").find('form:first').validate(validateOptions); 
      $("form.uniForm").validate(validateOptions);
      $("form.ui-form").validate(validateOptions);
      $("form[rel=validate]").validate(validateOptions);

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

        if(window.location.hash != '')
          $(window.location.hash + "-tab").trigger('click');
         
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
            
         $('[rel=guided-tour]').live('click',function(ev) {
          ev.preventDefault();
          try {
            tour.run($(this).data('tour-id'),true);
          } catch(e) { }
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

      if(jQuery.browser.opera){
        jQuery('.top-loading-strip').switchClass('top-loading-strip', 'top-loading-strip-opera');  
      }

      $(document).pjax('a[data-pjax]',"#body-container",{
          timeout: -1
        }).bind('pjax:beforeSend',function(evnt,xhr,settings){
          start_time = new Date();
          var bHeight = $('#body-container').height(),
              clkdLI = $(evnt.relatedTarget).parent();
          $('ul.header-tabs li.active').removeClass('active');
          clkdLI.addClass('active');
          jQuery('.top-loading-wrapper').switchClass('fadeOutRight','fadeInLeft',100,'easeInBounce',function(){
            jQuery('.top-loading-wrapper').removeClass('hide');
          });
          // $('#body-container .wrapper').css('visibility','hidden');
          $(document).trigger('ticket_list');
          $(document).trigger('ticket_show');
          return true;
      }).bind('pjax:end',function(){
        //$('.load-mask').hide();
        jQuery('.top-loading-wrapper').switchClass('fadeInLeft','fadeOutRight');
        jQuery('.top-loading-wrapper').addClass('hide','slow');
        // $('#body-container .wrapper').css('visibility','visible');
        end_time = new Date();
        setTimeout(function() {
          $('#benchmarkresult').html('Finnally This page took ::: <b>'+(end_time-start_time)/1000+' s</b> to load.') 
        },10);
        return true;
      })

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