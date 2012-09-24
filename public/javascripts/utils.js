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
    if (source.width <= 50) {
      source.src = PROFILE_BLANK_THUMB_PATH;
    } else {
      source.src = PROFILE_BLANK_MEDIUM_PATH;
    }
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
          field.value = source.value;
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

function construct_reply_url(to_email, account_full_domain){
   email_split  = to_email.split("@");
   email_name   = email_split[0]||'';
   email_domain = email_split[1]||'';

   account_full_domain = account_full_domain.toLowerCase();
   reply_email  = "@"+account_full_domain;

   if(email_domain.toLowerCase() == account_full_domain){
      reply_email = email_name + reply_email;		
   }
   else{
      reply_email = email_domain.replace(/\./g,'') + email_name + reply_email;
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
             
                href = jQuery(this).data('url') || this.href;
            
               if(dialog == null){
                  dialog = $("<div class='loading-center' />")
                              .html("<br />")
                              .dialog({  modal:true, width: width, height:'auto', position:'top',
                                         title: this.title, resizable: false });

                   active_dialog = dialog.load(href,{}, function(responseText, textStatus, XMLHttpRequest) {
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
	if($(e.target).hasClass("chzn-results")) return;
  if ($(e.target).parent().is(".fd-ajaxmenu, .fd-ajaxmenu .contents")) { return };
    if($(this).data("active-menu")){
      if(!$(e.target).data("menu-active")) hideActiveMenu();
      else setTimeout(hideActiveMenu, 500);         
    } 
 });
 
 hideActiveMenu = function (){
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

  $.fn.showAsAjaxMenu = function(){
    this.each(function(i, node){

      $(node).bind("click", function(ev){
        ev.preventDefault();
        ev.stopPropagation();

        //Dynamic Menu count is just used to give an ID to the menus, so that they can be hidden properly.
        if ($(node).data('options-fetched') != true) {
          if (typeof($(document).data('dynamic-menu-count')) == "undefined") {
            $(document).data('dynamic-menu-count',0);
          }
          menuid = $(document).data('dynamic-menu-count') + 1;
          $(document).data('dynamic-menu-count',menuid);

          menu_container = $('<div>');
          menu_container.attr('id',"menu_" + menuid);
          menu_container.data('parent',$(node));
          menu_container.addClass('loading fd-ajaxmenu');
          menu_container.html('<div class="contents"></div>');
          menu_container.insertAfter($(node));

          $(node).data('menuid',"menu_" + menuid);

          $.ajax({
            url: $(node).data('options-url'),
            success: function (data, textStatus, jqXHR) {
              $('#menu_' + menuid).removeClass('loading');
              $('#menu_' + menuid + ' .contents').html(data);  

              //Setting the Active Element
              match_found = false;
              text_to_match = $(node).children('.result').first().text();
              $('#menu_' + menuid + ' .contents').children().each(function(i) {
                if (!found && $(this).data('text') == text_to_match || $(this).text() == text_to_match) {
                  $(this).addClass('active').prepend('<span class="icon ticksymbol"></span>');
                  match_found = true;
                }
              });


              $(node).data('options-fetched',true);
            }
          });
        }

        menu = $('#' + $(node).data('menuid'));
        menu.show().css('visibility','visible');
        $(document).data({ "active-menu": true, "active-menu-element": menu, "active-menu-parent": node });

        $(node).addClass("selected");
      });
    });
  };

  $.fn.showPreloadedMenu = function(){
    this.each(function(i, node){

      $(node).bind("click", function(ev){
        ev.preventDefault();
        ev.stopPropagation();

        if ($(node).data('options-fetched') != true) {
          if (typeof($(document).data('dynamic-menu-count')) == "undefined") {
            $(document).data('dynamic-menu-count',0);
          }
          menuid = $(document).data('dynamic-menu-count') + 1;
          $(document).data('dynamic-menu-count',menuid);
          menu_container = $('<div>').attr('id',"menu_" + menuid)
                          .addClass('loading fd-ajaxmenu')
                          .html('<div class="contents"></div>')
                          .data('parent',$(node));
                          
          menu_container.find('.contents').append($($(node).data('options')).html());
          menu_container.insertAfter($(node));
          $(node).data('menuid',"menu_" + menuid);
          $(node).data('options-fetched',true)
          menuid = "menu_" + menuid;

          text_to_match = $(node).children('.result').first().text();
          match_found = false;
          $('#' + menuid + ' .contents').children().each(function(i) {
            if (!match_found && ($(this).data('text') == text_to_match || $(this).text() == text_to_match)) {
              $(this).addClass('active').prepend('<span class="icon ticksymbol"></span>');
              match_found = true;
            }
          });

        } else {
          menuid = $(node).data('menuid');
        }
        menu = $('#' + menuid);
        menu.show().removeClass('loading').css('visibility','visible');
        $(document).data({ "active-menu": true, "active-menu-element": menu, "active-menu-parent": node });

        $(node).addClass("selected");
      });
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

  
  $.fn.animateHighlight = function(originalBg, highlightColor, duration) {
    var highlightBg = highlightColor || "#FFFF9C";
    var animateMs = duration || 1500;
    var originalBg = originalBg || 'transparent';
    var element_animated = $(this);
    element_animated.stop().css("background-color", highlightBg);
    element_animated.animate({backgroundColor: originalBg }, animateMs, function () {
      element_animated.css({'background-color':''});
    });
  };
 

})( jQuery );


setCookie = function (name,value,expires_in_days,path)
{
  var exdate=new Date();
  exdate.setDate(exdate.getDate() + expires_in_days);
  var c_value=escape(value) + ((expires_in_days==null) ? "" : "; expires="+exdate.toUTCString()) + '; path=' + ( (path ==null) ? '/' : path);
  document.cookie=name + "=" + c_value;
}

getCookie = function(name)
{
  var i,x,y,ARRcookies=document.cookie.split(";");
  for (i=0;i<ARRcookies.length;i++)
  {
    x=ARRcookies[i].substr(0,ARRcookies[i].indexOf("="));
    y=ARRcookies[i].substr(ARRcookies[i].indexOf("=")+1);
    x=x.replace(/^\s+|\s+$/g,"");
    if (x==name)
    {
      return unescape(y);
    }
  }
}
supports_html5_storage = function() {
  try {
    return 'localStorage' in window && window['localStorage'] !== null;
  } catch (e) {
    return false;
  }
}