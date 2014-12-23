var five9cti;
var cti;
var recUrl;

function initialize() {
    try {
        five9cti = new Five9CTI("http://localhost:8080/agent/v2");
        five9cti.setDebug(true);
        five9cti.addCTIEventListener(this);
        five9cti.connect();
    } catch (e) {
        console.error('initialize() error: ' + e);
    }
}

function disconnect() {
    five9cti.disconnect();
}

function onCTIEvent(eventName, ctiEvent) {
    if (ctiEvent) {
        switch(eventName)
        {
            case "callStarted": {
                var cav = five9cti.getCallAttachedVariables();
                for(var i=0;i<cav.length;i++){
                if(cav[i].groupName=="Call"&&cav[i].name=="session_id") {
                     recUrl = cti_user.recording_path + cav[i].value + '.wav';
                     break;
                    }
                }
                break;
            }
            case "callEnded": {
                jQuery('.no-call-msg').removeClass('hide');
                freshdeskHandleEndCall(recUrl);
                break;
            }
            case "incomingCall": {
                freshdeskShowCrm(ctiEvent.callinfo.number);
                jQuery('.no-call-msg').addClass('hide');
                break;
            }
        }
    }
}
