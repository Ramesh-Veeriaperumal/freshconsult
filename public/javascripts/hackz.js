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