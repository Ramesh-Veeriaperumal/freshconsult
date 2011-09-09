/**
 * @author venom
 * Genric core utility class for the application
 */

// Primarly for the form customizer page. Used for making the text unselectable
makePageNonSelectable = function(source){
	if (document.all) source.onselectstart = function () { return false; };	// Internet Explorer
	
	source.onmousedown = function () { return false; };						// Other browsers
};

//Image error problem
function imgerror(source){
    source.src = "/images/fillers/profile_blank_thumb.gif";
    source.onerror = "";
    return true;
}

//Bitly url shortner
function get_short_url(long_url, callback)
{
    jQuery.getJSON(
        "http://api.bitly.com/v3/shorten?callback=?", 
        { 
            "format": "json",
            "apiKey": "R_8ae5a67d8d9930440f0d1d4b794332f0",
            "login": "freshdesk",
            "longUrl": long_url
        },
        function(response)
        {
            callback(response.data.url);
        }
    );
}

// Delay in typing of search text
var delay = (function(){
	var timer = 0;
	return function(callback, ms){
	    clearTimeout (timer);
	    timer = setTimeout(callback, ms);
	};
})();

// Inserting Text at the place where a cursor is currently
function insertTextAtCursor(el, text) {
    var val = el.value, endIndex, range;
    if (typeof el.selectionStart != "undefined" && typeof el.selectionEnd != "undefined") {
        endIndex = el.selectionEnd;
        el.value = val.slice(0, endIndex) + text + val.slice(endIndex);
        el.selectionStart = el.selectionEnd = endIndex + text.length;
    } else if (typeof document.selection != "undefined" && typeof document.selection.createRange != "undefined") {
        el.focus();
        range = document.selection.createRange();
        range.collapse(false);
        range.text = text;
        range.select();
    }
}

function setSelRange(inputEl, selStart, selEnd) { 
	 if (inputEl.setSelectionRange) { 
	  inputEl.focus(); 
	  inputEl.setSelectionRange(selStart, selEnd); 
	 } else if (inputEl.createTextRange) { 
	  var range = inputEl.createTextRange(); 
	  range.collapse(true); 
	  range.moveEnd('character', selEnd); 
	  range.moveStart('character', selStart); 
	  range.select(); 
	 } 
}

function setCaretToPos(input, pos) {
  setSelRange(input, pos, pos);
}

function construct_reply_url(to_email, account_name){
   email_split  = to_email.split("@");
   email_name   = email_split[0]||'';
   email_domain = email_split[1]||'';
   if(email_domain !== ''){
      email_domain = email_domain.split(".")[0];
   }
   account_name = account_name.toLowerCase();
   reply_email  = "@"+account_name;

   if(email_domain.toLowerCase() == account_name){
      reply_email = email_name + reply_email;		
   }
   else{
      reply_email = email_domain + email_name + reply_email;
   }
   return reply_email;
}

active_dialog = null;

// JQuery plugin that customizes the dialog widget to load an ajax infomation
(function( $ ){

   var methods = {
        init : function( options ) {
          return this.each(function(){
            $this = $(this);
            var dialog = null;
            $this.click(function(e){
               e.preventDefault();
               width = $this.attr("dialogWidth") || '750px';
               
               if(dialog == null){
                  dialog = $("<div class='loading-center' />")
                              .html("<br />")
                              .dialog({  modal:true, width: width, height:'auto', position:'top',
                                         title: this.title, resizable: false });

                   active_dialog = dialog.load(this.href,{}, function(responseText, textStatus, XMLHttpRequest) {
                                                   dialog.removeClass("loading-center");
                                                   dialog.css({"height": "auto"});
                                                });
               }else{
                  dialog.dialog("open");
               }
            });
          });
        },
        destroy : function( ) {
          return this.each(function(){
            var $this = $(this),
                data = $this.data('dialog2');
            // Namespacing FTW
            $(window).unbind('.dialog2');
            data.tooltip.remove();
            $this.removeData('dialog2');
          })
        },
        show : function( ) { },
        hide : function( ) { },
        update : function( content ) { }
   };
   
  $.fn.dialog2 = function( method ) {    
    // Method calling logic
    if ( methods[method] ) {
      return methods[ method ].apply( this, Array.prototype.slice.call( arguments, 1 ));
    } else if ( typeof method === 'object' || ! method ) {
      return methods.init.apply( this, arguments );
    } else {
      $.error( 'Method ' +  method + ' does not exist on jQuery.dialog2' );
    }
  };
  
  // usage: $('p').autoLink()
  $.fn.autoLink = function() {
    this.contents()
      .filter(function() { return this.nodeType === 3})
      .each(function(i, node) {
        if (node.nodeValue.match(/https?:/)) {
          $(node).replaceWith(
            node.nodeValue.replace(/(https?:\/\/\S+)/g, "<a href=\"$1\" target=\"_blank\">$1</a>")
          );
        }
      }
    );
    return this;
  }; 
  
  $.fn.limit = function( limit, element ) {
     var interval, f;
     var self = $(this);

     $(this).focus(function(){ interval = window.setInterval(substring,100); });

     $(this).blur(function(){
        clearInterval(interval);
        substring();
     });

     substringFunction = "function substring(){ var val = $(self).val();var length = val.length;if(length > limit){$(self).val($(self).val().substring(0,limit));}";
     
     if(typeof element != 'undefined')
      substringFunction += "if($(element).html() != limit-length){$(element).html((limit-length<=0)?'0':limit-length);}"
      
      substringFunction += "}";

     eval(substringFunction);

     substring();
     
     return this;
  } 
  
  // jQuery autoGrowInput plugin by James Padolsey
  // See related thread: http://stackoverflow.com/questions/931207/is-there-a-jquery-autogrow-plugin-for-text-fields
  $.fn.autoGrowInput = function(o) {
  
    o = $.extend({
        maxWidth: 1000,
        minWidth: 0,
        comfortZone: 70
    }, o);
    
    this.filter('input:text').each(function(){
        
        var minWidth = o.minWidth || $(this).width(),
            val = '',
            input = $(this),
            testSubject = $('<tester/>').css({
                position: 'absolute',
                top: -9999,
                left: -9999,
                width: 'auto',
                fontSize: input.css('fontSize'),
                fontFamily: input.css('fontFamily'),
                fontWeight: input.css('fontWeight'),
                letterSpacing: input.css('letterSpacing'),
                whiteSpace: 'nowrap'
            }),
            check = function() {
                
                if (val === (val = input.val())) {return;}
                
                // Enter new content into testSubject
                var escaped = val.replace(/&/g, '&amp;').replace(/\s/g,'&nbsp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
                testSubject.html(escaped);
                
                // Calculate new width + whether to change
                var testerWidth = testSubject.width(),
                    newWidth = (testerWidth + o.comfortZone) >= minWidth ? testerWidth + o.comfortZone : minWidth,
                    currentWidth = input.width(),
                    isValidWidthChange = (newWidth < currentWidth && newWidth >= minWidth)
                                         || (newWidth > minWidth && newWidth < o.maxWidth);
                
                // Animate width
                if (isValidWidthChange) {
                    input.width(newWidth);
                }
                
            };
            
        testSubject.insertAfter(input);
        
        $(this).bind('keyup keydown blur update', check);
        
    });
    
    return this;
    
  };

})( jQuery );