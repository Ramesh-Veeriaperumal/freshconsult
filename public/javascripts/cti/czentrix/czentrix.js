var CZentrixWidget = Class.create();
var agentId;
CZentrixWidget.prototype = {
  initialize : function(){
    var my_widget = this;
    this.freshdeskWidget = new Freshdesk.Widget({
    app_name: "czentrix",
    integratable_type:"issue-tracking",
    application_id: 29,
    use_server_password: false,
    auth_type: 'NoAuth',
    domain : 'http://'+cti_user.host_ip+'/' ,
    ssl_enabled: "false",
  });
  //this.freshdeskWidget.resource_failure=failureHandler.bind(this.freshdeskWidget);
  },
  loadAgentIFrame : function(callback,email){
    this.freshdeskWidget.request({
        rest_url: "apps/appsHandler.php?transaction_id=CTI_GET_AGENTID&email_id="+ email + "&resFormat=1",
        method: "get",
        contentType : "text/xml",
        on_success: function(data) {
          parser=new DOMParser();
          xmlDoc=parser.parseFromString(data['responseJSON'],"text/xml");
          agentId = xmlDoc.getElementsByTagName("agent")[0].childNodes[0].nodeValue;
          callback(agentId);
          addCZentrixEventListener();
        },
        on_failure: function(data) {
          alert(data);
        },
      });
  },
  
  getCallRecording : function(session_id){
    this.freshdeskWidget.request({
        rest_url: "apps/appsHandler.php?transaction_id=GET_VOICE_FILENAME&agent_id="+agentId+"&session_id="+session_id+"&ip="+cti_user.host_ip+"&resFormat=1",
        method: "get",
        contentType : "text/xml",
        on_success: function(data) {
          parser=new DOMParser();
          xmlDoc=parser.parseFromString(data['responseJSON'],"text/xml");
          var path = xmlDoc.getElementsByTagName("path")[0].childNodes[0].nodeValue;
          var fileName = xmlDoc.getElementsByTagName("filename")[0].childNodes[0].nodeValue;
          czentrix_widget.mixVoiceFile(path,fileName,session_id);
        },
        on_failure: function(data) {
          
        },
      });
  },

  mixVoiceFile : function(path,fileName,session_id){
    this.freshdeskWidget.request({
        rest_url: "apps/appsHandler.php?transaction_id=CTI_MIX_VOICE_FILE&agent_id="+agentId+"&session_id="+session_id+"&resFormat=1",
        method: "get",
        contentType : "text/xml",
        on_success: function(data) {
          parser=new DOMParser();
          xmlDoc=parser.parseFromString(data['responseJSON'],"text/xml");
          var status = xmlDoc.getElementsByTagName("status")[0].childNodes[0].nodeValue;
          if(status==1) freshdeskHandleEndCall("http://"+cti_user.host_ip+"/logger/"+path+"/"+fileName);
        },
        on_failure: function(data) {
          
        },
      });
  },

  logout : function(path,fileName,session_id){
    this.freshdeskWidget.request({
        rest_url: "apps/appsHandler.php?transaction_id=CTI_LOGOUT&agent_id="+agentId+"&ip="+cti_user.host_ip+"&resFormat=0",
        method: "get",
        contentType : "text/xml",
        on_success: function(data) {
          parser=new DOMParser();
          xmlDoc=parser.parseFromString(data['responseJSON'],"text/xml");
        },
        on_failure: function(data) {
          
        },
      });
  },

}