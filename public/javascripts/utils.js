/**
 * @author venom
 * Genric core utility class for the application
 */

function log(entry) {
  if (console) {
    console.log(entry);
  } else {
    alert(entry);
  }
}
function autoSaveTinyMce(editor){
   tinyMCE.triggerSave();
   return true;
}

function freshdate(str) {
  var month_names = ['January','February','March','April','May','June','July','August','September','October','November','December'];
  var d =  parseUTCDate(str);

  var date_part = month_names[d.getMonth()] + " " + d.getDate() + " " + d.getFullYear();
  var time_part = pad(d.getMinutes(),2);

  if (d.getHours() > 12) {
    time_part = (d.getHours() - 12) + ":" + time_part + " PM";
  } else{
    time_part = d.getHours() + ":" + time_part + " AM";
  }

  return date_part + " @ " + time_part;
}

function parseUTCDate(str) {
  var date_parts  = str.match(/(\d+)/g);
  return new Date(date_parts[0], date_parts[1]-1, date_parts[2], date_parts[3], date_parts[4], date_parts[5]);
}

function plural( count, text1, text2 ){
   return(count + " " + ((parseInt(count) > 1) ? text2 : text1))
}

function totalTime(listClass, updateId){
 total_hours = $$(listClass)
                .collect(function(t){ return t.innerHTML; })
                .inject(0, function(acc, n) { return parseFloat(acc) + parseFloat(n); });
 
 jQuery(updateId).html(sprintf( "%0.02f", total_hours));    
}

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

// Adding leading zeros to a number
function pad(number, length) {   
    var length = length || 2;
    var str = '' + number;
    while (str.length < length) {
        str = '0' + str;
    }   
    return str;
}

// Normalizing Hours
function normalizeHours(value){
   return value.split( new RegExp( "\\s*:\\s*", "gi" ) ).collect(function(s) {
     return pad(s);
   }).join(':')
   
}

// Getting Paramater Value
function getParameterByName(name, url)
{
  url = url || window.location.href;
  name = name.replace(/[\[]/, "\\\[").replace(/[\]]/, "\\\]");
  var regexS = "[\\?&]" + name + "=([^&#]*)";
  var regex = new RegExp(regexS);
  var results = regex.exec(url);
  if(results == null)
    return "";
  else
    return decodeURIComponent(results[1].replace(/\+/g, " "));
}

// Reorder show hide functions
function showSortableForm(buttonid, listid, formid){
	jQuery("#"+listid).hide();
	jQuery("#"+buttonid).hide();
	jQuery("#"+formid).fadeIn(300);
}

function hideSortableForm(buttonid, listid, formid){		
	jQuery("#"+listid).fadeIn(300);
	jQuery("#"+buttonid).show();
	jQuery("#"+formid).hide();
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

function helpdesk_submit(url, method, params){ 
   var form = $("tickets-expanded");
   if(method) form.down('input[name=_method]').value = method;

   (params || []).each(function(p){
      var source = $(p);
      var field = new Element('input', {
                     type: 'hidden',
                     value: source.value
                  });
          field.name = source.name;
          form.appendChild(field);
   });
   form.action = url;
   form.submit();
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

   // Quoted Addition show hide
   function quote_text(item){
      if (!jQuery(item).attr("data-quoted")) {
         var show_hide = jQuery("<a href='#' />").addClass("quoted_button").text(""), 
            child_quote = jQuery(item).find("div.freshdesk_quote").first().prepend(show_hide).children("blockquote.freshdesk_quote").hide();
            
            show_hide.bind("click", function(ev){
               ev.preventDefault();
               child_quote.toggle();
            });
            jQuery(item).removeClass("request_mail");
            jQuery(item).attr("data-quoted", true);	
      }
   }

active_dialog = null;

// JQuery plugin that customizes the dialog widget to load an ajax infomation
(function( $ ){
   var methods = {
        init : function( options ) {
          return this.each(function(i, item){
            curItem = $(item);
            var dialog = null;
            
            curItem.modal();
            curItem.click(function(e){
               e.preventDefault();
               width = $(this).data("width") || '750px';
               
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

 $(document).bind('mousedown', function(e) {
    if($(this).data("active-menu")){
      if(!$(e.target).data("menu-active")) hideActiveMenu();
      else setTimeout(hideActiveMenu, 500);         
    } 
 });
 
 function hideActiveMenu(){
    $($(document).data("active-menu-element")).hide().removeClass("active-nav-menu");
    $($(document).data("active-menu-parent")).removeClass("selected");
    $(document).data("active-menu", false);
 }

 $.fn.showAsMenu = function(id){
    this.each(function(i, node){
       if($(node).data("showAsMenu")) return; 
       
       $(node).bind("click", function(ev){
           ev.preventDefault(); 
           elementid = id || node.getAttribute("menuid");
           element = $(elementid).show().css("visibility", "visible"); 
           $(document).data({ "active-menu": true, "active-menu-element": element, "active-menu-parent": this });
           $(element).find("a, li").data("menu-active", true);
           $(node).addClass("selected");
        });
        $(node).data("showAsMenu", true);
     });
   };
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

(function( $ ){
   var methods = {
        init : function( options ) {
          return this.each(function(){
            $this = $(this);
            dialogid = this.id + "_dialog";
            dialogcontent = this.id + "_dialogcontent";            
            var dialog = null;
            $("body").prepend('<div id="'+dialogid+'" class="modal hide fade"><div class="modal-header"><a href="#" class="close"></a><h3 class="title">'+ this.title +'</h3></div><div id="'+dialogcontent+'"><p class="loading-box" ></p></div></div>');
            
            $("#"+dialogid).data({"content": dialogcontent, "href": $this.attr("href")});
            $this.attr("data-controls-modal", dialogid);
            $this.attr("data-backdrop", true);
            $this.attr("data-keyboard", true);
            
            $this.modal();
            
            $("#"+dialogid).bind('shown', function(){
               self = $(this)
               if(!self.attr("ajax-loaded")){
                  $("#"+self.data("content")).load(self.data("href"), {}, function(responseText, textStatus, XMLHttpRequest) { 
                     self.attr("ajax-loaded", true);                     
                     self.find('.close-dialog').click(function(){
                        self.modal("hide");
                     });
                  });
               }
            });
          });
        }
   };
   
  $.fn.modalAjax = function( method ) {    
    // Method calling logic
    if ( methods[method] ) {
      return methods[ method ].apply( this, Array.prototype.slice.call( arguments, 1 ));
    } else if ( typeof method === 'object' || ! method ) {
      return methods.init.apply( this, arguments );
    } else {
      $.error( 'Method ' +  method + ' does not exist on jQuery.dialog2' );
    }
  };

})( jQuery );