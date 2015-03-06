// no conflict check for jQuery
$j = jQuery.noConflict()

// Error handling for console.log
if (typeof console === "undefined" || typeof console.log === "undefined") {
    console = { };
    console.log = function() {
    };
}

function log() {
  var args = Array.prototype.slice.call(arguments);
  if (window.console && window.console.log && window.console.log.apply) {
    console.log(args.join(" "));
  } else {
    // alert(entry);
  }
}

// Image error issues
function imgerror(source){
    if (source.width <= 50) {
      source.src = portal['image_placeholders']['profile_thumb'];
    } else {
      source.src = portal['image_placeholders']['profile_medium'];
    }
    source.onerror = function(){ };
    return true;
}

function default_image_error(source){
  // The various types are attachment | logo | favicon
  var type_class = source.getAttribute('data-type') || "attachment",
      class_name = ['', 'no-image-placeholder', 'no-image-'.concat(type_class) ];
  source.src = portal['image_placeholders']['spacer'];
  source.className += class_name.join(" ");
  // source.onerror = "";

  return true;
}

// Additional util methods for support helpdesk
// Extending the string protoype to check if the entered string is a valid email or not
String.prototype.isValidEmail = function(){
    return (/^((([a-z]|\d|[!#\$%&'\*\+\-\/=\?\^_`{\|}~]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])+(\.([a-z]|\d|[!#\$%&'\*\+\-\/=\?\^_`{\|}~]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])+)*)|((\x22)((((\x20|\x09)*(\x0d\x0a))?(\x20|\x09)+)?(([\x01-\x08\x0b\x0c\x0e-\x1f\x7f]|\x21|[\x23-\x5b]|[\x5d-\x7e]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(\\([\x01-\x09\x0b\x0c\x0d-\x7f]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF]))))*(((\x20|\x09)*(\x0d\x0a))?(\x20|\x09)+)?(\x22)))@((([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])*([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])))\.)+(([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])*([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])))\.?$/i).test(this)
}

String.prototype.trim = function(){
    return this.replace(/^\s+|\s+$/g, '')
}

// Mobile checking utility inside javascript
var isMobile = {
    Android: function() {
        return navigator.userAgent.match(/Android/i);
    },
    BlackBerry: function() {
        return navigator.userAgent.match(/BlackBerry/i);
    },
    iOS: function() {
        return navigator.userAgent.match(/iPhone|iPad|iPod/i);
    },
    Opera: function() {
        return navigator.userAgent.match(/Opera Mini/i);
    },
    Windows: function() {
        return navigator.userAgent.match(/IEMobile/i);
    },
    any: function() {
        return (isMobile.Android() || isMobile.BlackBerry() || isMobile.iOS() || isMobile.Opera() || isMobile.Windows());
    }
};

// Layout resize util for portal
function layoutResize(layoutClass1, layoutClass2){
    "use strict"
    var mainbar = $j(layoutClass1).get(0),
        sidebar = $j(layoutClass2)

    // Remove sidebar if empty
    if (!$j.trim(sidebar.html())) sidebar.remove()

    sidebar = $j(layoutClass2).get(0)

    // If no sidebar is present make the main content to stretch to full-width
    if (!sidebar) {
        $j(mainbar).removeClass("main")
    }

    // If no mainbar is present make the sidebar content to stretch to full-width
    if (!mainbar) {
        $j(sidebar).removeClass("sidebar")
    }

    // Setting equal height for main & sidebar if both are present
    if (mainbar || sidebar) {
        $j(layoutClass1 + ", " + layoutClass2)
            .css("minHeight", Math.max($j(mainbar).outerHeight(true), $j(sidebar).outerHeight(true)))
    }
}

Number.prototype.toTime = function(format) {
  return (new Date())
          .clearTime()
          .addSeconds(this)
          .toString(format || "mm:ss");
}

window.highlight_code = function() {
    jQuery('[rel="highlighter"]').each(function(i,element){
        var brush,
            attr = jQuery(element).attr('code-brush');

        if(attr == 'html'){
            brush = 'js ; html-script: true';
        } else {
            brush = attr;
        }
        jQuery(element).attr('type','syntaxhighlighter').addClass('brush: ' + brush);
    })
    // when doubleclick the code highlighter its giving the text in a single line in IE(11).so this featur is disabled
    if( jQuery.browser.msie && parseInt(jQuery.browser.version, 10) == 11){
        SyntaxHighlighter.defaults['quick-code'] = false;
    }
    SyntaxHighlighter.all();
}

// Delay in typing of search text
var delay = (function(){
  var timer = 0;
  return function(callback, ms){
      clearTimeout (timer);
      timer = setTimeout(callback, ms);
  };
})();

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

