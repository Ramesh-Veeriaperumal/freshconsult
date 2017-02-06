//Czentrix Widget
var CZentrixWidget = Class.create();
var agentId;
CZentrixWidget.prototype = {
  initialize : function(){
    var my_widget = this;
    this.freshdeskWidget = new Freshdesk.Widget({
      app_name: "czentrix",
      integratable_type:"issue-tracking",
      application_id: 29,
      use_server_password: true,
      auth_type: 'NoAuth',
      domain : location.protocol + "//" +cti_user.host_ip+'/' ,
      ssl_enabled: "false",
    });
  //this.freshdeskWidget.resource_failure=failureHandler.bind(this.freshdeskWidget);
  },
  loadAgentIFrame : function(callback,email){
    this.makeRequest("apps/appsHandler.php?transaction_id=CTI_GET_AGENTID&email_id="+ email + "&resFormat=1", function(data){
      agentId = data.getElementsByTagName("agent")[0].childNodes[0].nodeValue;
      callback(agentId);
      addCZentrixEventListener();
    }, function(data) {
       alert("Unable to reach C-Zentrix servers");
    });
  },
  getCallRecording : function(session_id){
    this.makeRequest("apps/appsHandler.php?transaction_id=GET_VOICE_FILENAME&agent_id="+agentId+"&session_id="+session_id+"&ip="+cti_user.host_ip+"&resFormat=1", function(data) {
      var path = data.getElementsByTagName("path")[0].childNodes[0].nodeValue;
      var fileName = data.getElementsByTagName("filename")[0].childNodes[0].nodeValue;
      czentrix_widget.mixVoiceFile(path,fileName,session_id);
    }, function(data) {
      alert("Failed to fetch call recording");
    });
  },

  mixVoiceFile : function(path,fileName,session_id){
    this.makeRequest("apps/appsHandler.php?transaction_id=CTI_MIX_VOICE_FILE&agent_id="+agentId+"&session_id="+session_id+"&resFormat=1", function(data) {
      var status = data.getElementsByTagName("status")[0].childNodes[0].nodeValue;
      if(status==1) freshdeskHandleEndCall(location.protocol +"//" +cti_user.host_ip+"/logger/"+path+"/"+fileName);
    }, function(data) {
      alert("Failed to fetch mix voice file");
    });
  },

  logout : function(path,fileName,session_id){
    this.makeRequest("apps/appsHandler.php?transaction_id=CTI_LOGOUT&agent_id="+agentId+"&ip="+cti_user.host_ip+"&resFormat=0", function(data) {}, function(data) {});
  },
  
  sendIntegratableId : function(type,id){
    var params = "type:"+id;
    this.makeRequest("apps/appsHandler.php?transaction_id=CTI_SET_DETAILS&session_id="+remoteId+"&agent_id="+agentId+"&remarks="+params+"&resFormat=0", function(data) {}, function(data) {});
  },

  makeRequest: function(path, onSuccess, onFailure){
    try {
      var domain = czentrix_widget.freshdeskWidget.options.domain;
      delete jQuery.ajaxSettings.headers['X-CSRF-Token'];
      jQuery.ajax({
        url: domain + path,
        type: 'GET',
        dataType: "xml",
        success: onSuccess,
        error: onFailure
      });
      jQuery.ajaxSettings.headers['X-CSRF-Token'] = jQuery('meta[name="csrf-token"]').attr('content');

    } catch(err) {
      jQuery.ajaxSettings.headers['X-CSRF-Token'] = jQuery('meta[name="csrf-token"]').attr('content');
    }
  }
}