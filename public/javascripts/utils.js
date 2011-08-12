/**
 * @author venom
 * Genric core utility class for the application
 */

// Primarly for the form customizer page. Used for making the text unselectable
makePageNonSelectable = function(source){
	if (document.all) source.onselectstart = function () { return false; };	// Internet Explorer
	
	source.onmousedown = function () { return false; };						// Other browsers
};

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


 /*
  * JavaScript Pretty Date
  * Copyright (c) 2008 John Resig (jquery.com)
  * Licensed under the MIT license.
  */

// Takes an ISO time and returns a string representing how
// long ago the date represents.
function prettyDate(time){
 	var date = new Date((time || "").replace(/-/g,"/").replace(/[TZ]/g," ")),
 		diff = (((new Date()).getTime() - date.getTime()) / 1000),
 		day_diff = Math.floor(diff / 86400);

 	if ( isNaN(day_diff) || day_diff < 0 || day_diff >= 31 )
 		return;
 		
 	return day_diff == 0 && (
 			diff < 60 && "just now" ||
 			diff < 120 && "1 minute ago" ||
 			diff < 3600 && Math.floor( diff / 60 ) + " minutes ago" ||
 			diff < 7200 && "1 hour ago" ||
 			diff < 86400 && Math.floor( diff / 3600 ) + " hours ago") ||
 		day_diff == 1 && "Yesterday" ||
 		day_diff < 7 && day_diff + " days ago" ||
 		day_diff < 31 && Math.ceil( day_diff / 7 ) + " weeks ago";
 }


// JQuery plugin that customizes the dialog widget to load an ajax infomation
(function( $ ){

   var methods = {
        init : function( options ) {
          return this.each(function(){
            $this = $(this);
            var dialog = null;
            $this.click(function(e){
               e.preventDefault();
               if(dialog == null){
                  dialog = $("<div class='loading-center' />")
                              .html("<br />")
                              .dialog({  modal:true, width:'750px', height:'auto', position:'top', 
                                      // show: "blind", 
                                      // hide: 'blind', 
                                         title: this.title, resizable: false });

                   dialog.load(this.href,{}, function(responseText, textStatus, XMLHttpRequest) {
                      dialog.removeClass("loading-center");
                      dialog.css("height", "auto");
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
  
  $.fn.prettyDate = function(){
		return this.each(function(){
			var date = prettyDate(this.title);
			if ( date )
				$(this).text( date );
		});
	};

})( jQuery );