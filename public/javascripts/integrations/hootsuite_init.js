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

      $('.freshdesk_quote').live('click', function(){
        var _container = jQuery(this).parents('.details');
        var _fd_quote = jQuery(this);
        if (_fd_quote.data('remoteQuote')){
          var _note_id = _container.data('note-id');
          var _messageDiv = _container.find('div:first');
          var options = {"force_quote": true};
          jQuery.ajax({
            url: '/integrations/hootsuite/tickets/full_text'+args,
            data: { id: ticketId, note_id: _note_id },
            success: function(response){
              if(response!=""){
                _messageDiv.html(response);

                quote_text(_messageDiv, options);
              }
              else {
                _container.find('div.freshdesk_quote').remove();
              }
            }
          });
        }
      });
  
   });
    
    var layzr;
    $(".image-lazy-load img").livequery(
      function(){
        layzr = new Layzr({
          container: null,
          selector: '.image-lazy-load img',
          attr: 'data-src',
          retinaAttr: 'data-src-retina',
          hiddenAttr: 'data-layzr-hidden',
          threshold: 0,
          callback: function(){
            $(".image-lazy-load img").css('opacity' , 1);
          }
        });
      },
      function() {
        layzr._destroy()
      }
    ); 

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