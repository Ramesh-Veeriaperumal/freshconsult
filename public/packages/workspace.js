makePageNonSelectable=function(a){if(document.all)a.onselectstart=function(){return!1};a.onmousedown=function(){return!1}};var delay=function(){var a=0;return function(b,e){clearTimeout(a);a=setTimeout(b,e)}}();
function insertTextAtCursor(a,b){var e=a.value,c;if(typeof a.selectionStart!="undefined"&&typeof a.selectionEnd!="undefined")c=a.selectionEnd,a.value=e.slice(0,c)+b+e.slice(c),a.selectionStart=a.selectionEnd=c+b.length;else if(typeof document.selection!="undefined"&&typeof document.selection.createRange!="undefined")a.focus(),e=document.selection.createRange(),e.collapse(!1),e.text=b,e.select()}
function setSelRange(a,b,e){a.setSelectionRange?(a.focus(),a.setSelectionRange(b,e)):a.createTextRange&&(a=a.createTextRange(),a.collapse(!0),a.moveEnd("character",e),a.moveStart("character",b),a.select())}function setCaretToPos(a,b){setSelRange(a,b,b)}window.fdUtil={make_defined:function(){$A(arguments).each(function(){})}};
window.FactoryUI={text:function(a,b,e,c){return jQuery("<input type='text' name='"+(b||"")+"' class='"+(c||"text")+"' placeholder='"+(a||"")+"' value='"+(e||"")+"' />")},dropdown:function(a,b,e){if(a){var c="<select name='"+(b||"")+"' class='"+(e||"dropdown")+"' >";a.each(function(a){c+="<option value='"+a.name+"'>"+a.value+"</option>"});c+="</select>";return jQuery(c)}},paragraph:function(a,b,e,c){return jQuery("<textarea type='text' name='"+(b||"")+"' class='"+(c||"paragraph")+"' placeholder='"+
(a||"")+"'>"+(e||"")+"</textarea>")},checkbox:function(a,b,e,c){b=b||"";return jQuery("<label class='"+(c||"checkbox")+"'><input type='hidden' name='"+b+"' value=false /><input type='checkbox' name='"+b+"' "+(e=="true"?"checked":"")+" value=true />"+(a||"")+"</label>")}};var JSON;JSON||(JSON={});
(function(){function a(a){return a<10?"0"+a:a}function b(a){o.lastIndex=0;return o.test(a)?'"'+a.replace(o,function(a){var b=p[a];return typeof b==="string"?b:"\\u"+("0000"+a.charCodeAt(0).toString(16)).slice(-4)})+'"':'"'+a+'"'}function e(a,c){var i,f,j,l,m=h,g,d=c[a];d&&typeof d==="object"&&typeof d.toJSON==="function"&&(d=d.toJSON(a));typeof k==="function"&&(d=k.call(c,a,d));switch(typeof d){case "string":return b(d);case "number":return isFinite(d)?String(d):"null";case "boolean":case "null":return String(d);
case "object":if(!d)return"null";h+=n;g=[];if(Object.prototype.toString.apply(d)==="[object Array]"){l=d.length;for(i=0;i<l;i+=1)g[i]=e(i,d)||"null";j=g.length===0?"[]":h?"[\n"+h+g.join(",\n"+h)+"\n"+m+"]":"["+g.join(",")+"]";h=m;return j}if(k&&typeof k==="object"){l=k.length;for(i=0;i<l;i+=1)typeof k[i]==="string"&&(f=k[i],(j=e(f,d))&&g.push(b(f)+(h?": ":":")+j))}else for(f in d)Object.prototype.hasOwnProperty.call(d,f)&&(j=e(f,d))&&g.push(b(f)+(h?": ":":")+j);j=g.length===0?"{}":h?"{\n"+h+g.join(",\n"+
h)+"\n"+m+"}":"{"+g.join(",")+"}";h=m;return j}}if(typeof Date.prototype.toJSON!=="function")Date.prototype.toJSON=function(){return isFinite(this.valueOf())?this.getUTCFullYear()+"-"+a(this.getUTCMonth()+1)+"-"+a(this.getUTCDate())+"T"+a(this.getUTCHours())+":"+a(this.getUTCMinutes())+":"+a(this.getUTCSeconds())+"Z":null},String.prototype.toJSON=Number.prototype.toJSON=Boolean.prototype.toJSON=function(){return this.valueOf()};var c=/[\u0000\u00ad\u0600-\u0604\u070f\u17b4\u17b5\u200c-\u200f\u2028-\u202f\u2060-\u206f\ufeff\ufff0-\uffff]/g,
o=/[\\\"\x00-\x1f\x7f-\x9f\u00ad\u0600-\u0604\u070f\u17b4\u17b5\u200c-\u200f\u2028-\u202f\u2060-\u206f\ufeff\ufff0-\uffff]/g,h,n,p={"\u0008":"\\b","\t":"\\t","\n":"\\n","\u000c":"\\f","\r":"\\r",'"':'\\"',"\\":"\\\\"},k;if(typeof JSON.stringify!=="function")JSON.stringify=function(a,b,c){var f;n=h="";if(typeof c==="number")for(f=0;f<c;f+=1)n+=" ";else typeof c==="string"&&(n=c);if((k=b)&&typeof b!=="function"&&(typeof b!=="object"||typeof b.length!=="number"))throw Error("JSON.stringify");return e("",
{"":a})};if(typeof JSON.parse!=="function")JSON.parse=function(a,b){function e(a,c){var f,g,d=a[c];if(d&&typeof d==="object")for(f in d)Object.prototype.hasOwnProperty.call(d,f)&&(g=e(d,f),g!==void 0?d[f]=g:delete d[f]);return b.call(a,c,d)}var f;a=String(a);c.lastIndex=0;c.test(a)&&(a=a.replace(c,function(a){return"\\u"+("0000"+a.charCodeAt(0).toString(16)).slice(-4)}));if(/^[\],:{}\s]*$/.test(a.replace(/\\(?:["\\\/bfnrt]|u[0-9a-fA-F]{4})/g,"@").replace(/"[^"\\\n\r]*"|true|false|null|-?\d+(?:\.\d*)?(?:[eE][+\-]?\d+)?/g,
"]").replace(/(?:^|:|,)(?:\s*\[)+/g,"")))return f=eval("("+a+")"),typeof b==="function"?e({"":f},""):f;throw new SyntaxError("JSON.parse");}})();var jQ=jQuery.noConflict();
(function(a){a.fn.qtip.baseIndex=1E4;a(document).ready(function(){a("label.overlabel").overlabel();validateOptions={onkeyup:!1,focusCleanup:!0,focusInvalid:!1};a("ul.ui-form").not(".dont-validate").parents("form:first").validate(validateOptions);a("div.ui-form").not(".dont-validate").find("form:first").validate(validateOptions);a("form.uniForm").validate(validateOptions);a.browser.msie||a("textarea.auto-expand").autoResize();a(".custom-tip").qtip({position:{my:"center right",at:"center left",viewport:jQuery(window)},
style:{classes:"ui-tooltip-rounded ui-tooltip-shadow"}});a(".custom-tip-top").qtip({position:{my:"bottom center",at:"top center",viewport:jQuery(window)},style:{classes:"ui-tooltip-rounded ui-tooltip-shadow"}});flash=a("div.flash_info");if(flash.get(0))try{close=a("<a />").addClass("close").attr("href","#").appendTo(flash).click(function(){flash.fadeOut(600)}),setTimeout(function(){flash.hide("blind",{},500)},2E4),flash.find("a.show-list").click(function(){flash.find("div.list").slideDown(300);a(this).hide()})}catch(b){}})})(jQuery);
