window.liveChat = window.liveChat || {};

window.liveChat.jsonpRequest = function (request, callback) {  
    jQuery.ajax({
        type: "GET",
        url: window.liveChat.URL + "/" + request.action + "?callback=?",
        data: request.data,
        dataType: "jsonp",
        crossDomain: true,
        cache: false,
        success: function( response ) {
            if(_.isFunction(callback)){
                callback(response);
            }
        },
        error: function (httpReq, status, exception) {
            console.log("error getting " +request.name, exception);
        }
    });
};

window.liveChat.ieVersionCompatability = function(){
    var nav = navigator.userAgent.toLowerCase();
    if(nav.indexOf('msie') == -1){
        return false;
    }
    var version = parseInt(nav.split('msie')[1]);
    return (version == 8 || version == 9)
};

window.liveChat.validateKey = function(eventObject,$){
	if($(eventObject.target).val()==''){
		return true;
	}
	if(eventObject.metaKey || eventObject.ctrlKey){
		return true;
	}
	var keys = [224,9,18,17,16,27,37,38,39,40];
	return ($.inArray(eventObject.keyCode,keys)!=-1);
};

