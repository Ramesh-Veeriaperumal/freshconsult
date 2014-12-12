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
  cti.showEndCallForm();
  cti.recordingUrl=recordingUrl||"";
  //cti.$endCallNote.val(recordingUrl||"");
}
function show_incomming_popup(data){
  jQuery('.cti').removeClass('hide');
  if(jQuery("#toolbar").css("display")=="none")
            jQuery("#cust_det").trigger("click");
            jQuery("#cust_name").text(data.name || " ");
            jQuery("#cust_mobile").text(data.mobile);
            jQuery("#cust_company").text(data.company_name || " ");
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
                myTable+="<li><i class='ficon-ticket fsize-18 '></i><a href='/helpdesk/tickets/"+obj[i]["helpdesk_ticket"].display_id+"' target='_blank'>"+obj[i]["helpdesk_ticket"].subject+"</a></li>";
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