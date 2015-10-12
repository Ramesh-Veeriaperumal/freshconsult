var socket;
var cti;
function freshdeskShowCrm(phone, additionalParams) {
	jQuery.ajax({
          url: '/integrations/cti/customer_details/fetch.json',
          type: 'GET',
          data: {"user" : {"mobile" : phone},
                 "agent" : {"email" : cti_user.email}
               },
          success: function (response) {
            data = response.data;
            show_incomming_popup(data);
        	},
          error: function (data) {
          }
    });
  jQuery(".cti_notes").show(); 

}

function freshdeskHandleLogin(reason) {

}
function freshdeskHandleLogout(reason) {

}
function freshdeskHandleOnLoad() {
	socket = new CtiSocket();
  socket.init(cti_user);
}

function freshdeskHandleLoginStatus(status) {

}
function freshdeskHandleEndCall(recordingUrl){
  jQuery('.cti').addClass('hide');
  if(cti===undefined){
    cti = new CtiEndCall();
  }
  if (!jQuery('#cti_end_call').hasClass('in')) {
    cti.showEndCallForm();
    cti.recordingUrl=recordingUrl||"";
  }
  jQuery(".cti_notes").hide();
}
function show_incomming_popup(data){
  jQuery('.cti').removeClass('hide');
  if(jQuery("#toolbar").css("display")=="none")
            jQuery("#cust_det").trigger("click");
            jQuery("#cust_name").text(escapeHtml(truncateString(data.name || " ",26)));
            jQuery("#cust_mobile").text(escapeHtml(data.mobile));
            jQuery("#cust_company").text(escapeHtml(truncateString(data.company_name || " ",36)));
            jQuery("#profile_pic").html("");
            if(data.avatar!="NA"){
              jQuery("#profile_pic").html(data.avatar || " ");
              jQuery("#profile_pic").attr("href",data.href);
              jQuery("#profile_pic").attr("target","_blank");
            }
            jQuery("#user_details").css("display","block");
            jQuery("#tickets_table").css("display","block");
            var myTable="";
            if(data.tickets!=null){
              var tickets = data.tickets;
              var obj =  JSON.parse(tickets);
              var len = obj.length;
                for (var i=0; i<len; i++) {
                  var sub = escapeHtml(obj[i]["helpdesk_ticket"].subject);
                  var trunc_sub = escapeHtml(truncateString(obj[i]["helpdesk_ticket"].subject,29));
                myTable+="<li><i class='ficon-ticket fsize-18 '></i><a href='/helpdesk/tickets/"+obj[i]["helpdesk_ticket"].display_id+"' data-toggle='tooltip' title='"+sub+"'"+ "target='_blank'>"+trunc_sub+"</a></li>";
                }
            }
            document.getElementById('tickets_table').innerHTML = myTable;
            if(cti===undefined){
              cti = new CtiEndCall();
            }
            cti.number = data.mobile;
            cti.callerName = null;
            if(data.name!=null) {
              cti.callerName = data.name;
              cti.$requesterName.val(data.name);
            }

            
}

jQuery(document).ready(function() {
  jQuery(".cti_notes").hide();
});

function truncateString(str, length) {
     return str.length > length ? str.substring(0, length - 3) + '...' : str
  }
