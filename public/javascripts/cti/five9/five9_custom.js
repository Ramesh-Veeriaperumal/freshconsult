var five9cti;
var cti;
var recUrl;
        function listenFive9Events() {
            try {
                five9cti = new Five9CTI("http://localhost:8080/agent/v2");
                five9cti.setDebug(false);
                five9cti.setUseIFrameProxy(true, "http://"+integrations_url+"/Five9CTIProxy-1.0.0.html");
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

            if (eventName === 'connected') {
                // Five9CTI is connected

            } else if (eventName === 'disconnected') {
                // Five9CTI is disconnected

            } else {
                if (ctiEvent) {
                    switch(eventName)
                    {
                        case "loginProcessFinished" : {
                            break;
                        }
                        case "logoutProcessFinished" : {
                            break;
                        }

                        case "callStarted": {
                            var cav = five9cti.getCallAttachedVariables();
                            for(var i=0;i<cav.length;i++){
                            if(cav[i].groupName=="Freshdesk"&&cav[i].name=="RecordingURL") {
                                 recUrl = cav[i].value;
                                break;
                                }
                            }
                            for(var i=0;i<cav.length;i++){
                            if(cav[i].groupName=="Call"&&cav[i].name=="session_id") {
                                 recUrl = recUrl + cav[i].value + '.wav';
                                
                                }
                            }
                            break;
                        }

                        case "callEnded": {
                            jQuery('.no-call-msg').removeClass('hide');
                            freshdeskHandleEndCall(recUrl);
                            break;
                        }

                        case "readyStatesUpdated": {
                            break;
                        }

                        case "readyStateChanged": {
                            break;
                        }

                        case "incomingCall": {
                            freshdeskShowCrm(ctiEvent.callinfo.number);
                            jQuery('.no-call-msg').addClass('hide');
                            break;
                        }

                        default: //alert( eventName +'::'+ JSON.stringify(ctiEvent));

                    }
                    
                }
            }
        }

        function isAvailable() {
            return five9cti.Connected;
        }

        function login(userName, password, stationId, stationType) {
            return five9cti.login(userName, password, stationId, stationType);
        }

        function loginAsync2(userName, password, stationId, stationType, force) {
            return five9cti.loginAsync2(userName, password, stationId, stationType, force);
        }

        function logout(reasonId) {
            return five9cti.logout(reasonId);
        }

        function makeCall(number, campaignId, checkDnc, callbackId) {
            return five9cti.makeCall(number, campaignId, checkDnc, callbackId);
        }