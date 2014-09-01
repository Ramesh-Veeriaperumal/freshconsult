/*
* Loading js file with out distrobing the page load..
* For performance improvements this has been introceed. Pratheepv
* copied from http://www.nczonline.net/blog/2009/06/23/loading-javascript-without-blocking/
*/
function AsyncJSLoader(url, callback){
    callback = callback || function(){};
    var script = document.createElement("script")
    script.type = "text/javascript";

    if (script.readyState){  //IE
        script.onreadystatechange = function(){
            if (script.readyState == "loaded" ||
                    script.readyState == "complete"){
                script.onreadystatechange = null;
                callback();
            }
        };
    } else {  //Others
        script.onload = function(){
            callback();
        };
    }

    script.src = url;
    document.getElementsByTagName("head")[0].appendChild(script);
}