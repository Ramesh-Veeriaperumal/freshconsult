/*
 * @author venom
 */
window.Helpdesk = window.Helpdesk || {};
(function ($) {
  Helpdesk.settings = {}
  Helpdesk.calenderSettings = {
    insideCalendar : false,
    closeCalendar : false
  }
}(window.jQuery));

var $J = jQuery.noConflict();
is_touch_device = function() {
  return !!('ontouchstart' in window) // works on most browsers
      || !!('onmsgesturechange' in window); // works on ie10
};
window.xhrPool = [];
(function($){
    // IE 11
    if (!!navigator.userAgent.match(/^(?=.*\bTrident\b)(?=.*\brv\b).*$/)){
      $.browser = { msie: true, version: "11" };
      $('html').addClass('ie ie11');
    }
// Note - Browser detection code for edge.
 $.browser.edge = ( window.navigator.userAgent.indexOf("Edge") > 0 ) ? true : false;
 
   // Global Jquery Plugin initialisation
   // $.fn.qtip.baseIndex = 10000;

  // App initialisation
  $.oldajax = $.ajax;
  $.xhrPool_Abort  = function(){
    if(window.xhrPool)
    {
      for (var i = 0; i < window.xhrPool.length; i++) {
        window.xhrPool[i].abort();
      }
      window.xhrPool = [];
    }
  }
  $.ajax = function(options)
  {
    if(options.persist)
    {
      return $.oldajax(options);
    }
    else
    {
      var original_complete = options.complete || function(){};
      options.complete = function(xhr,status)
      {
        var index = window.xhrPool.indexOf(xhr)
        if(index> -1)
        {
          window.xhrPool.splice(index,1);
        }
        original_complete(xhr,status);
      }
      var xhr = $.oldajax(options);
      if (xhr) window.xhrPool.push(xhr);
      return xhr;
    }

  }
  $(document).ready(function() {
    var widgetPopup = null;
    var hoverPopup =  false;
    var hidePopoverTimer;

    if (is_touch_device()) {
      $('html').addClass('touch');
    }

    //IE10
    if ($.browser.msie && parseInt($.browser.version) == 10) {
      $('html').addClass('ie ie10');
    }

    $("body").click(function(ev){
      hideWidgetPopup(ev);
    });

    hideWidgetPopup = function(ev) {
      if((widgetPopup != null) && !$(ev.target).parents().hasClass("popover")){
        if(!Helpdesk.calenderSettings.insideCalendar)
        {
          widgetPopup.popover('hide');
          widgetPopup = null;
        }
      }
      if (Helpdesk.calenderSettings.closeCalendar)
      {
        Helpdesk.calenderSettings.insideCalendar = false;
        Helpdesk.calenderSettings.closeCalendar = false;
      }
    }

    hidePopover = function (ev) {
      if(!$.contains(this, ev.relatedTarget) ) {
        if(hoverPopup && !$(ev.relatedTarget).is('[rel=contact-hover]')) {
          hidePopoverTimer = setTimeout(function() {widgetPopup.popover('hide'); hoverPopup = false;},1000);
        }
        if(!$(ev.relatedTarget).is('[rel=more-agents-hover]')) {
          hidePopoverTimer = setTimeout(function() {$('.hover-card-agent').parent().remove(); },500);
        }
      }
    };

    hideActivePopovers = function (ev) {
      $('[rel=widget-popover],[rel=contact-hover],[rel=hover-popover],[rel=more-agents-hover],[rel=ff-alert-popover]').each(function(){
        if (ev.target != $(this).get(0))
          $(this).popover('hide');

        //Not hiding the popup if the current event is actually trying to trigger the same popup
        //That would result in Hiding the popover and immediately showing it again.
      });
    };

    $('div.popover').live('mouseleave',hidePopover).live('mouseenter',function (ev) {
      clearTimeout(hidePopoverTimer);
    });

    $("a[rel=popover], a[rel=widget-popover]")
      .popover({
        delayOut: 300,
        trigger: 'manual',
        offset: 5,
        html: true,
        reloadContent: false,
        template: '<div class="arrow"></div><div class="inner"><div class="content"><div></div></div></div>',
        content: function(){
          return $("#" + $(this).attr("data-widget-container")).html();
        }
      });
      
   $("a[rel=more-agents-hover]").live('mouseenter',function(ev) {
          ev.preventDefault();
          var element = $(this);
          // Introducing a slight delay so that the popover does not show up
          // when just passing thru this element.

          var timeoutDelayShow = setTimeout(function(){
            clearTimeout(hidePopoverTimer);
            hideActivePopovers(ev);
            widgetPopup = element.popover('show');
            hoverPopup = true;
          }, 300);
          element.data('timeoutDelayShow', timeoutDelayShow);

        }).live('mouseleave',function(ev) {
            clearTimeout($(this).data('timeoutDelayShow'));
            hidePopoverTimer = setTimeout(function() {
              $('.hover-card-agent').parent().remove();
            },1000);
      });

    $("a[rel=contact-hover],[rel=hover-popover]").live('mouseenter',function(ev) {
        ev.preventDefault();
        var element = $(this);
        // Introducing a slight delay so that the popover does not show up
        // when just passing thru this element.
        var timeoutDelayShow = setTimeout(function(){
          clearTimeout(hidePopoverTimer);
          hideActivePopovers(ev);
          widgetPopup = element.popover('show');
          hoverPopup = true;
        }, 500);
        element.data('timeoutDelayShow', timeoutDelayShow);

      }).live('mouseleave',function(ev) {
          clearTimeout($(this).data('timeoutDelayShow'));
          hidePopoverTimer = setTimeout(function() {
            if(widgetPopup) widgetPopup.popover('hide');
            hoverPopup = false;
          },1000);
      });
    $("[rel=ff-alert-popover]").live('mouseenter',function(ev) {
        ev.preventDefault();
        var element = $(this);
        // Introducing a slight delay so that the popover does not show up
        // when just passing thru this element.
        var timeoutDelayShow = setTimeout(function(){
          clearTimeout(hidePopoverTimer);
          hideActivePopovers(ev);
          widgetPopup = element.popover('show');
          hoverPopup = true;
        }, 500);
        element.data('timeoutDelayShow', timeoutDelayShow);

      }).live('mouseleave',function(ev) {
            clearTimeout($(this).data('timeoutDelayShow'));
            hidePopoverTimer = setTimeout(function() {
              $('.hover-card-agent').parent().remove();
            },300);
      });  
    $("a[rel=ff-hover-popover]").live('mouseenter',function(ev) {
          ev.preventDefault();
          if(!freshfoneuser.online){ return;}
          var element = $(this);
          // Introducing a slight delay so that the popover does not show up
          // when just passing thru this element.
          var timeoutDelayShow = setTimeout(function(){
            clearTimeout(hidePopoverTimer);
            hideActivePopovers(ev);
            widgetPopup = element.popover('show');
            hoverPopup = true;
          }, 300);
          element.data('timeoutDelayShow', timeoutDelayShow);

        }).live('mouseleave',function(ev) {
            clearTimeout($(this).data('timeoutDelayShow'));
            hidePopoverTimer = setTimeout(function() {
              $('.hover-card-agent').parent().remove();
            },1000);
      });

    $("a[rel=widget-popover], a[rel=click-popover-below-left]").live("click", function(e){
        e.preventDefault();
        e.stopPropagation();
        clearTimeout(hidePopoverTimer);
        hoverPopup = false;
        hideActivePopovers(e);
        widgetPopup = $(this).popover('show');
      });

    $("body").on('input propertychange', 'textarea[maxlength]', function() {
        var maxLength = $(this).attr('maxlength');
        if ($(this).val().length > maxLength) {
            $(this).val($(this).val().substring(0, maxLength));
        }
    });

      // !PULP to be moved into the pulp framework as a sperate util or plugin function
      $('body').on('afterShow', '[rel=remote]', function(ev) {
          var _self = $(this);
          if(!_self.data('loaded')) {
            _self.append("<div class='sloading loading-small loading-block'></div>");
            _self.load(_self.data('remoteUrl'), function(){
                _self.data('loaded', true);
                _self.trigger('remoteLoaded');
            });
          }
      });

      $('body').on('reload', '[rel=remote]', function(ev) {
        var _self = $(this);
        _self.empty();
        _self.data('loaded', false);
        _self.trigger('afterShow');
      });

      // Any object with class custom-tip will be given a different tool tip
      $(".tooltip").twipsy({ live: true });

      $(".full-width-tooltip").twipsy({
        live: true,
        template: '<div class="twipsy-arrow"></div><div class="twipsy-inner big"></div>'
      });

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

      $.validator.setDefaults({
        errorPlacement: function(error, element) {
          if (element.prop("type") == "checkbox" || element.hasClass("portal-logo") || element.hasClass("portal-fav-icon")){
            error.insertAfter(element.parent());
          } else {
            error.insertAfter(element);
          }
        },
        onkeyup: false,
        focusCleanup: false,
        focusInvalid: true,
        ignore:"select.nested_field:empty, .portal_url:not(:visible), .ignore_on_hidden:not(:visible)"
      });

      
      

    $('.single_click_link').live('click',function(ev) {
      if (! $(ev.srcElement).is('a')) {
        window.location = $(this).find('a').first().attr('href');
      }
    });

    $('#helpdesk_ticket_status').live('change', function(){
      var required_closure_elements = $(".required_closure");
      if(required_closure_elements.length == 0)
        return
      var ticket_status = $('#helpdesk_ticket_status option:selected').val();
      if(ticket_status === "5" || ticket_status === "4" ){
        required_closure_elements.each(function(){
          element = $(this)
          if(element.prop("type") == "checkbox")
            element.prev().remove()
          element.parents('.field').children('label').find('.required_star').remove();
          element.addClass('required').parents('.field').children('label').append('<span class="required_star">*</span>');
        })
      }
      else{
        required_closure_elements.each(function(){
          element = $(this)
          element.removeClass('required');
          element.siblings('label.error').remove();
          element.parents('.field').children('label').find('.required_star').remove();
          if(element.prop("type") == "checkbox" && element.prev().attr('name') != element.attr('name')){
            var hidden_checkbox_input = FactoryUI.hidden(element.attr('name'), "0")
            element.before(hidden_checkbox_input)
            element.parent().siblings('label.error').remove()
          }
        })
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

      // Tab auto select based on window hash url
      hashTabSelect();

      $(window).on('hashchange', hashTabSelect);

        qtipPositions = {
          normal : {
            my: 'center right',
            at: 'center left'
          },
          top: {
            my: 'bottom center',  // Position my top left...
            at: 'top center' // at the bottom right of...
          },
          bottom : {
            my: 'top center',  // Position my top left...
            at: 'bottom center'
          },
          left : {
            my: 'top left',
            at: 'bottom  left'
          }
        };

        $('.custom-tip, .custom-tip-top, .custom-tip-left, .custom-tip-bottom').live('mouseenter', function(ev) {
          config_position = qtipPositions['normal'];

          var classes = jQuery(this).data('tip-classes') || '';

          if ($(this).hasClass('custom-tip-top')) {
            config_position = qtipPositions['top'];
          }
          if ($(this).hasClass('custom-tip-bottom')) {
            config_position = qtipPositions['bottom'];
          }
          if ($(this).hasClass('custom-tip-left')) {
            config_position = qtipPositions['left'];
          }
          config_position['viewport'] = jQuery(window);

          $(this).qtip({
            overwrite: false,
            position: config_position,
            style: {
              classes : 'ui-tooltip-rounded ui-tooltip-shadow ' + classes,
              tip: {
                mimic: 'center'
              }
            },
            show: {
              event: ev.type,
              ready: true,
              delay: 300
            }
          }, ev);


        }).each(function(i) {
          $.attr(this, 'oldtitle', $.attr(this, 'title'));
          this.removeAttribute('title');
        })

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

      var flash = $("div.alert").not('[rel=permanent]');
      if(flash.get(0)){
         try{ closeableFlash(flash); } catch(e){}
      }

      $('body').on('click.freshdesk', '#scroll-to-top', function(ev) {
        $.scrollTo('body');
      })


			
			$(window).on("scroll.select2", function(ev) {
			    $(".select2-container.select2-dropdown-open").not($(this)).select2('positionDropdown');
			});

      // If there are some form changes that is unsaved, it prompts the user to save before leaving the page.
      $(window).on('beforeunload', function(ev){
        var form = $('.form-unsaved-changes-trigger');
        if(form.data('formChanged')) {
          ev.preventDefault();
          return customMessages.confirmNavigate;
        }
      });

      $('.form-unsaved-changes-trigger').on('change', function() {
        $(this).data('formChanged', true);
      });
      
      
   });
})(jQuery);

function closeableFlash(flash){
   flash = jQuery(flash);
   jQuery("<a />").addClass("close").attr("href", "#").appendTo(flash).click(function(ev){
      flash.fadeOut(600);
      return false;
   });
   setTimeout(function() {
      if(flash.css("display") != 'none')
         flash.hide('blind', {}, 500);
    }, 20000);
    setTimeout(function() {      
      flash.find("a").remove();
      delete flash.find("a");
      delete flash.prevObject;
    }, 20700);
}
