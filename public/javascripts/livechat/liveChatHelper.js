window.liveChat = window.liveChat || {};

window.liveChat.request = function (action, type, data, callback) {  
    var siteInfo = { siteId: SITE_ID, 
                     code: "fd", 
                     token: LIVECHAT_TOKEN, 
                     appId  : LIVECHAT_APP_ID };

    if(window.CURRENT_USER && CURRENT_USER.id){
        siteInfo.userId = CURRENT_USER.id;
    }
    var requestData = jQuery.extend( siteInfo, data );
    jQuery.ajax({
        type: type,
        url: window.liveChat.URL + "/" + action,
        data: requestData,
        dataType: "json",
        cache: false,
        success: function( response ) {
            response = response && response.data ? response.data : {};
            _.isFunction( callback ) && callback( null, response );
        },
        error: function (httpReq, status, exception) {
            console.log("error getting " +action, exception);
            _.isFunction( callback ) && callback( exception, null );
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

