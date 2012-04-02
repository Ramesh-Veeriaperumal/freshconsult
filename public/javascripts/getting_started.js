var Validate = {	
	email:function(emails){
	   var emailArray = emails.split(",");
	   var filter = /^[a-zA-Z0-9_.-]+@[a-zA-Z0-9]+[a-zA-Z0-9.-]+[a-zA-Z0-9]+.[a-z]{1,4}$/;
	   for(var e=0;e < emailArray.length;e++)
	   {
		
		var email = emailArray[e];
		
	    if(filter.test(email)){
	        return true;
	    }
	    else{
	        return false;
	    }
	
	   }
	},
	colorCode:function(val){
		var colorCode = /^#(?:[0-9a-fA-F]{3}){1,2}$/;
		return colorCode.test(val);
	},
	isEmpty:function(val){
		var empty_string = /^\s*$/;
		return empty_string.test(val);
	}
}
	
var Loading ={	
	updateStatus:function(statusObj, status, content){	
	     statusObj.find("div.gs_"+status).html(content);
		 statusObj.attr("class","gs_"+status);
	},
	error:function(statusObj,content){
		statusObj.find("div.gs_failure").html(content);
		 statusObj.attr("class","gs_failure");
	},
	success:function(statusObj,content){
		statusObj.find("div.gs_success").html(content);
		 statusObj.attr("class","gs_success");
	},
	getContainer:function(divId,objId){	
		var loadingDiv = document.createElement("div");
		loadingDiv.innerHTML='<div id="status_update"><div class="gs_success"></div><div class="gs_failure"></div><div class="gs_update"></div></div>';
		loadingDiv.id= divId;
		loadingDiv.className = "ajx_loading_status";
	    jQuery(objId).append(loadingDiv);
		loadingDiv = jQuery(loadingDiv);
	    loadingDiv.width(parseInt((loadingDiv.parent()[0].getWidth()*4)/5));
		return loadingDiv;
	}
}
	
 var SendTestMail ={	
	  success:function(data){
		var loadingDiv = jQuery("#email_config_status");
		loadingDiv = (loadingDiv.length>0)? loadingDiv:Loading.getContainer("email_config_status","#email_config_box");		
		var statusBox = loadingDiv.find("#status_update");						
		Loading.updateStatus(statusBox,"success",GettingStarted.translate("email_sent_success"));
		loadingDiv.delay(300).hide(1);		
		var sendMailContent = jQuery("#send_mail_content");
		sendMailContent.animate({
			opaque:.5
		},
		{
			duration:1000
		});
		sendMailContent.attr("class","gs_response");	
		sendMailContent.animate({
			opaque:1
		},
		{
			duration:1000
		});
	},
	fail:function(data){	
		var loadingDiv = jQuery("#email_config_status");
		loadingDiv = (loadingDiv.length>0)? loadingDiv:Loading.getContainer("email_config_status","#email_config_box");
		var statusBox = loadingDiv.find("#status_update");
		Loading.updateStatus(statusBox,"failure",GettingStarted.translate("email_send_problem"));
		loadingDiv.delay(5000).hide(1);
	},
	confirm:function(code){
		var sendMailContent = jQuery("#send_mail_content");
		sendMailContent.attr("class","gs_"+code);
		sendMailContent.delay(500).fadeIn(100);
	},
	request:function(){
		var loadingDiv = jQuery("#email_config_status");
		loadingDiv = (loadingDiv.length>0)? loadingDiv:Loading.getContainer("email_config_status","#email_config_box");
		var statusBox = loadingDiv.find("#status_update");
		Loading.updateStatus(statusBox,"update",GettingStarted.translate("sending_test_mail_progress"));
		loadingDiv.show();
	}
  }