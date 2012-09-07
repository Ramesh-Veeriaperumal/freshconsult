var LogMeInWidget = Class.create();
LogMeInWidget.prototype= {

	TechConsole : new Template(
		'<div class="remote_support">Start a new LogMeIn Rescue Session and copy instructions to the ticket'+
		'<div class="session_data">'+
		'<div class="pin_submit"><input type="submit" id="pinsubmit" class="uiButton" value="New Remote Session" onclick="logmeinWidget.generatePincode();return false;" /></div>' +
		'<div class="tech_console"><a target="_blank" href="#{techTicket}">Launch Technician Console...</a></div></div>'+
		'<div class="session_pin hide">'+
		'<span class="seperator"></span>'+
		'<span class="active_header">Last generated session</span>'+
		'<div class="active_session_pin">'+ 
		'<div class="pincode">Pincode : #{pincode}</div>'+
		'<div class="pintime">Generated #{pintime}</div></div>'+
		'<div class="resend"><a href="#" id="logmein_copy_to_tkt">Resend Instructions</a></div>'+
		'</div></div>'
	),

	SessionInstructions : new Template(
			'<hr /><b>Remote Session Instructions</b><br />'+
			'Pincode : #{pincode}<br/><br/>'+
			'Click the link below to start your remote session<br/>'+
			'<a href=\"https://secure.logmeinrescue.com/Customer/Code.aspx?Code=#{pincode}\"> https://secure.logmeinrescue.com/Customer/Code.aspx?Code=#{pincode}</a><br /><br />'+
			'<hr/><br/>'
	),
	
	initialize:function(logmeinBundle){
		jQuery("#logmein_widget").addClass('loading-fb');
		logmeinWidget = this;
		this.logmeinBundle = logmeinBundle;
		this.isPincodeValid();
		this.freshdeskWidget = new Freshdesk.Widget({
			//application_id:logmeinBundle.application_id,
			integratable_type:"remote_support",
			anchor:"logmein_widget",
			app_name:"LogMeIn",
			use_server_password: true,
			domain:"https://secure.logmeinrescue.com",
			ssl_enabled:"true"
		})
		this.getTechConsole();
	},

	getAuthcode: function(){
		authcodeEndpoint = "API/requestAuthCodeSSO.aspx?ssoid=#{sso_id}&pwd={{password}}&company=#{company_id}";
		this.freshdeskWidget.request({
			resource: authcodeEndpoint.interpolate({sso_id: logmeinBundle.ssoId, company_id: logmeinBundle.companyId}) ,
			on_failure: this.authcodeFailure.bind(this),
			on_success: this.authcodeSuccess.bind(this)
		});
	},


	getTechConsole: function(){
		techConsoleEndpoint = "SSO/GetLoginTicket.aspx?ssoid=#{sso_id}&Password={{password}}&CompanyID=#{company_id}";
		this.freshdeskWidget.request({
			resource: techConsoleEndpoint.interpolate({sso_id: logmeinBundle.ssoId, company_id: logmeinBundle.companyId}) ,
			on_failure: this.processFailure,
			on_success: this.assignTechnicianTicket.bind(this)
		});
	},

	generatePincode:function(){
		jQuery('#pinsubmit').prop('value', 'Generating Pincode...');
		jQuery('#pinsubmit').attr('disabled', 'disabled');
		if(logmeinBundle.authcode == null || logmeinBundle.authcode == "")
			this.getAuthcode();
		else{
			pincodeEndpoint = "API/requestPINCode.aspx?cfield0=#{reqName}&tracking0=INTEGRATIONS_LOGMEIN:#{account}:#{ticket}:#{secret}&notechconsole=1&authcode=#{authcode}";
			this.freshdeskWidget.request({
				resource: pincodeEndpoint.interpolate({reqName: logmeinBundle.reqName, account: logmeinBundle.accountId, ticket: logmeinBundle.ticketId, secret: logmeinBundle.secret, authcode: logmeinBundle.authcode}) ,
				on_failure: this.processFailure,
				on_success: this.processPincode.bind(this)
			});	
		}
		
	},


	assignTechnicianTicket:function(response){
		response = response.responseText;
		if(response.indexOf('OK') >= 0){
			logmeinWidget.techlink = response.substr(3);
			this.renderTechConsole(logmeinWidget.techlink, logmeinBundle.pincode, logmeinBundle.pinTime);
			jQuery("#logmein_widget").removeClass('loading-fb');
			if(logmeinBundle.pincode != ""){
				jQuery('.session_pin').removeClass("hide");
				jQuery("#logmein_copy_to_tkt").click(function(ev) { 
					ev.preventDefault();
					logmeinWidget.copyPincode(logmeinBundle.pincode);
				});
			}
		}
		else 
			this.handleError(response);
			
	},

	processPincode:function(response){	
		if(response.responseText.substr(0,2) == 'OK') {
			jQuery('#pinsubmit').prop('value', 'New Remote Session');
			jQuery('#pinsubmit').removeAttr('disabled');
			pincode = response.responseText.substr(12);
			logmeinBundle.pincode = pincode;
			logmeinBundle.pinTime = "";
			if(pincode != ""){
				this.copyPincode(pincode);	
			}
			logmein_session = {"agent_id": logmeinBundle.agentId, "md5secret": logmeinBundle.secret,  "pincode": pincode, "pintime": new Date().toString()}
			this.update_pincode({"ticket_id":logmeinBundle.ticketId, "account_id":logmeinBundle.accountId, "logmein_session": JSON.stringify(logmein_session)});
		}
		else 
			this.handleError(response.responseText);
	},

	update_pincode: function(reqData){
		new Ajax.Request("/integrations/logmein/update_pincode", {
			asynchronous: true,
			method: "put",
			parameters: reqData
		});
	},

	copyPincode: function(rescuePincode) {
		var pincodeInstructions = logmeinWidget.SessionInstructions.evaluate({ pincode: logmeinBundle.pincode })  ;
		jQuery('#ReplyButton').trigger("click");
		insertIntoConversation(pincodeInstructions.interpolate({ pincode:rescuePincode }), 'cnt-reply-body');
	},

	authcodeSuccess: function(response){
		response = response.responseText;
		if(response.indexOf('OK') >= 0){
			logmeinBundle.authcode = response.substring(13);
			this.updateAuthcode();
			this.generatePincode();
		}
		else 
			this.handleError(response);
	},

	updateAuthcode: function(){
		reqData = {
			"configs[authcode]":logmeinBundle.authcode
		};
		resource = "/integrations/installed_applications/update/#{appID}.json";
		new Ajax.Request(resource.interpolate({appID: logmeinBundle.installed_app_id}), {
			asynchronous: true,
			method: "post",
			parameters: reqData
		});
	},

	isPincodeValid:function(){
		if(logmeinBundle.pincode != ""){
			pintime = new Date(logmeinBundle.pinTime);
			if(new Date() > new Date(pintime.getTime() + 1200000)){
				logmeinBundle.pinTime = "";
				logmeinBundle.pincode = "";
			}
		}
	},

	renderTechConsole:function(techConsoleLink){
		this.freshdeskWidget.options.application_html = function(){ return logmeinWidget.TechConsole.evaluate({techTicket: techConsoleLink, pincode: logmeinBundle.pincode, pintime: logmeinWidget.freshdeskWidget.prettyDate(logmeinBundle.pinTime)}) } 
		this.freshdeskWidget.options.init_requests = null;
		this.freshdeskWidget.display();
	},

	handleError:function(response){
		if(response.indexOf("INVALID_SECRETAUTHCODE") >=0)
			logmeinWidget.getAuthcode();
		else if(response.indexOf("INVALIDSSOID") >=0)
			errorMsg = "Unable to fetch technician details. Please make sure your techncian SSO ID in LogMeIn matches your agent email";
		else if(response.indexOf("INVALID") >=0)
			errorMsg = "Unable to login to Logmein Rescue. Please verify your SSO ID and password and try again"
		else 
			errorMsg = "Unable to contact Logmein Rescue. Please try again later"

		this.freshdeskWidget.alert_failure(errorMsg);
		
	},

	authcodeFailure: function(){
		if(response.indexOf("INVALID") >=0)
			errorMsg = "Unable to login to Logmein Rescue. Please verify your SSO ID and password and try again";
		else
			errorMsg = "Unable to contact Logmein Rescue. Please try again later"

		this.freshdeskWidget.alert_failure(errorMsg);			
	}
}
logmeinWidget = new LogMeInWidget(logmeinBundle);