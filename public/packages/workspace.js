makePageNonSelectable=function(a){if(document.all)a.onselectstart=function(){return!1};a.onmousedown=function(){return!1}};function imgerror(a){a.src="/images/fillers/profile_blank_thumb.gif";a.onerror="";return!0}function get_short_url(a,b){jQuery.getJSON("http://api.bitly.com/v3/shorten?callback=?",{format:"json",apiKey:"R_8ae5a67d8d9930440f0d1d4b794332f0",login:"freshdesk",longUrl:a},function(a){b(a.data.url)})}var delay=function(){var a=0;return function(b,d){clearTimeout(a);a=setTimeout(b,d)}}();
function insertTextAtCursor(a,b){var d=a.value,c;if(typeof a.selectionStart!="undefined"&&typeof a.selectionEnd!="undefined")c=a.selectionEnd,a.value=d.slice(0,c)+b+d.slice(c),a.selectionStart=a.selectionEnd=c+b.length;else if(typeof document.selection!="undefined"&&typeof document.selection.createRange!="undefined")a.focus(),d=document.selection.createRange(),d.collapse(!1),d.text=b,d.select()}
function setSelRange(a,b,d){a.setSelectionRange?(a.focus(),a.setSelectionRange(b,d)):a.createTextRange&&(a=a.createTextRange(),a.collapse(!0),a.moveEnd("character",d),a.moveStart("character",b),a.select())}function setCaretToPos(a,b){setSelRange(a,b,b)}
function construct_reply_url(a,b){email_split=a.split("@");email_name=email_split[0]||"";email_domain=email_split[1]||"";email_domain!==""&&(email_domain=email_domain.split(".")[0]);b=b.toLowerCase();reply_email="@"+b;return reply_email=email_domain.toLowerCase()==b?email_name+reply_email:email_domain+email_name+reply_email}active_dialog=null;
(function(a){var b={init:function(){return this.each(function(){$this=a(this);var b=null;$this.click(function(c){c.preventDefault();width=$this.attr("dialogWidth")||"750px";b==null?(b=a("<div class='loading-center' />").html("<br />").dialog({modal:!0,width:width,height:"auto",position:"top",title:this.title,resizable:!1}),active_dialog=b.load(this.href,{},function(){b.removeClass("loading-center");b.css({height:"auto"})})):b.dialog("open")})})},destroy:function(){return this.each(function(){var b=
a(this),c=b.data("dialog2");a(window).unbind(".dialog2");c.tooltip.remove();b.removeData("dialog2")})},show:function(){},hide:function(){},update:function(){}};a.fn.dialog2=function(d){if(b[d])return b[d].apply(this,Array.prototype.slice.call(arguments,1));else if(typeof d==="object"||!d)return b.init.apply(this,arguments);else a.error("Method "+d+" does not exist on jQuery.dialog2")};a.fn.autoLink=function(){this.contents().filter(function(){return this.nodeType===3}).each(function(b,c){c.nodeValue.match(/https?:/)&&
a(c).replaceWith(c.nodeValue.replace(/(https?:\/\/\S+)/g,'<a href="$1" target="_blank">$1</a>'))});return this};a.fn.limit=function(b,c){var e;a(this);a(this).focus(function(){e=window.setInterval(substring,100)});a(this).blur(function(){clearInterval(e);substring()});substringFunction="function substring(){ var val = $(self).val();var length = val.length;if(length > limit){$(self).val($(self).val().substring(0,limit));}";typeof c!="undefined"&&(substringFunction+="if($(element).html() != limit-length){$(element).html((limit-length<=0)?'0':limit-length);}");
substringFunction+="}";eval(substringFunction);substring();return this};a.fn.autoGrowInput=function(b){b=a.extend({maxWidth:1E3,minWidth:0,comfortZone:70},b);this.filter("input:text").each(function(){var c=b.minWidth||a(this).width(),e="",f=a(this),h=a("<tester/>").css({position:"absolute",top:-9999,left:-9999,width:"auto",fontSize:f.css("fontSize"),fontFamily:f.css("fontFamily"),fontWeight:f.css("fontWeight"),letterSpacing:f.css("letterSpacing"),whiteSpace:"nowrap"});h.insertAfter(f);a(this).bind("keyup keydown blur update",
function(){if(e!==(e=f.val())){var a=e.replace(/&/g,"&amp;").replace(/\s/g,"&nbsp;").replace(/</g,"&lt;").replace(/>/g,"&gt;");h.html(a);a=h.width();a=a+b.comfortZone>=c?a+b.comfortZone:c;var j=f.width();(a<j&&a>=c||a>c&&a<b.maxWidth)&&f.width(a)}})});return this}})(jQuery);typeof Autocompleter=="undefined"&&(Autocompleter={});
Autocompleter.Json=Class.create(Autocompleter.Base,{initialize:function(a,b,d,c){c=c||{};this.baseInitialize(a,b,c);this.lookupFunction=d;this.options.choices=c.choices||10},getUpdatedChoices:function(){this.lookupFunction(this.getToken().toLowerCase(),this.updateJsonChoices.bind(this))},updateJsonChoices:function(a){this.updateChoices("<ul>"+a.slice(0,this.options.choices).map(this.jsonChoiceToListChoice.bind(this)).join("")+"</ul>")},jsonChoiceToListChoice:function(a){return"<li>"+a.escapeHTML()+
"</li>"}});Autocompleter.RateLimiting=function(){this.scheduledRequest=this.currentRequest=null};
Autocompleter.RateLimiting.prototype={schedule:function(a,b,d){this.scheduledRequest={f:a,searchTerm:b,callback:d};this._sendRequest()},_sendRequest:function(){if(!this.currentRequest)this.currentRequest=this.scheduledRequest,this.scheduledRequest=null,this.currentRequest.f(this.currentRequest.searchTerm,this._callback.bind(this))},_callback:function(a){this.currentRequest.callback(a);this.currentRequest=null;this.scheduledRequest&&this._sendRequest()}};
Autocompleter.Cache=Class.create({initialize:function(a,b){this.cache=new Hash;this.backendLookup=a;this.rateLimiter=new Autocompleter.RateLimiting;this.options=Object.extend({choices:10,fuzzySearch:!1},b||{})},lookup:function(a,b){return this._lookupInCache(a,null,b)||this.rateLimiter.schedule(this.backendLookup,a,this._storeInCache.curry(a,b).bind(this))},_lookupInCache:function(a,b,d){b=b||a;var c=this.cache.get(b);return c==null?b.length>1?this._lookupInCache(a,b.substr(0,b.length-1),d):!1:(a!=
b&&(c=this._localSearch(c,a),this._storeInCache(a,null,c)),d(c.slice(0,this.options.choices)),!0)},_localSearch:function(a,b){for(var d=this.options.fuzzySearch?RegExp(b.gsub(/./,".*#{0}"),"i"):RegExp(b,"i"),c=[],e=null,f=0,h=a.length;f<h;++f)e=a[f],d.test(e)&&c.push(e);return c},_storeInCache:function(a,b,d){this.cache.set(a,d);b&&b(d.slice(0,this.options.choices))}});
Autocompleter.MultiValue=Class.create({options:$H({}),element:null,dataFetcher:null,createSelectedElement:function(a,b){var d=(new Element("a")).update("x");d.className="close-link";d.observe("click",function(a){this.removeEntry(a.element().up("li"));a.stop()}.bind(this));var c=new Element("input",{type:"hidden",value:a});c.name=this.name+"[]";var e=new Element("li",{choice_id:a});e.className="choice";return e.insert((""+b).escapeHTML()).insert(d).insert(c)},initialize:function(a,b,d,c){this.options=
c||{};a=$(a);this.name=a.name;this.form=a.up("form");this.dataFetcher=b;this.active=!1;this.acceptNewValues=this.options.acceptNewValues||!1;this.options.frequency=this.options.frequency||0.4;this.options.allowSpaces=this.options.allowSpaces||!1;this.options.minChars=this.options.minChars||2;this.options.tabindex=this.options.tabindex||a.readAttribute("tabindex")||"";this.options.onShow=this.options.onShow||function(a,b){if(!b.style.position||b.style.position=="absolute"){b.style.position="absolute";
try{b.clonePosition(a,{setHeight:!1,offsetTop:a.offsetHeight})}catch(c){}}Effect.Appear(b,{duration:0.15})};this.options.onHide=this.options.onHide||function(a,b){new Effect.Fade(b,{duration:0.15})};this.searchField=new Element("input",{type:"text",autocomplete:"off",tabindex:this.options.tabindex});this.searchFieldItem=(new Element("li")).update(this.searchField);this.searchFieldItem.className="search_field_item";this.holder=(new Element("ul",{style:a.readAttribute("style")})).update(this.searchFieldItem);
this.holder.className="multi_value_field";a.insert({before:this.holder});a.remove();this.choicesHolderList=new Element("ul");this.choicesHolder=(new Element("div")).update(this.choicesHolderList);this.choicesHolder.className="autocomplete";this.choicesHolder.style.position="absolute";this.holder.insert({after:this.choicesHolder});this.choicesHolder.hide();Event.observe(this.holder,"click",Form.Element.focus.curry(this.searchField));Event.observe(this.searchField,"keydown",this.onSearchFieldKeyDown.bindAsEventListener(this));
this.acceptNewValues&&(Event.observe(this.searchField,"keyup",this.onSearchFieldKeyUp.bindAsEventListener(this)),Event.observe(this.searchField,"blur",this.onSearchFieldBlur.bindAsEventListener(this)));Event.observe(this.searchField,"focus",this.getUpdatedChoices.bindAsEventListener(this));Event.observe(this.searchField,"focus",this.show.bindAsEventListener(this));Event.observe(this.searchField,"blur",this.hide.bindAsEventListener(this));this.setEmptyValue();(d||[]).each(function(a){this.addEntry(this.getValue(a),
this.getTitle(a))},this)},show:function(){if(!this.choicesHolderList.empty()&&Element.getStyle(this.choicesHolder,"display")=="none")this.options.onShow(this.holder,this.choicesHolder)},hide:function(){this.stopIndicator();if(Element.getStyle(this.choicesHolder,"display")!="none")this.options.onHide(this.element,this.choicesHolder);this.iefix&&Element.hide(this.iefix)},onSearchFieldKeyDown:function(a){if(this.active)switch(a.keyCode){case Event.KEY_TAB:case Event.KEY_RETURN:this.selectEntry(),a.stop();
case Event.KEY_ESC:this.hide();this.active=!1;a.stop();return;case Event.KEY_LEFT:case Event.KEY_RIGHT:return;case Event.KEY_UP:this.markPrevious();this.render();a.stop();return;case Event.KEY_DOWN:this.markNext();this.render();a.stop();return}else if(a.keyCode==Event.KEY_TAB||a.keyCode==Event.KEY_RETURN||Prototype.Browser.WebKit>0&&a.keyCode==0)return;else a.keyCode==Event.KEY_BACKSPACE&&a.element().getValue().blank()&&(a=a.element().up("li.search_field_item").previous("li.choice"))&&this.removeEntry(a);
this.hasFocus=this.changed=!0;this.observer&&clearTimeout(this.observer);this.observer=setTimeout(this.onObserverEvent.bind(this),this.options.frequency*1E3)},onSearchFieldKeyUp:function(a){var b="";if(a.keyCode==188||a.keyCode==32){var d=$F(a.element()),c=0;a.keyCode==188?c=d.indexOf(","):a.keyCode==32&&!this.options.allowSpaces&&(c=d.indexOf(" "));b=d.substr(0,c).toLowerCase().strip()}if(!b.blank())this.addEntry(b,b),a.element().value=d.substring(c+1,d.length)},onSearchFieldBlur:function(a){this.addNewValueFromSearchField.bind(this).delay(0.1,
a.element())},addNewValueFromSearchField:function(a){var b=$F(a).strip();if(!b.blank())this.addEntry(b,b),a.value=""},onObserverEvent:function(){this.changed=!1;this.tokenBounds=null;this.getToken().length>=this.options.minChars?this.getUpdatedChoices():(this.active=!1,this.hide())},getToken:function(){return this.searchField.value},markPrevious:function(){this.index>0?this.index--:this.index=this.entryCount-1},markNext:function(){this.index<this.entryCount-1?this.index++:this.index=0},getEntry:function(a){return this.choicesHolderList.childNodes[a]},
getCurrentEntry:function(){return this.getEntry(this.index)},selectEntry:function(){this.active=!1;var a=this.getCurrentEntry();this.addEntry(a.choiceId,a.textContent||a.innerText);this.searchField.clear();this.searchField.focus()},addEntry:function(a,b){b=b||a;this.selectedEntries().include(""+a)||this.searchFieldItem.insert({before:this.createSelectedElement(a,b)});var d=this.emptyValueElement();d&&d.remove()},removeEntry:function(a){if(a=Object.isElement(a)?a:this.holder.down("li[choice_id="+a+
"]"))a.remove(),this.selectedEntries().length==0&&this.setEmptyValue()},clear:function(){this.holder.select("li.choice").each(function(a){this.removeEntry(a)},this)},setEmptyValue:function(){this.emptyValueElement()||this.form.insert(jQuery("<input />").attr({type:"hidden",name:this.name}).addClass("emptyValueField").get(0))},emptyValueElement:function(){return this.form.down("input.emptyValueField[name='"+this.name+"']")},selectedEntries:function(){return this.form.select("input[type=hidden][name='"+
this.name+"[]']").map(function(a){return a.value})},startIndicator:function(){},stopIndicator:function(){},getUpdatedChoices:function(){this.startIndicator();var a=this.getToken();a.length>0?this.dataFetcher(a,this.updateChoices.curry(a).bind(this)):this.choicesHolderList.update()},updateChoices:function(a,b){if(!this.changed&&this.hasFocus){this.entryCount=b.length;this.choicesHolderList.innerHTML="";b.each(function(b,c){this.choicesHolderList.insert(this.createChoiceElement(this.getValue(b),this.getTitle(b),
c,a))}.bind(this));for(var d=0;d<this.entryCount;d++){var c=this.getEntry(d);c.choiceIndex=d;this.addObservers(c)}this.stopIndicator();this.index=0;this.entryCount==1&&this.options.autoSelect?(this.selectEntry(),this.hide()):this.render()}},addObservers:function(a){Event.observe(a,"mouseover",this.onHover.bindAsEventListener(this));Event.observe(a,"click",this.onClick.bindAsEventListener(this))},onHover:function(a){var b=Event.findElement(a,"LI");if(this.index!=b.autocompleteIndex)this.index=b.autocompleteIndex,
this.render();Event.stop(a)},onClick:function(a){this.index=Event.findElement(a,"LI").autocompleteIndex;this.selectEntry();this.hide()},createChoiceElement:function(a,b,d){var c=new Element("li",{choice_id:a});c.innerHTML=(""+b).escapeHTML();c.choiceId=a;c.autocompleteIndex=d;return c},render:function(){if(this.entryCount>0){for(var a=0;a<this.entryCount;a++)this.index==a?Element.addClassName(this.getEntry(a),"selected"):Element.removeClassName(this.getEntry(a),"selected");if(this.hasFocus)this.show(),
this.active=!0}else this.active=!1,this.hide()},getTitle:function(a){return Object.isArray(a)?a[0]:a},getValue:function(a){return Object.isArray(a)?a[1]:a}});var date_lang={ago:"Ago",from:"From Now",now:"Just Now",minute:"Minute",minutes:"Minutes",hour:"Hour",hours:"Hours",day:"Day",days:"Days",week:"Week",weeks:"Weeks",month:"Month",months:"Months",year:"Year",years:"Years"};
function humaneDate(a,b){function d(a,b){if(a>=b&&a<=b*1.1)return b;return a}var c=date_lang,e=[[60,c.now],[3600,c.minute,c.minutes,60],[86400,c.hour,c.hours,3600],[604800,c.day,c.days,86400],[2628E3,c.week,c.weeks,604800],[31536E3,c.month,c.months,2628E3],[Infinity,c.year,c.years,31536E3]],f=typeof a=="string";a=f?new Date((""+a).replace(/-/g,"/").replace(/[TZ]/g," ")):a;b=b||new Date;f=(b-a+(b.getTimezoneOffset()-(f?0:a.getTimezoneOffset()))*6E4)/1E3;f<0?(f=Math.abs(f),c=" "+c.from):c=" "+c.ago;
for(var h=0,i=e[0];e[h];i=e[++h])if(f<i[0]){if(h===0)return i[1];e=Math.ceil(d(f,i[3])/i[3]);return e+" "+(e!=1?i[2]:i[1])+(h>0?c:"")}}if(typeof jQuery!="undefined")jQuery.fn.humaneDates=function(){return this.each(function(){var a=jQuery(this),b=humaneDate(new Date(a.attr("title")));b&&a.html()!=b&&a.html(b)})};window.fdUtil={make_defined:function(){$A(arguments).each(function(){})}};
window.FactoryUI={text:function(a,b,d,c){a=b||"";return jQuery("<input type='text' />").attr({name:a}).addClass(c||"text").val(d||"")},dropdown:function(a,b,d){if(a){b=b||"";var c=jQuery("<select />").attr({name:b}).addClass(d||"dropdown");a.each(function(a){jQuery("<option />").text(a.value).val(a.name).appendTo(c)});return jQuery(c)}},paragraph:function(a,b,d,c){a=b||"";return jQuery("<textarea />").attr({name:a}).addClass(c||"paragraph").val(d||"")},checkbox:function(a,b,d,c){a=a||"";b=b||"";labelBox=
jQuery("<label />").addClass(c||"checkbox");hiddenBox=jQuery("<input type='hidden' />").attr({name:b,value:!1});checkBox=jQuery("<input type='checkbox' />").attr({name:b,checked:"checked",value:!0});return labelBox.append(hiddenBox).append(checkBox).append(a)}};var JSON;JSON||(JSON={});
(function(){function a(a){return a<10?"0"+a:a}function b(a){e.lastIndex=0;return e.test(a)?'"'+a.replace(e,function(a){var b=i[a];return typeof b==="string"?b:"\\u"+("0000"+a.charCodeAt(0).toString(16)).slice(-4)})+'"':'"'+a+'"'}function d(a,c){var e,m,l,i,n=f,k,g=c[a];g&&typeof g==="object"&&typeof g.toJSON==="function"&&(g=g.toJSON(a));typeof j==="function"&&(g=j.call(c,a,g));switch(typeof g){case "string":return b(g);case "number":return isFinite(g)?String(g):"null";case "boolean":case "null":return String(g);
case "object":if(!g)return"null";f+=h;k=[];if(Object.prototype.toString.apply(g)==="[object Array]"){i=g.length;for(e=0;e<i;e+=1)k[e]=d(e,g)||"null";l=k.length===0?"[]":f?"[\n"+f+k.join(",\n"+f)+"\n"+n+"]":"["+k.join(",")+"]";f=n;return l}if(j&&typeof j==="object"){i=j.length;for(e=0;e<i;e+=1)typeof j[e]==="string"&&(m=j[e],(l=d(m,g))&&k.push(b(m)+(f?": ":":")+l))}else for(m in g)Object.prototype.hasOwnProperty.call(g,m)&&(l=d(m,g))&&k.push(b(m)+(f?": ":":")+l);l=k.length===0?"{}":f?"{\n"+f+k.join(",\n"+
f)+"\n"+n+"}":"{"+k.join(",")+"}";f=n;return l}}if(typeof Date.prototype.toJSON!=="function")Date.prototype.toJSON=function(){return isFinite(this.valueOf())?this.getUTCFullYear()+"-"+a(this.getUTCMonth()+1)+"-"+a(this.getUTCDate())+"T"+a(this.getUTCHours())+":"+a(this.getUTCMinutes())+":"+a(this.getUTCSeconds())+"Z":null},String.prototype.toJSON=Number.prototype.toJSON=Boolean.prototype.toJSON=function(){return this.valueOf()};var c=/[\u0000\u00ad\u0600-\u0604\u070f\u17b4\u17b5\u200c-\u200f\u2028-\u202f\u2060-\u206f\ufeff\ufff0-\uffff]/g,
e=/[\\\"\x00-\x1f\x7f-\x9f\u00ad\u0600-\u0604\u070f\u17b4\u17b5\u200c-\u200f\u2028-\u202f\u2060-\u206f\ufeff\ufff0-\uffff]/g,f,h,i={"\u0008":"\\b","\t":"\\t","\n":"\\n","\u000c":"\\f","\r":"\\r",'"':'\\"',"\\":"\\\\"},j;if(typeof JSON.stringify!=="function")JSON.stringify=function(a,b,c){var e;h=f="";if(typeof c==="number")for(e=0;e<c;e+=1)h+=" ";else typeof c==="string"&&(h=c);if((j=b)&&typeof b!=="function"&&(typeof b!=="object"||typeof b.length!=="number"))throw Error("JSON.stringify");return d("",
{"":a})};if(typeof JSON.parse!=="function")JSON.parse=function(a,b){function d(a,c){var e,f,g=a[c];if(g&&typeof g==="object")for(e in g)Object.prototype.hasOwnProperty.call(g,e)&&(f=d(g,e),f!==void 0?g[e]=f:delete g[e]);return b.call(a,c,g)}var e;a=String(a);c.lastIndex=0;c.test(a)&&(a=a.replace(c,function(a){return"\\u"+("0000"+a.charCodeAt(0).toString(16)).slice(-4)}));if(/^[\],:{}\s]*$/.test(a.replace(/\\(?:["\\\/bfnrt]|u[0-9a-fA-F]{4})/g,"@").replace(/"[^"\\\n\r]*"|true|false|null|-?\d+(?:\.\d*)?(?:[eE][+\-]?\d+)?/g,
"]").replace(/(?:^|:|,)(?:\s*\[)+/g,"")))return e=eval("("+a+")"),typeof b==="function"?d({"":e},""):e;throw new SyntaxError("JSON.parse");}})();var $J=jQuery.noConflict();
(function(a){a.fn.qtip.baseIndex=1E4;a.validator.addMethod("tweet",a.validator.methods.maxlength,"Your Tweet was over 140 characters. You'll have to be more clever.");a.validator.addClassRules("tweet",{tweet:140});a(document).ready(function(){function b(){a(".nav-drop .menu-box").hide();a(".nav-drop .menu-trigger").removeClass("selected")}a("label.overlabel").overlabel();a(".customSelect").chosen();validateOptions={onkeyup:!1,focusCleanup:!0,focusInvalid:!1};a(".admin_list li").hover(function(){a(this).children(".item_actions").css("visibility",
"visible")},function(){a(this).children(".item_actions").css("visibility","hidden")});a("ul.ui-form").not(".dont-validate").parents("form:first").validate(validateOptions);a("div.ui-form").not(".dont-validate").find("form:first").validate(validateOptions);a("form.uniForm").validate(validateOptions);a.browser.msie||a("textarea.auto-expand").autoResize();sidebarHeight=a("#Sidebar").height();sidebarHeight!==null&&sidebarHeight>a("#Pagearea").height()&&a("#Pagearea").css("minHeight",sidebarHeight);a(".custom-tip").qtip({position:{my:"center right",
at:"center left",viewport:jQuery(window)},style:{classes:"ui-tooltip-rounded ui-tooltip-shadow"}});a(".custom-tip-top").qtip({position:{my:"bottom center",at:"top center",viewport:jQuery(window)},style:{classes:"ui-tooltip-rounded ui-tooltip-shadow"}});a(".custom-tip-bottom").qtip({position:{my:"top center",at:"bottom center",viewport:jQuery(window)},style:{classes:"ui-tooltip-rounded ui-tooltip-shadow"}});menu_box_count=0;fd_active_drop_box=null;a(".nav-drop .menu-trigger").bind("click",function(b){b.preventDefault();
a(this).toggleClass("selected").next().toggle();a(this).attr("data-menu-name")||a(this,a(this).next()).attr("data-menu-name","page_menu_"+menu_box_count++);a(this).attr("data-menu-name")!==a(fd_active_drop_box).attr("data-menu-name")&&a(fd_active_drop_box).removeClass("selected").next().hide();fd_active_drop_box=a(this)});a(".nav-drop li.menu-item a").bind("click",function(){b()});a(document).bind("click",function(c){c=a(c.target);c.parents().hasClass("nav-drop")||b();c.parent().hasClass("request_form_options")||
a("#canned_response_container").hide()});flash=a("div.flash_info");if(flash.get(0))try{closeableFlash(flash)}catch(d){}})})(jQuery);function closeableFlash(a){a=jQuery(a);jQuery("<a />").addClass("close").attr("href","#").appendTo(a).click(function(){a.fadeOut(600)});setTimeout(function(){a.css("display")!="none"&&a.hide("blind",{},500)},2E4)};
