/*
 * @author venom
 */
window.Helpdesk = window.Helpdesk || {};
(function ($) {
  Helpdesk.settings = {}   
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
    var insideCalendar = false;
    var closeCalendar = false;

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

    $("a.dialog2, a[data-ajax-dialog], button.dialog2").livequery(function(ev){
      $(this).dialog2();
    })
    
    //Added for social tweet links
    $(".autolink").livequery(function(ev){
      $(this).autoLink();
    })
    

    //Stickey Header and Button collapsed
    window.sticky = new SetupSticky();

    $('.menuselector').livequery(function(){$(this).menuSelector() })

    hideWidgetPopup = function(ev) {
      if((widgetPopup != null) && !$(ev.target).parents().hasClass("popover")){
        if(!insideCalendar)
        {
          widgetPopup.popover('hide');
          widgetPopup = null;
        }
      }
      if (closeCalendar)
      {
        insideCalendar = false;
        closeCalendar = false;
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
      $('[rel=widget-popover],[rel=contact-hover],[rel=hover-popover],[rel=more-agents-hover]').each(function(){
        if (ev.target != $(this).get(0))
          $(this).popover('hide');

        //Not hiding the popup if the current event is actually trying to trigger the same popup
        //That would result in Hiding the popover and immediately showing it again.
      });
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
        template: '<div class="arrow"></div><div class="inner"><div class="content"><div></div></div></div>',
        content: function(){
          return $("#" + $(this).attr("data-widget-container")).html();
        }
      });

    $("a[rel=click-popover-below-left]").livequery(function(){
      $(this).popover({
        delayOut: 300,
        trigger: 'manual',
        offset: 5,
        html: true,
        reloadContent: false,
        placement: 'belowLeft',
        template: '<div class="dbl_up arrow"></div><div class="hover_card inner"><div class="content ' + $("#" + $(this).attr("data-widget-container")).data('container-class') + '"><div></div></div></div>',
        content: function(){
          return $("#" + $(this).attr("data-widget-container")).html();
        }
      });
    });

    $("a[rel=widget-popover]")
      .popover({
        delayOut: 300,
        trigger: 'manual',
        offset: 5,
        html: true,
        reloadContent: false,
        template: '<div class="arrow"></div><div class="inner"><div class="content"><div></div></div></div>',
        content: function(){
          return $("#" + $(this).attr("data-widget-container")).val();
        }
      });
    $("[rel=more-agents-hover]").livequery(function(){
      if(typeof agentCollisionData != 'undefined')
        {
          $(this).popover({
            delayOut: 300,
            trigger: 'manual',
            offset: 5,
            html: true,
            reloadContent: false,
            template: '<div class="dbl_left arrow"></div><div class="hover_card hover-card-agent inner"><div class="content"><div></div></div></div>',
            content: function(){
                var container_id = "agent-info-div";
                var agentContent = '<ul id='+container_id+' class="fc-agent-info">';
                var chatIcon ='';
                var chatIconClose = '';

               if(typeof window.freshchat != 'undefined' && freshchat.chatIcon){
                  chatIcon ='<span class="active"><i class="ficon-message"></i></span> <a href="javascript:void(0)" class="tooltip"  title="Begin chat" data-placement="right">';
                  chatIconClose = '</a>';
                }
                agentCollisionData.forEach(function(data){
                    agentContent += '<li class ="agent_name" id="'+data.userId+'"> <strong>'+chatIcon +''+data.name +chatIconClose+'</strong></li>';
                });
                return agentContent+'</ul>';

            }
          });
        }
    });
    $("[rel=contact-hover]").livequery(function(){
      $(this).popover({
        delayOut: 300,
        trigger: 'manual',
        offset: 5,
        html: true,
        reloadContent: false,
        template: '<div class="dbl_left arrow"></div><div class="hover_card inner"><div class="content"><div></div></div></div>',
        content: function(){
          var container_id = "user-info-div-"+$(this).data('contactId');
          return jQuery("#"+container_id).html() || "<div class='sloading loading-small loading-block' id='"+container_id+"' rel='remote-load' data-url='"+$(this).data('contactUrl')+"'></div>";
        }
      });
    });


    $("a[rel=hover-popover-below-left]").livequery(function(){
      $(this).popover({ 
        delayOut: 300,
        offset: 5,
        trigger: 'manual',
        html: true,
        reloadContent: false,
        placement: 'belowLeft',
        template: '<div class="dbl_up arrow"></div><div class="hover_card inner"><div class="content ' + $("#" + $(this).attr("data-widget-container")).data('container-class') + '"><p></p></div></div>',
        content: function(){
          return $("#" + $(this).attr("data-widget-container")).val();
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
         template: '<div class="dbl_left arrow"></div><div class="hover_card inner"><div class="content"><div></div></div></div>',
         content: function(){
           return $(this).data("content") || $("#" + $(this).attr("data-widget-container")).val();
         }
        });
      });

    $("textarea.autosize").livequery(function(){
      $(this).autosize();
    });

    $("[rel=remote-load]").livequery(function(){
      if(!document.getElementById('remote_loaded_dom_elements'))
        $("<div id='remote_loaded_dom_elements' class='hide' />").appendTo("body");

      var $this = jQuery(this)

      $(this)
        .load($(this).data("url"), function(){
          $(this).attr("rel", "");
          $(this).removeClass("sloading loading-small loading-block");

          if(!$this.data("loadUnique"))
            $(this).clone().prependTo('#remote_loaded_dom_elements');

          if($this.data("extraLoadingClasses"))
            $(this).removeClass($this.data("extraLoadingClasses"));
        });
    });

    // Uses the date format specified in the data attribute [date-format], else the default one 'yy-mm-dd'
    $("input.datepicker_popover").livequery(function() {
      var dateFormat = 'yy-mm-dd';
      if($(this).data('date-format')) {
        dateFormat = $(this).data('date-format');
      }
      $(this).datepicker({
        dateFormat: dateFormat,
        beforeShow: function(){
          insideCalendar=true;
          closeCalendar=false;
        },
        onClose: function(){
          closeCalendar=true;
        }
      });
      if($(this).data('showImage')) {
        $(this).datepicker('option', 'showOn', "both" );
        $(this).datepicker('option', 'buttonText', "<i class='ficon-date'></i>" );
      }
    });

    $('input.datetimepicker_popover').livequery(function() {
      $(this).datetimepicker({
        timeFormat: "HH:mm:ss",
        dateFormat: 'MM dd,yy',
        beforeShow: function(){
          insideCalendar=true;
          closeCalendar=false;
        },
        onClose: function(){
          closeCalendar=true;
        }
      });
    });

    $("[rel=mouse-wheel]").livequery(function(){
      $(this).on('mousewheel DOMMouseScroll', function (ev) {
          if (ev.originalEvent) { ev = ev.originalEvent; }
          var delta = ev.wheelDelta || -ev.detail;
          this.scrollTop += (delta < 0 ? 1 : -1) * parseInt($(this).data("scrollSpeed"));
          ev.preventDefault();
      });
    })

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

      // - Labels with overlabel will act a Placeholder for form elements
      $("label.overlabel").livequery(function(){ $(this).overlabel(); });
      $(".nav-trigger").livequery(function(){ $(this).showAsMenu(); });
      $("input[rel=toggle]").livequery(function(){ $(this).itoggle(); });

      $("select.select2").livequery(function(){
          var defaults = {
            minimumResultsForSearch:    10  
          }
          $(this).select2($.extend( defaults, $(this).data()));
      });
      $("input.select2").livequery(function(){
        $(this).select2({tags: [],tokenSeparators: [","],
          formatNoMatches: function () {
           return "  ";
          }
        });
      });

      // - Quote Text in the document as they are being loaded
      $("div.request_mail").livequery(function(){ quote_text(this); });

      $("input.datepicker").livequery(function(){ $(this).datepicker( $.extend( {}, $(this).data() , { dateFormat: getDateFormat('datepicker') }  )) });

      $('.contact_tickets .detailed_view .quick-action').removeClass('dynamic-menu quick-action').attr('title','');
      $('.quick-action.ajax-menu').livequery(function() { $(this).showAsDynamicMenu();});
      $('.quick-action.dynamic-menu').livequery(function() { $(this).showAsDynamicMenu();});

      // - Tour My App 'Next' button change
      $(".tourmyapp-toolbar .tourmyapp-next_button").livequery(function(){
        if($(this).text() == "Next »")
           $(this).addClass('next_button_arrow').text('Next');
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

      $(".image-lazy-load img").livequery(function(ev){
          $(this).unveil(200, function() {
              this.style.opacity = 1;
          });
      });
      $("ul.ui-form, .cnt").livequery(function(ev){
        $(this).not(".dont-validate").parents('form:first').validate();
      })
      $("div.ui-form").livequery(function(ev){
        $(this).not(".dont-validate").find('form:first').validate();
      })
      // $("form.uniForm").validate(validateOptions);
      $("form.ui-form").livequery(function(ev){
        $(this).not(".dont-validate").validate();
      })
      // $("form[rel=validate]").validate(validateOptions);
      var validateOptions = {}
      validateOptions['submitHandler'] = function(form, btn) {
                                          // Setting the submit button to a loading state
                                          $(btn).button("loading")

                                          // IF the form has an attribute called data-remote then it will be submitted via ajax
                                          if($(form).data("remote")){
                                              $(form).ajaxSubmit({
                                                dataType: 'script',
                                                success: function(response, status){
                                                  // Resetting the submit button to its default state
                                                $(btn).button("reset");

                                                // If the form has an attribute called update it will used to update the response obtained
                                                  $("#"+$(form).data("update")).html(response)
                                                }
                                              })
                                          // For all other form it will be a direct page submission
                                          }else{
                                            setTimeout(function(){ 
                                              add_csrf_token(form);
                                              // Nullifies the form data changes flag, which is checked to prompt the user before leaving the page.
                                              $(form).data('formChanged', false);
                                              form.submit();
                                            }, 50)
                                          }
                                        }
      // Form validation any form append to the dom will be tested via live query and then be validated via jquery
      $("form[rel=validate]").livequery(function(ev){
        $(this).validate($.extend( validateOptions, $(this).data()))
      })

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

      flash = $("div.alert").not('[rel=permanent]');
      if(flash.get(0)){
         try{ closeableFlash(flash); } catch(e){}
      }

      $('body').on('click.freshdesk', '#scroll-to-top', function(ev) {
        $.scrollTo('body');
      })

      $('#Activity .activity > a').livequery(function() {
        $(this).attr('data-pjax', '#body-container')
      });
			
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
      
      $('[rel="select-choice"]').livequery(function(ev) {
        jQuery(this).select2({maximumSelectionSize: 10,removeOptionOnBackspace:false});
        var $select_content = $(this).siblings('.select2-container');
        var disableField = $(this).data('disableField');
        disableField = disableField.split(',');
        $select_content.find(".select2-search-choice div").each(function(index,element){
          value = jQuery(element).text();
          if($.inArray(value, disableField ) != -1) {
            jQuery(element).next("a").remove();
          }
        });
      })
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
}
