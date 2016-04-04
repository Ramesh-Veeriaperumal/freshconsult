function extractAgentPhoneNumber(callback) {
  return callback(cti_user.number);
}

var jsonpCallback=function(res) {
    return res;
} 

function makePhoneCall(agent, customer) {
  var data = {knumber: KNOWLARITY_NUMBER,
             api_key: KNOWLARITY_API_KEY, 
             agent: agent,
             customer: customer
      };
  if (typeof SIVR_DOMAIN !== 'undefined') {
    data['sivr_domain'] = SIVR_DOMAIN;  
  } 
  if (typeof SIVR_ID !== 'undefined') {
    data['sivr_ivr'] = SIVR_ID;
  }  
  if (typeof SIVR_OPTIN_KEY !== 'undefined') {
    data['sivr_optin_key'] = SIVR_OPTIN_KEY;
  }  
  data['country_code'] = 'IN';
  if (typeof COUNTRY_CODE !== 'undefined') {
    data['country_code'] = COUNTRY_CODE;
  }
  (function($) {
      $.ajax({
      type: "GET",
      url: 'https://konnect.knowlarity.com/konnect/makecall/',
      dataType: 'jsonp',
      jsonpCallback: "jsonpCallback",
      crossDomain: true,
      cache: false,
      data: data,
      success: function(response) {
          if (response.error) {
              
          } else if (response.success) {

          } else {

          }
      }
      });
   })(jQuery);
}

var PopupClient = (function() {
    return {
        source: null,
        popup_global: function() {
            if (typeof PopupClient.source != "undefined" && PopupClient.source != null) {
                if (source.OPEN) {
                    source.close();
                }
            }
            extractAgentPhoneNumber(function(agentNumber) {
              if ((typeof agentNumber === 'undefined') || (agentNumber == null)) {
                return;
            }
            PopupClient.source = new EventSource('https://konnect.knowlarity.com:8100/update-stream/'+ KNOWLARITY_API_KEY + '/freshdesk/'+agentNumber );
            PopupClient.source.addEventListener('message', function(e) {
                  var data = JSON.parse(e.data);
                  if(data.type=="ORIGINATE"){
                      freshdeskShowCrm(data.customer_number);
                      jQuery('.no-call-msg').addClass('hide');
                  }
                  else if(data.type=="BRIDGE"){
                      var reqBody = 'uuid='+data.uuid+'&id='+data.konnect_id;
                      remoteId = "Knowlarity_Call_Id_"+data.uuid;
                      knowlarity_widget.acknowledgeCallReceived(reqBody);
                  }
                  else if(data.type=="HANGUP"){
                    var recordingUrl = data.call_recording;
                    freshdeskHandleEndCall(recordingUrl);
                    jQuery('.no-call-msg').removeClass('hide');
                  }
                  else if (data.type != "ANSWER") {
                    return;
                  } 
              });
          });
       }
    };
})();


jQuery(document).ready(function() {
       PopupClient.popup_global();
});

