(function($){

  $(document).ready(function() {
    var widgetPopup = null;
    var hoverPopup =  false;
    var hidePopoverTimer;

   
    $("body").click(function(ev){
      hideWidgetPopup(ev);
    });


    hideWidgetPopup = function(ev) {
      if((widgetPopup != null) && !$(ev.target).parents().hasClass("popover")){
        if(!insideCalendar)
        {
          widgetPopup.popover('hide');
          widgetPopup = null;
        }
      }
    }

    hidePopover = function (ev) {
      if(!$.contains(this, ev.relatedTarget) ) {
        hidePopoverTimer = setTimeout(function() {$('.hover-card-agent').parent().remove(); },500);
      }
    };

    hideActivePopovers = function (ev) {
      $('[rel=hover-popover]').each(function(){
        if (ev.target != $(this).get(0))
          $(this).popover('hide');

        //Not hiding the popup if the current event is actually trying to trigger the same popup
        //That would result in Hiding the popover and immediately showing it again.
      });
    };

    $('div.popover').live('mouseleave',hidePopover).live('mouseenter',function (ev) {
      clearTimeout(hidePopoverTimer);
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



    $("[rel=hover-popover]").live('mouseenter',function(ev) {
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
  
   });
    
    $(".image-lazy-load img").livequery(function(ev){
        $(this).unveil(200, function() {
            this.style.opacity = 1;
        });
    });

    function quote_text(item, options){
        options = options || {}
        if (!jQuery(item).attr("data-quoted") || options["force_quote"]) {
         var show_hide = jQuery("<a href='#' title='Show quoted text'/>").addClass("q-marker tooltip").text(""),
            child_quote = jQuery(item).find("div.freshdesk_quote").first().prepend(show_hide).children("blockquote.freshdesk_quote")

            if(!options["force_quote"]){
              child_quote.hide();
            }
            show_hide.bind("click", function(ev){
               ev.preventDefault();
               child_quote.toggle();
            });
            jQuery(item).removeClass("request_mail");
            jQuery(item).attr("data-quoted", true);
      }
   }

    $(".helpdesk_note .details").livequery(function(){ quote_text(this); });
  
})(jQuery);