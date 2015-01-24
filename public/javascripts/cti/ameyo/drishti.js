var DrishtiWidget = Class.create();
var agentId;
DrishtiWidget.prototype = {
  initialize : function(){
    var my_widget = this;
    this.freshdeskWidget = new Freshdesk.Widget({
    app_name: "drishti",
    integratable_type:"issue-tracking",
    application_id: 27,
    use_server_password: false,
    auth_type: 'NoAuth',
    domain : location.protocol + "//" +cti_user.host_ip+'/' ,
    ssl_enabled: "false",
  });
  },

  sendIntegratableId : function(type,id){
    
  },

}