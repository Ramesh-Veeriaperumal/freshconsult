/* 
   A collection of javascript fixes for various libraries eg. Prototype, jQuery ... 
   because of missing or broken functionaly in various browsers
*/

// FIX for prototype 1.6 createContextualFragment not working in IE 9
// The method is directly added to the prototype object
if ((typeof Range !== "undefined") && !Range.prototype.createContextualFragment)
{
    Range.prototype.createContextualFragment = function(html)
    {
        var frag = document.createDocumentFragment(), 
        div = document.createElement("div");
        frag.appendChild(div);
        div.outerHTML = html;
        return frag;
    };
}


// ref http://stackoverflow.com/questions/1225102/jquery-event-to-trigger-action-when-a-div-is-made-visible
// !PULP move this into the pulp framework later
// @venom

// Triggering afterShow event for the following function
// show, slideDown & fadeIn add any other function that may require this property

// jQuery(function($) {
//     ["show", "slideDown", "fadeIn"]
//         .each(function(name){
//             var _oldShow = $.fn[name];
//             console.log(_oldShow);
//             $.fn[name] = function(speed, oldCallback) {                
//                 console.log(this);
//                 return $(this).each(function() {
//                         var
//                                 obj         = $(this),
//                                 newCallback = function() {
//                                         if ($.isFunction(oldCallback)) {
//                                                 oldCallback.apply(obj);
//                                         }

//                                         obj.trigger('afterShow');
//                                 };
//                         // For initiating trigger if speed is not present for plain show
//                         if(!speed) obj.trigger('afterShow');

//                         // now use the old function to show the element passing the new callback
//                         _oldShow.apply(obj, [speed, newCallback]);
//                 });
//             }    
//     });
// });

//Resolve the conflict between Bootstrap and PrototypeJS
// http://www.softec.lu/site/DevelopersCorner/BootstrapPrototypeConflict
jQuery.noConflict();
if (Prototype.BrowserFeatures.ElementExtensions) {
    var disablePrototypeJS = function (method, pluginsToDisable) {
            var handler = function (event) {
                event.target[method] = undefined;
                setTimeout(function () {
                    delete event.target[method];
                }, 0);
            };
            pluginsToDisable.each(function (plugin) { 
                jQuery(window).on(method + '.bs.' + plugin, handler);
            });
        },
        pluginsToDisable = ['collapse', 'dropdown', 'modal', 'tooltip'];
    disablePrototypeJS('show', pluginsToDisable);
    disablePrototypeJS('hide', pluginsToDisable);
}
jQuery(document).ready(function ($) {
    $('.bs-example-tooltips').children().each(function () {
        $(this).tooltip();
    });
});