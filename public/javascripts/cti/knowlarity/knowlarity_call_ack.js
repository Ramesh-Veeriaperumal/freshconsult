var KnowlarityWidget = Class.create();
KnowlarityWidget.prototype = {
  initialize : function(){
      this.freshdeskWidget = new Freshdesk.Widget({
      app_name: "knowlarity", 
      integratable_type:"issue-tracking", 
      use_server_password: false,
      auth_type: 'NoAuth',
      domain: "https://konnect.knowlarity.com"
  });
  },
  acknowledgeCallReceived : function(reqData){
     this.freshdeskWidget.request({
        rest_url: 'konnect/client_ack/',
        body: reqData,
        content_type: 'application/x-www-form-urlencoded',
        dataType: "text",
        method: "post",
        cache: false,
        on_success : function(response) {
         },
        on_failure : function(response) {
        }
      });
  },
}
  var knowlarity_widget = new KnowlarityWidget();
