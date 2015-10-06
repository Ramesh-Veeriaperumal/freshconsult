var czentrix_widget;
function addCZentrixEventListener(){
  var eventMethod = window.addEventListener ? "addEventListener" : "attachEvent";
    var eventer = window[eventMethod];
    var messageEvent = eventMethod == "attchEvent" ? "onmessage" : "message";
    eventer(messageEvent,function(e){
      parseData(e)
    },false);
}

function parseData(e){
  var data = e.data;
  var params = data.split("|");
  if(params[0]=="Disconnect"){
    czentrix_widget.getCallRecording(params[1]);
  }
  else if(params[0]=="Accept"){
    var callerId = params[1];
    var sessionId = params[2];
    remoteId = "Czentrix_Call_Id_"+sessionId;
    freshdeskShowCrm(callerId);
  }
}