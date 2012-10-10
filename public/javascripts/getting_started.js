var hideDelay=10000;
var $J = jQuery.noConflict();

var GettingStarted = {
	i18n:{},
	translate:function(key){
		return GettingStarted.i18n[key];
	},
	map:function(key,value){
		 GettingStarted.i18n[key] = value;
	}
};

			
var Validate = {	
	email:function(emails){
	   var emailArray = emails.split(",");
	   var filter = /^[a-zA-Z0-9_.-]+@[a-zA-Z0-9]+[a-zA-Z0-9.-]+[a-zA-Z0-9]+.[a-z]{1,4}$/;
	   for(var e=0;e < emailArray.length;e++)
	   {
		
		var email = Validate.extract_email(emailArray[e]);
		
	    if(filter.test(email)){
	        return true;
	    }
	    else{
	        return false;
	    }
	   }
	},
	extract_email:function(email){
	 email_match = email.match(/<(.+?)>/);
    if(email_match!=null){email = email_match[1];}
    return email;
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
	     statusObj.attr("class",status);
	},
	error:function(statusObj,content){
		statusObj.find("div.gs_failure").html(content);
		 statusObj.attr("class","failure");
	},
	success:function(statusObj,content){
		statusObj.find("div.gs_success").html(content);
		 statusObj.attr("class","success");
	},
	getContainer:function(divId,objId){	
		var loadingDiv = document.createElement("div");
		loadingDiv.innerHTML='<div id="status_update"><div class="gs_success"></div><div class="gs_failure"></div><div class="gs_update"></div></div>';
		loadingDiv.id= divId;
		loadingDiv.className = "ajx_loading_status";
	    	jQuery(objId).append(loadingDiv);
		loadingDiv = jQuery(loadingDiv);
	      loadingDiv.width(parseInt((jQuery(document.body).width()*4)/5));
		return loadingDiv;
	}
}
	
 var SendTestMail ={	
	  success:function(data){		
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
		sendMailContent.delay(300).fadeIn(100);
	},
	request:function(send){		
		var sendObj = jQuery(send);
		if(sendObj.data("progress")){return;}
		jQuery.ajax({
			   type: "put",
            url: sendObj.data('test-url')
      }).complete(function(){
      		sendObj.data("progress",false);
      		sendObj.val(sendObj.data("value"));
      }).done(function(){SendTestMail.success()}).fail(function(){SendTestMail.fail()});
      sendObj.data("progress",true);
      sendObj.val(sendObj.data("loading"));		
	}
  }

jQuery(document).ready(function(){
	jQuery("#ResetColors").click(function(){
		jQuery("#HeaderColor").val("#252525").trigger("keyup");
		jQuery("#TabColor").val("#006063").trigger("keyup");
		jQuery("#BackgroundColor").val("#efefef").trigger("keyup");
	});		
				
	jQuery('input#email_config_submit').click( function(event) {						
		var form = jQuery('form#email_config');
		var loadingDiv = jQuery("#email_config_status");
		loadingDiv = (loadingDiv.length>0)? loadingDiv:Loading.getContainer("email_config_status","#email_config_box");
		var statusBox = loadingDiv.find("#status_update");
		Loading.updateStatus(statusBox,"update",GettingStarted.translate("validating"));
		loadingDiv.show();
		var reply_email_ele = form.find("#reply_to_id");
		var reply_email = reply_email_ele.val();
		if(Validate.email(reply_email))
		{
			Loading.updateStatus(statusBox,"update",GettingStarted.translate("updating"));
			loadingDiv.show();
		}
		else{
			Loading.updateStatus(statusBox,"failure",GettingStarted.translate("email_invalid"));
			reply_email_ele.addClass("gs_error_highlight");
			reply_email_ele.focus();
			loadingDiv.delay(hideDelay).hide(1);
			event.stopPropagation();
		    return false;
		}
	});

	jQuery('input#agent_invite_submit').click( function(event) {
		var form = jQuery('form#agent_invite');
		var loadingDiv = jQuery("#agent_invite_status");
		loadingDiv = (loadingDiv.length>0)? loadingDiv : Loading.getContainer("agent_invite_status","#agent_box");
		var statusBox = loadingDiv.find("#status_update");		
		loadingDiv.show();
		var agent_emails_ele = form.find("#agent_invite");
		var agent_emails = "";
		var invalid_emails_exist = false;
		jQuery.each( jQuery('input:hidden[name="agents_invite_email[]"]', '#agent_invite'), function(index,obj){
													var agent_email = jQuery(obj).val();
													if(!Validate.email(agent_email)){
														jQuery(obj).closest("li").addClass("error_bubble");														
														invalid_emails_exist = true;
													}
													agent_emails = (agent_emails) ? agent_emails+"," : "";
													agent_emails += agent_email;													
												});		
		
		if(Validate.isEmpty(agent_emails)){
							Loading.updateStatus(statusBox,"failure",GettingStarted.translate("agent_email_required"));
							return false;
		}

		if(!invalid_emails_exist)
		{			  	Loading.updateStatus(statusBox,"update",GettingStarted.translate("agent_email_sending"));

		}
		else{
								
							Loading.updateStatus(statusBox,"failure",GettingStarted.translate("emails_invalid"));
					
			invalid_emails_exist = false;
			loadingDiv.delay(hideDelay).hide(1);
			event.stopPropagation();
		    return false;
		}		    
	});

	jQuery('input#rebrand_submit').click( function(event) {				
		
		var loadingDiv = jQuery("#rebrand_submit_status");
		loadingDiv = (loadingDiv.length>0)? loadingDiv : Loading.getContainer("#rebrand_submit_status","#rebrand_box");
		var statusBox = loadingDiv.find("#status_update");
		
		var form = jQuery('form#rebrand');
		
		
		var header_color = form.find("#HeaderColor");
		var tab_color = form.find("#TabColor");
		var bg_color = form.find("#BackgroundColor");
		
								
		if(!Validate.colorCode(header_color.val())){	
			var errorMessage = Validate.isEmpty(header_color.val())?GettingStarted.translate("rebrand_header_empty"):GettingStarted.translate("rebrand_header_invalid");			
			Loading.error(statusBox,errorMessage);
			loadingDiv.show();
			loadingDiv.delay(hideDelay).hide(1);
			header_color.focus();
			event.stopPropagation();
			return false;
		}
		else if(!Validate.colorCode(tab_color.val())){
			var errorMessage = Validate.isEmpty(tab_color.val())?GettingStarted.translate("rebrand_tab_empty"):GettingStarted.translate("rebrand_tab_invalid");			
			Loading.error(statusBox,errorMessage);
			loadingDiv.show();
			loadingDiv.delay(hideDelay).hide(1);
			tab_color.focus();
			event.stopPropagation();
			return false;
		}
		else if(!Validate.colorCode(bg_color.val())){
			var errorMessage = Validate.isEmpty(bg_color.val())?GettingStarted.translate("rebrand_bg_empty"):GettingStarted.translate("rebrand_bg_invalid");
			Loading.error(statusBox,errorMessage);
			loadingDiv.show();
			loadingDiv.delay(hideDelay).hide(1);
			bg_color.focus();
			event.stopPropagation();
			return false;
		}
		
		Loading.updateStatus(statusBox,"update",GettingStarted.translate("updating"));		
		loadingDiv.show();				
		loadingDiv.delay(hideDelay).hide(1);		
						
	});

	jQuery('.custom-upload input[type=file]').change(function(){
				    jQuery(this).next().find('input').val(jQuery(this).val());
	});

	jQuery(window).bind('hashchange', function(){
	  jQuery("#nav-controls [href="+window.location.hash+"]").trigger("click");
	});

	var activeSlide = 1; 

	jQuery("#slide1-1, #slide1-2, #slide1-3, #slide1-4").click(function(ev) {
		jQuery(this).siblings().removeClass("active");
		jQuery(this).addClass("active");
		jQuery("#content").css("left", jQuery(this).data("translate"));
		jQuery("#indicator-arrow").css("left", jQuery(this).data("translateArrow"));
		activeSlide = parseInt(this.id.split("-")[1]);
		if(activeSlide>1){
			jQuery("a#back").addClass("active");		
		}
		else{
			jQuery("a#back").removeClass("active");
			jQuery("a#back").addClass("inactive");
		}
		if(activeSlide==4){	jQuery("#next_text").text(GettingStarted.translate("next_alt_link")); }
		else{jQuery("#next_text").text(GettingStarted.translate("next_link"));}		
	});

	jQuery("#next").click(function(ev) {
		ev.preventDefault();		
		if(activeSlide==4){ goto_helpdesk();	}
		activeSlide = Math.min(4, activeSlide+1);
		jQuery("#slide1-"+activeSlide).trigger("click");
	});

	jQuery("#back").click(function(ev) {
		ev.preventDefault();		
		activeSlide = Math.max(1, activeSlide-1);
		jQuery("#slide1-"+activeSlide).trigger("click");
	});

	jQuery('.colorpicker input[type=text]').change(function(ev) {
		jQuery("#"+jQuery(this).attr("id")+"View").css("background-color",jQuery(this).val());
	});	

	jQuery('form#rebrand').change(function(ev){
			IS_REBRAND_CHANGED = true;
			trigger_rebrand();

	})	

	jQuery("form#rebrand").ajaxForm();	

	jQuery("form#agent_invite").bind('keydown', function(e)
	{		
	     if(e.keyCode == 13)
	     {	     		
	     		if(jQuery(e.target).attr("id")!="agent_invite_submit" && jQuery(e.target).val()){	     			
	     			jQuery(e.target).blur();
	     			setTimeout(function(){
	     					jQuery("form#agent_invite :input[type=text][value=]").each(
	     							function(){
	     									jQuery(this).focus();
	     							}
	     						)
	     			},100)	     			
	     			e.preventDefault();
	     			return false;
	     		}	         
	     }
	});

	jQuery("input.send-mail[type=button]").bind("click",function(e){
					 SendTestMail.request(e.target);
	});

	jQuery("input.change-logo-but[type=button]").bind("click",function(e){
					 jQuery("input#account_main_portal_attributes_logo_attributes_content[type=file]").click();
	});

});

var rms=0;
var IS_REBRAND_TIMEOUT_ALIVE = false;
var REBRAND_TIMEOUT = null;
var IS_REBRAND_CHANGED = false;
function trigger_rebrand(millisecs){
	
	if(IS_REBRAND_TIMEOUT_ALIVE){
		return;
	}	

	REBRAND_TIMEOUT = setTimeout("rebrand("+rms+")",5000);
	IS_REBRAND_TIMEOUT_ALIVE = true;
	
}

function rebrand(){
	jQuery("form#rebrand").submit();
	
	if(REBRAND_TIMEOUT){
		clearTimeout(REBRAND_TIMEOUT);
		REBRAND_TIMEOUT = null;
	}
	IS_REBRAND_CHANGED = false;
	IS_REBRAND_TIMEOUT_ALIVE = false;	
}

function execPendingJob()
{
	if(IS_REBRAND_CHANGED)
	{
		rebrand();
	}
}

function update_image(input) {
            if (input.files && input.files[0]) {
                var reader = new FileReader();

                reader.onload = function (e) {
                    jQuery("div.custom-upload").css("background-image", 'url(' + e.target.result + ')');                    
                    jQuery("div.custom-upload").css("background-size", '50px 50px');                    
                    jQuery("#logo-preview").attr("src",e.target.result);
                    rebrand();
                }

                reader.readAsDataURL(input.files[0]);
            }
        }

function goto_helpdesk(){
	execPendingJob();	
	window.location.href = "/helpdesk";
}