var drishti_widget;
var a=0;
var crtObjectId;
function customShowCrm(phone, additionalParams) {
	var params = JSON.parse(additionalParams);
  remoteId = params.crtObjectId;
  crtObjectId = remoteId;
	freshdeskShowCrm(phone, additionalParams);
}

function handleOnLoad() {
	if(a) return;
	a++;
	jQuery.ajax({
          url: '/integrations/cti/customer_details/ameyo_session.json',
          type: 'GET',
          data: {"email" : cti_user.email},
          success: function (response) {
            session = response.sessionId;
            doLogin(cti_user.email,session,'auth.type.crm.http');
        	},
          error: function (data) {
          }
    }); 
}

function handleHangup(reason) {
	var recordingUrl = location.protocol + "//" +cti_user.host_ip+'/ameyowebaccess/command?command=downloadVoiceLog&data={"crtObjectId":"'+crtObjectId+'"}';
	freshdeskHandleEndCall(recordingUrl);
}

customIntegration = {};
customIntegration.showCrm = customShowCrm;
customIntegration.onLoadHandler = handleOnLoad;
customIntegration.hangupHandler = handleHangup;

registerCustomFunction("showCrm", customIntegration);
registerCustomFunction("onLoadHandler", customIntegration);
registerCustomFunction("hangupHandler", customIntegration);