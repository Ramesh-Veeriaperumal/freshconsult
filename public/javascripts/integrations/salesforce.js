var SalesforceWidget = Class.create();
SalesforceWidget.prototype= {

  initialize:function(salesforceBundle){
    jQuery("#salesforce_contacts_widget").addClass('loading-fb');
    salesforceWidget = this;
    salesforceBundle.app_name = "salesforce";
    salesforceBundle.integratable_type = "crm";
    salesforceBundle.auth_type = "NoAuth";
    salesforceBundle.widget_name = "salesforce_contacts_widget";
    salesforceBundle.handleRender = true;
    this.salesforceBundle = salesforceBundle;
    this.contactFields = ["Name"];
    this.leadFields=["Name"];
    this.accountFields=["Name"];
    this.opportunityFields = ["Name"];
    this.contactInfo = this.mapFieldLabels(salesforceBundle.contactFields,salesforceBundle.contactLabels);
    this.leadInfo = this.mapFieldLabels(salesforceBundle.leadFields,salesforceBundle.leadLabels);
    this.accountInfo = this.mapFieldLabels(salesforceBundle.accountFields,salesforceBundle.accountLabels);
    this.opportunityInfo = this.mapFieldLabels(salesforceBundle.opportunityFields,salesforceBundle.opportunityLabels);
    this.initOpportunityHash();
    freshdeskWidget = new Freshdesk.CRMWidget(salesforceBundle, this);
  },
  mapFieldLabels: function(fields,labels){
    var fieldLabels ={}
    var labelsArr = new Array();
    fieldsArr = fields.split(",");
    labelsArr = fieldsArr;//no labels until reenabled,defaults to field-name for existing sf users
    if(labels != undefined && labels.length != 0){
      labelsArr = labels.split(",");
    }
    for (var i=0;i<fieldsArr.length;i++){
      fieldLabels[fieldsArr[i]] = labelsArr[i];
    }
    return fieldLabels
  },

  get_contact_request: function() {
    var requestUrls = [];
    var custEmail = this.salesforceBundle.reqEmail;
    requestUrls.push( { type:"contact", value:custEmail } )
    requestUrls.push( { type:"lead", value:custEmail } )
    var custCompany = this.salesforceBundle.reqCompany;
    var ticket_company = salesforceBundle.ticket_company;
    if( this.salesforceBundle.accountFields && this.salesforceBundle.accountFields.length > 0 ) { //accountFields is configured
      if(ticket_company && ticket_company.length > 0){ // fetch account by ticket filed company
        requestUrls.push( { type:"account", value:{company:ticket_company} } )
      }
      else if ( custCompany  && custCompany.length > 0 ) { // make sure company is present
        custCompany = custCompany.trim(); 
        requestUrls.push( { type:"account", value:{company:custCompany} } )
      }
      else{
        requestUrls.push( { type:"account", value:{email:custEmail} } )
      }
    }
    for(var i=0;i<requestUrls.length;i++){
      requestUrls[i] = {  event:"fetch_user_selected_fields", 
                  source_url:"/integrations/service_proxy/fetch",
                  app_name:"salesforce",
                  payload: JSON.stringify(requestUrls[i]) 
               }
    }
    this.searchCount = requestUrls.length;
    this.searchResultsCount = 0;
    return requestUrls; 
  },

  parse_contact: function(resJson){
    var contacts =[];
    if(resJson.records)
      resJson=resJson.records;
    resJson.each(function(contact) {
      var cLink = this.salesforceBundle.domain +"/"+contact.Id;
      var sfcontact ={};
      sfcontact['url'] = cLink;//This sets the url to salesforce on name
      sfcontact['type'] = contact.attributes.type;
      if(contact.attributes.type == "Contact"){
        if(this.salesforceBundle.contactFields!=undefined){
          contactfields = this.salesforceBundle.contactFields.split(",");
          for (var i=0;i<contactfields.length;i++){
            if(contactfields[i]=="Address"){
              sfcontact[contactfields[i]]=this.salesforceWidget.getAddress(contact.MailingStreet,contact.MailingState,contact.MailingCity,contact.MailingCountry);
            }
            else if(contactfields[i]=="Account.Name"){
              sfcontact[contactfields[i]] = contact.Account.Name;
            }
            else{
              sfcontact[contactfields[i]] = escapeHtml(this.salesforceWidget.eliminateNullValues(contact[contactfields[i]]));
            }
          }
        }
      }
      else if(contact.attributes.type == "Lead"){
        if(this.salesforceBundle.leadFields!=undefined){
          leadfields = this.salesforceBundle.leadFields.split(",");
          for (var i=0;i<leadfields.length;i++){
            if(leadfields[i]=="Address"){
              sfcontact[leadfields[i]]=this.salesforceWidget.getAddress(contact.Street,contact.State,contact.City,contact.Country);
            }
            else{
              sfcontact[leadfields[i]] = escapeHtml(this.salesforceWidget.eliminateNullValues(contact[leadfields[i]]));
            }
          }
        }
      }
      else{
        sfcontact['Id'] = contact.Id; // This sets the salesforce account id as reference to fetch opportunities
        if(this.salesforceBundle.accountFields!=undefined){
          accountfields = this.salesforceBundle.accountFields.split(",");
          for (var i=0;i<accountfields.length;i++){
            if(accountfields[i]=="Address"){
              sfcontact[accountfields[i]]=this.salesforceWidget.getAddress(contact.BillingStreet,contact.BillingState,contact.BillingCity,contact.BillingCountry);
            }
            else{
              sfcontact[accountfields[i]] = escapeHtml(this.salesforceWidget.eliminateNullValues(contact[accountfields[i]]));
            }
          }
        }
      }
      contacts.push(sfcontact);
    });
    return contacts;
  },
  getAddress:function(street, state, city, country){
    var address="";
    street = (street) ? (street + ", ")  : "";
    state = (state) ? (state + ", ")  : "";
    city = (city) ? (city)  : "";
    country = (country) ? (city + ", " + country)  : city;
    address = street + state + country;
    address = (address == "") ? null : address
    return escapeHtml(address || "NA");
  },
  getTemplate:function(eval_params,crmWidget){
    var resourceTemplate = "";
    var fields = undefined;
    var labels = undefined;
    if(eval_params.type == "Lead"){
      fields = this.salesforceBundle.leadFields.split(",");
      labels = this.leadInfo;
      resourceTemplate = this.resourceSectionTemplate(fields,labels,eval_params);
    }
    else if(eval_params.type == "Account"){
      fields = this.salesforceBundle.accountFields.split(",");
      labels = this.accountInfo;
      var accountsTemplate = this.resourceSectionTemplate(fields,labels,eval_params);
      var opportunity_records = this.salesforceBundle.opportunityHash[eval_params.Id];
      resourceTemplate = accountsTemplate;
      if(opportunity_records && salesforceBundle.opportunityView == "1"){
        if(opportunity_records.length){
          resourceTemplate += this.getOpportunitiesTemplate(opportunity_records,eval_params,crmWidget);
        }
        else{
          resourceTemplate += this.getEmptyOpportunitiesTemplate(eval_params,crmWidget);
        }
      }
    }
    else if(eval_params.type == "Contact"){
      labels = this.contactInfo;
      fields = this.salesforceBundle.contactFields.split(",");
      resourceTemplate = this.resourceSectionTemplate(fields,labels,eval_params);
    }
    return resourceTemplate;
  },
  handleRender:function(contacts,crmWidget){
    if ( !this.allResponsesReceived() ) 
      return;
    this.loadIntegratedRemoteResource();
    if(contacts.length > 0) {
      if(contacts.length == 1) {
        this.processSingleResult(contacts[0],crmWidget);
      }
      else{
        this.renderSearchResults(crmWidget);
      }
    } 
    else {
      this.processEmptyResults(crmWidget);
    }
    jQuery("#"+crmWidget.options.widget_name).removeClass('loading-fb');
  },
  renderContactWidget:function(eval_params,crmWidget){
    var cw = this;
    var customer_emails = salesforceBundle.reqEmails.split(",");
    eval_params.count = crmWidget.contacts.length;
    eval_params.app_name = crmWidget.options.app_name;
    eval_params.widget_name = crmWidget.options.widget_name;
    eval_params.type = eval_params.type?eval_params.type:"" ; // Required
    eval_params.department = eval_params.department?eval_params.department:null;
    eval_params.url = eval_params.url?eval_params.url:"#";
    eval_params.address_type_span = eval_params.address_type_span || " ";
    eval_params.current_email = this.salesforceBundle.reqEmail;
    var contact_fields_template="";
    contact_fields_template = this.getTemplate(eval_params,crmWidget);
    var contact_template = (customer_emails.length > 1 && eval_params.count == 1)  ? cw.VIEW_CONTACT_MULTIPLE_EMAILS : cw.VIEW_CONTACT;
    crmWidget.options.application_html = function(){ return _.template(contact_template, eval_params)+""+contact_fields_template; } 
    this.removeError();
    this.removeLoadingIcon();
    crmWidget.display();
    this.bindParagraphReadMoreEvents();
    if(customer_emails.length > 1 && eval_params.count == 1){
      cw.showMultipleEmailResults();
    }
    var obj = this;
    jQuery('#' + crmWidget.options.widget_name).on('click','#search-back', (function(ev){
      ev.preventDefault();
      obj.resetOpportunityDialog();
      obj.renderSearchResults(crmWidget);
    }));
    if(eval_params.type == "Account"){
      this.handleOpportunitesSection(eval_params,crmWidget);
    }
  },
  renderSearchResults:function(crmWidget){
    var crmResults="";
    for(var i=0; i<crmWidget.contacts.length; i++){
      crmResults += '<li><a class="multiple-contacts salesforce-tooltip" title="'+crmWidget.contacts[i].Name+'" href="#" data-contact="' + i + '">'+crmWidget.contacts[i].Name+'</a><span class="contact-search-result-type pull-right">'+crmWidget.contacts[i].type+'</span></li>';
    }
    var results_number = {resLength: crmWidget.contacts.length, requester: crmWidget.options.reqEmail, resultsData: crmResults};
    this.renderSearchResultsWidget(results_number,crmWidget);
    var obj = this;
    var sf_resource = undefined;
    jQuery('#' + crmWidget.options.widget_name).off('click','.multiple-contacts').on('click','.multiple-contacts', (function(ev){
      ev.preventDefault();
      sf_resource = crmWidget.contacts[jQuery(this).data('contact')];
      obj.handleSalesforceResource(sf_resource,crmWidget);
    }));
  },
  renderSearchResultsWidget:function(results_number,crmWidget){
    var cw=this;
    var customer_emails = salesforceBundle.reqEmails.split(",");
    results_number.widget_name = crmWidget.options.widget_name;
    results_number.current_email = this.salesforceBundle.reqEmail;
    var resultsTemplate = "";
    resultsTemplate = customer_emails.length > 1 ? cw.CONTACT_SEARCH_RESULTS_MULTIPLE_EMAILS : cw.CONTACT_SEARCH_RESULTS;
    crmWidget.options.application_html = function(){ return _.template(resultsTemplate, results_number); } 
    crmWidget.display();
    if(customer_emails.length > 1){
      cw.showMultipleEmailResults();
    }
  },
  allResponsesReceived:function(){
    return (this.searchCount <= ++this.searchResultsCount );
  },
  eliminateNullValues:function(input){
    input = (input == null)? "NA":input
    return input;
  },
  resourceSectionTemplate:function(fields,labels,eval_params){
    var contactTemplate ="";
    for(var i=0;i<fields.length;i++){
      var value = eval_params[fields[i]];
      if(fields[i]=="Name" && eval_params.type != "Opportunity"){
        continue;
      }
      // Placing external link in the name field of opportunity
      else if(fields[i]=="Name" && eval_params.type == "Opportunity"){
        var opp_external_link = salesforceBundle.domain+"/"+eval_params.Id;
        contactTemplate+= '<div class="salesforce-widget">' +
          '<div class="clearfix">' +
            '<span class="ellipsis"><span class="tooltip" title="'+labels[fields[i]]+'">'+labels[fields[i]]+':</span></span>' +
          '<label id="contact-'+fields[i]+'"><a target="_blank" href="'+opp_external_link+'">'+value+'</a></label>' +
          '</div></div>'; 
        continue;
      }
      if(value==null || value == undefined){
        value ="N/A";
      }
        contactTemplate+= '<div class="salesforce-widget">' +
          '<div class="clearfix">' +
            '<span class="ellipsis"><span class="tooltip" title="'+labels[fields[i]]+'">'+labels[fields[i]]+':</span></span>' +
          '<label class="para-less" id="contact-'+fields[i]+'">'+value+'</label>' +
          '<span class="toggle-para q-para-span hide"><p class="q-marker-more"></p></span>'+
          '</div></div>'; 
    }
    if(eval_params.type == "Opportunity"){
      contactTemplate = _.template('<div class="opportunity_details mt5 ml12 hide"><%=contactTemplate%></div>',{contactTemplate:contactTemplate});
    }
    return contactTemplate;
  },
  processSingleResult:function(contact,crmWidget){
    if(contact.type == "Account" && salesforceBundle.opportunityView == "1"){
      this.getRelatedOpportunities(contact,crmWidget); //This will render single account and it also triggers related opportunities
    }
    else{
      this.renderContactWidget(contact,crmWidget);
    }
  },
  processEmptyResults:function(crmWidget){
    var customer_emails = salesforceBundle.reqEmails.split(",");
    if(customer_emails.length > 1){
      this.renderEmailSearchEmptyResults(crmWidget);
    }
    else{
      crmWidget.renderContactNa();
    }
  },
  loadIntegratedRemoteResource:function(){
    var obj = this;
    freshdeskWidget.request({
      event:"integrated_resource", 
      source_url:"/integrations/service_proxy/fetch",
      app_name:"salesforce",
      payload: JSON.stringify({ ticket_id:salesforceBundle.ticket_id }),
      on_success: function(response){
        response = response.responseJSON;
        if(!_.isEmpty(response)){
          salesforceBundle.remote_integratable_id = response.remote_integratable_id;
        }
        else{
          salesforceBundle.remote_integratable_id = "";
        }
      },
      on_failure: function(response){} 
    });
  },
  getRelatedOpportunities:function(eval_params,crmWidget,linkFlag){
    this.showLoadingIcon(crmWidget.options.widget_name);
    var obj = this;
    freshdeskWidget.request({
        event:"fetch_user_selected_fields", 
        source_url:"/integrations/service_proxy/fetch",
        app_name:"salesforce",
        payload: JSON.stringify({ type:"opportunity", value:{ account_id:eval_params.Id }, ticket_id:salesforceBundle.ticket_id }),
        on_success: function(response){
          response = response.responseJSON
          obj.loadOpportunities(response,eval_params,crmWidget,linkFlag);
        },
        on_failure: function(response){
          var message = "Problem occured while fetching opportunties";
          obj.processFailure(eval_params,crmWidget,message);
        } 
    });
  },
  loadOpportunities:function(response,eval_params,crmWidget,linkFlag){
    var opp_records = response.records;
    var error=undefined;
    if(opp_records.length){
      var opp_fields = this.salesforceBundle.opportunityFields.split(",");
      for(i=0;i<opp_records.length;i++){
        for(j=0;j<opp_fields.length;j++){
          if(typeof opp_records[i][opp_fields[j]] == "boolean"){
            continue;
          }
          opp_records[i][opp_fields[j]] = escapeHtml(this.eliminateNullValues(opp_records[i][opp_fields[j]]));
          if(opp_fields[j] == "CloseDate"){ //Converting close date to user readable format
            opp_records[i][opp_fields[j]] = new Date(opp_records[i][opp_fields[j]]).toString("dd MMM, yyyy");
          }
        }
      }
      this.salesforceBundle.opportunityHash[eval_params.Id] = opp_records;
    }
    else{
      this.salesforceBundle.opportunityHash[eval_params.Id] = [];
    }
    if(eval_params.error){ // This will show error in the opportunities section
      error = eval_params.error;
      eval_params.error = undefined;
      this.processFailure(eval_params,crmWidget,error);
    }
    else{
      this.renderContactWidget(eval_params,crmWidget);
    }
  },
  getOpportunitiesTemplate:function(opportunity_records,eval_params,crmWidget){
    var opportunities_template = "";
    for(var i=0;i<opportunity_records.length;i++){
      opportunities_template += this.getOpportunityDetailsTemplate(opportunity_records[i]);
    }
    var opportunity = this.getOpportunityCreateTemplate(eval_params);
    opportunities_template = _.template(this.OPPORTUNITY_SEARCH_RESULTS,{resultsData:opportunities_template,opportunityCreateLink:opportunity.create_template,opportunityForm:opportunity.form_template});
    return opportunities_template;
  },
  getOpportunityDetailsTemplate:function(opportunity_record){
      var opportunity_template = "";
      var opportunity_list_item = "";
      var opportunity_link_template = "<span class='hide opportunity_link pull-right'><a href='#' class='#{opportunity_status}' id='#{opportunity_id}'>#{opportunity_status}</a></span>";
      var link_status = (opportunity_record["link_status"] == undefined) ? "" : opportunity_record["link_status"];
      var unlink_status = (opportunity_record["unlink_status"] == undefined) ? "" : opportunity_record["unlink_status"];
      opportunity_link_template = (salesforceBundle.agentSettings == "1") ? opportunity_link_template : "";
      if(link_status && unlink_status){
        if(opportunity_record["IsDeleted"]){ // Deleted flag will be shown for linked deleted opportunities
          opportunity_link_template += "<div class='opp-flag pull-right'>Deleted</div>";
        }
        else{
          opportunity_link_template += "<div class='opp-flag pull-right'>Linked</div>";
        }
        opportunity_list_item += opportunity_link_template.interpolate({opportunity_id:opportunity_record.Id,opportunity_status:"Unlink"});
      }
      else if(link_status === false){
        opportunity_list_item += opportunity_link_template.interpolate({opportunity_id:opportunity_record.Id,opportunity_status:"Link"});
      }
      opportunity_record["type"] = "Opportunity";
      opportunity_template += '<li><a class="multiple-opportunities salesforce-opportunity-tooltip" title="'+opportunity_record.Name+'" href="#">'+opportunity_record.Name+'</a>'+opportunity_list_item+'</li>';
      opportunity_template += this.resourceSectionTemplate(this.salesforceBundle.opportunityFields.split(","),this.opportunityInfo,opportunity_record);
      return opportunity_template;
  },
  getEmptyOpportunitiesTemplate:function(eval_params,crmWidget){
    var opportunity = this.getOpportunityCreateTemplate(eval_params);
    var opportunities_template = _.template(this.OPPORTUNITY_SEARCH_RESULTS_NA,{opportunityCreateLink:opportunity.create_template,opportunityForm:opportunity.form_template});
    return opportunities_template;
  },
  getOpportunityCreateTemplate:function(eval_params){
    var opportunity_create_template = "";
    var opportunity_form = "";
    var result = undefined;
    if(!salesforceBundle.remote_integratable_id && salesforceBundle.ticket_id){
      if(salesforceBundle.agentSettings == "1"){
        opportunity_create_template += '<div class="opportunity_create pull-right"><span class="contact-search-result-type"><a id="create_new_opp" href="#" rel="freshdialog" data-target="#create_sf_opportunity_'+eval_params.Id+'" data-title="Create Opportunity" data-width="500" data-keyboard="false" data-template-footer="">Create New</a></span></div>';
        var stage_options = salesforceBundle.opportunity_stage;
        var stage_dropdown_options = "";
        for(i=0;i<stage_options.length;i++){
          stage_dropdown_options += '<option id="'+i+'" value="'+stage_options[i][1]+'">'+stage_options[i][0]+'</option>';
        }
        opportunity_form += this.OPPORTUNITY_FORM.evaluate({stage_options:stage_dropdown_options,account_id:eval_params.Id});
      }
    }
    result = {create_template:opportunity_create_template,form_template:opportunity_form};
    return result;
  },
  handleOpportunitesSection:function(eval_params,crmWidget){
    var obj = this;
    var opportunity_records = this.salesforceBundle.opportunityHash[eval_params.Id];
    if(jQuery("#create_new_opp").length){
      jQuery(".salesforce_contacts_widget_bg").on('click','#create_new_opp',(function(ev){
        ev.preventDefault();
        obj.bindOpportunitySubmitEvents(eval_params,crmWidget);
      }));
    }
    if(opportunity_records && opportunity_records.length){
        obj.bindOpportunityEvents(opportunity_records);
        obj.bindOpportunityLinkEvents(eval_params,crmWidget);
    }
  },
  handleSalesforceResource:function(sf_resource,crmWidget){
    if(sf_resource.type == "Account" && salesforceBundle.opportunityView == "1"){ // This will handle opportunites if the opportunity_view is enabled
      var opportunity_records = this.salesforceBundle.opportunityHash[sf_resource.Id];
      if(opportunity_records == undefined){
        this.getRelatedOpportunities(sf_resource,crmWidget);
      }
      else{
        this.renderContactWidget(sf_resource,crmWidget);
      }
    }
    else{
      this.renderContactWidget(sf_resource,crmWidget);
    }
  },
  renderEmailSearchEmptyResults:function(crmWidget){
    var cw=this;
    crmWidget.options.application_html = function(){ return _.template(cw.EMAIL_SEARCH_RESULTS_NA,{current_email:cw.salesforceBundle.reqEmail});} 
    crmWidget.display();
    cw.showMultipleEmailResults();
  },
  showMultipleEmailResults:function(){
    var customer_emails = salesforceBundle.reqEmails.split(",");
    var email_dropdown_opts = "";
    var selected_opt = undefined;
    var active_class= undefined;
    for(var i = 0; i < customer_emails.length; i++) {
      selected_opt = "";
      active_class = "";
      if(this.salesforceBundle.reqEmail == customer_emails[i]){
        selected_opt += '<span class="icon ticksymbol"></span>'
        active_class = " active";
      }
      email_dropdown_opts += '<a href="#" class="cust-email'+active_class+'" data-email="'+customer_emails[i]+'">'+selected_opt+customer_emails[i]+'</a>';
    }
    jQuery("#leftViewMenu.fd-menu").html(email_dropdown_opts);
    jQuery('#email-dropdown-div').show();
    this.bindEmailChangeEvent();
  },
  processFailure:function(eval_params,crmWidget,msg){
    this.renderContactWidget(eval_params,crmWidget);
    this.showError(msg);
  },
  bindEmailChangeEvent:function(){
    var obj = this;
    //This will re-instantiate the salesforce object for every user email
    jQuery(".fd-menu .cust-email").on('click',function(ev){
      ev.preventDefault();
      obj.resetOpportunityDialog();
      jQuery("#salesforce_contacts_widget .content").html("");
      var email = jQuery(this).data('email');
      var newSalesforceBundle = obj.resetSalesforceBundle(obj.salesforceBundle);
      newSalesforceBundle.reqEmail = email;
      new SalesforceWidget(newSalesforceBundle);
    });
  },
  resetSalesforceBundle:function(salesforceBundle){
    var newSalesforceBundle = {};
    var bundleProperties = [
                              "domain","ticket_id","reqCompany","reqEmails",
                              "contactFields","opportunityFields","accountFields",
                              "contactLabels","opportunityLabels","accountLabels",
                              "leadLabels","leadFields","reqName"
                           ]
    for(i=0;i<bundleProperties.length;i++){
      newSalesforceBundle[bundleProperties[i]] = salesforceBundle[bundleProperties[i]];
    }
    return newSalesforceBundle;
  },
  bindOpportunityEvents:function(opportunity_records){
    jQuery(".multiple-opportunities").click(function(ev){
      ev.preventDefault();
      if(jQuery(this).parent().next(".opportunity_details").css('display') != 'none'){
        jQuery(".opportunity_link").hide();
        jQuery(".opp-flag").show();
        jQuery(this).css('color','');
        jQuery(this).parent().next(".opportunity_details").hide();
      }
      else{
        jQuery(".opportunity_link").hide();
        jQuery(".multiple-opportunities").css('color','')
        jQuery(".opportunity_details").hide();
        jQuery(this).siblings(".opp-flag").hide();
        jQuery(this).next(".opportunity_link").show();
        jQuery(this).css('color','#000');
        jQuery(this).parent().next(".opportunity_details").show();
      }
    });
  },
  bindOpportunityLinkEvents:function(eval_params,crmWidget){
    var obj = this;
    jQuery(".Link").off('click').on('click',function(ev){
      ev.preventDefault();
      var opportunity_id = jQuery(this).attr('id');
      obj.linkOpportunity(opportunity_id,eval_params,crmWidget);
    });
    jQuery(".Unlink").off('click').on('click',function(ev){
      ev.preventDefault();
      var opportunity_id = jQuery(this).attr('id');
      obj.unlinkOpportunity(opportunity_id,eval_params,crmWidget);
    });
  },
  bindOpportunitySubmitEvents:function(eval_params,crmWidget){
    var obj = this;
    var account_id = eval_params.Id;
    this.clearOpportunityFormErrors();
    jQuery("#opportunity-submit-"+account_id).off('click').on('click',function(ev){
      ev.preventDefault();
      jQuery(this).attr("disabled","disabled").val("Creating...");
      obj.createOpportunity(eval_params,crmWidget);
    });
    jQuery("#opportunity-cancel-"+account_id).off('click').on('click',function(ev){
      ev.preventDefault();
      jQuery("#create_sf_opportunity_"+account_id).modal("hide")
      obj.resetOpportunityForm(account_id);
    });
    jQuery("#create_sf_opportunity_"+account_id+" .close").on('click',function(ev){
      ev.preventDefault();
      obj.resetOpportunityForm(account_id);
    });
  },
  linkOpportunity:function(opportunity_id,eval_params,crmWidget){
    var obj = this;
    this.resetOpportunityDialog();
    this.showLoadingIcon("salesforce_contacts_widget");
    freshdeskWidget.request({
      event:"link_opportunity", 
      source_url:"/integrations/service_proxy/fetch",
      app_name:"salesforce",
      payload: JSON.stringify({ ticket_id:salesforceBundle.ticket_id, remote_id:opportunity_id }),
      on_success: function(response){
        response = response.responseJSON;
        obj.handleOpportunityLink(response,eval_params,crmWidget,opportunity_id,true);
      },
      on_failure: function(response){
        var message = response.responseJSON.message || response.responseJSON;
        obj.processFailure(eval_params,crmWidget,message);
      } 
    });
  },
  unlinkOpportunity:function(opportunity_id,eval_params,crmWidget){
    var obj = this;
    this.showLoadingIcon("salesforce_contacts_widget");
    freshdeskWidget.request({
      event:"unlink_opportunity", 
      source_url:"/integrations/service_proxy/fetch",
      app_name:"salesforce",
      payload: JSON.stringify({ ticket_id:salesforceBundle.ticket_id, remote_id:opportunity_id }),
      on_success: function(response){
        response = response.responseJSON;
        obj.handleOpportunityLink(response,eval_params,crmWidget,opportunity_id,false);
      },
      on_failure: function(response){
        var message = response.responseJSON.message || response.responseJSON;
        obj.processFailure(eval_params,crmWidget,message);
      } 
    });
  },
  handleOpportunityLink:function(response,eval_params,crmWidget,opportunity_id,linkStatus){
    if(response.error){
      eval_params.error = response.error;
      salesforceBundle.remote_integratable_id = response.remote_id;
      this.removeOtherAccountOpportunities(eval_params);
      this.getRelatedOpportunities(eval_params,crmWidget);
    }
    else{
      salesforceBundle.remote_integratable_id = linkStatus ? opportunity_id : "";
      this.resetOtherAccountOpportunities(eval_params,linkStatus);
      this.getRelatedOpportunities(eval_params,crmWidget,linkStatus);
    }
  },
  createOpportunity:function(eval_params,crmWidget){
    var obj = this;
    if(salesforceWidget.validateInput()){
      jQuery("#salesforce-opportunity-validation-errors").hide();
      var date = new Date(jQuery("#opportunity_close_date").val()).toString("yyyy-MM-dd");
      var stage_name = jQuery("#opportunity_stage").val();
      var name = jQuery("#opportunity_name").val();
      var amount = jQuery("#opportunity_amount").val();
      var opportunity_params = { ticket_id:salesforceBundle.ticket_id, AccountId:eval_params.Id,Name:name, CloseDate:date, StageName:stage_name, Amount:amount};
      freshdeskWidget.request({
        event:"create_opportunity", 
        source_url:"/integrations/service_proxy/fetch",
        app_name:"salesforce",
        payload: JSON.stringify(opportunity_params),
        on_success:function(response){
          response = response.responseJSON;
          obj.processOpportunityPostCreate(response,eval_params,crmWidget);
        },
        on_failure:function(response){
          var message = response.responseJSON.message || response.responseJSON;
          jQuery("#opportunity-submit-"+eval_params.Id).removeAttr('disabled').val("Create");
          jQuery(".salesforce-opportunity-custom-errors").show().html("<span>Opportunity creation failed."+" "+message+"</span>");
        } 
      });
    }
    else{
      jQuery(".salesforce-opportunity-custom-errors").hide();
      jQuery("#opportunity-submit-"+eval_params.Id).removeAttr('disabled').val("Create");
    }
  },
  processOpportunityPostCreate:function(response,eval_params,crmWidget){
    jQuery("#create_sf_opportunity_"+eval_params.Id).modal("hide");
    this.resetOpportunityForm(eval_params.Id);
    if(response.error){
      eval_params.error = response.error;
      salesforceBundle.remote_integratable_id = response.remote_id;
      this.removeOtherAccountOpportunities(eval_params);
      this.resetOpportunityDialog();
      this.getRelatedOpportunities(eval_params,crmWidget);
    }
    else{
      this.linkOpportunity(response.id,eval_params,crmWidget);
    }
  },
  validateInput:function(){
    var datecheck = new Date($("opportunity_close_date").value.trim());
    jQuery(".salesforce-opportunity-custom-errors").hide();
    if(!$("opportunity_name").value.trim()){
      this.showValidationErrors("Please enter a name");
      return false;
    }
    if(!$("opportunity_stage").value.trim()){
      this.showValidationErrors("Please select an opportunity stage");
      return false;
    }
    if(!$("opportunity_close_date").value.trim() || datecheck.toString() == "Invalid Date"){
      this.showValidationErrors("Enter value for close date");
      return false;
    }
    if($("opportunity_amount").value.trim() && isNaN($("opportunity_amount").value)){
      this.showValidationErrors("Please enter valid amount");
      return false;
    }
    return true;
  },
  showValidationErrors:function(msg){
    jQuery("#salesforce-opportunity-validation-errors").text(msg);
    jQuery("#salesforce-opportunity-validation-errors").show();
  },
  resetOtherAccountOpportunities:function(eval_params,link_status){
    var records = undefined;
    for(key in this.salesforceBundle.opportunityHash){
      records = this.salesforceBundle.opportunityHash[key];
      if (key != eval_params.Id && records.length){
        for(i=0;i<records.length;i++){
          records[i]["link_status"] = link_status;
        }
        this.salesforceBundle.opportunityHash[key] = records;
      }
    }
  },
  removeOtherAccountOpportunities:function(eval_params){
    for(key in this.salesforceBundle.opportunityHash){
      if (key != eval_params.Id){
        this.salesforceBundle.opportunityHash[key] = undefined;
      }
    }
  },
  resetOpportunityForm:function(account_id){
    this.clearOpportunityFormErrors();
    jQuery("#opportunity-submit-"+account_id).removeAttr('disabled').val("Create");
    jQuery("#opportunity_stage").select2("val",salesforceBundle.opportunity_stage[0][1]);
    jQuery("#salesforce-opportunity-form")[0].reset();
  },
  clearOpportunityFormErrors:function(){
    jQuery("#salesforce-opportunity-validation-errors").hide();
    jQuery(".salesforce-opportunity-custom-errors").hide();
  },
  resetOpportunityDialog:function(){
    if(jQuery("#create_new_opp").data("freshdialog")){
        jQuery("#"+ jQuery("#create_new_opp").data("freshdialog").$dialogid).remove();
    }
  },
  showLoadingIcon:function(widget_name){
    jQuery("#"+widget_name+" .content").html("");
    jQuery("#"+widget_name).addClass('sloading loading-small');
  },
  showError:function(message){
    freshdeskWidget.alert_failure("The following error is reported:"+" "+message);
  },
  removeError:function(){
    jQuery("#salesforce_contacts_widget .error").html("").addClass('hide');
  },
  removeLoadingIcon:function(){
    jQuery("#salesforce_contacts_widget").removeClass('sloading loading-small');
  },
  initOpportunityHash:function(){
    this.salesforceBundle.opportunityHash = {};
  },
  bindParagraphReadMoreEvents:function(){
    var i = 1;
    jQuery(".para-less").each(function(){
      if(jQuery(this).actual('height') > 48){ // This event uses jquery.actual.min.js plugin to find the height of hidden element
        jQuery(this).addClass('para-min-lines');
        jQuery(this).attr('tabIndex',i);
        jQuery(this).next(".toggle-para").addClass('active-para').removeClass('hide');
        i++;
      }
    });
    jQuery('.toggle-para.active-para p').click(function(){
      jQuery(this).parent().toggleClass('q-para-span');
      jQuery(this).parent().prev(".para-less").toggleClass('para-min-lines para-max-lines');
      jQuery(this).toggleClass('q-marker-more q-marker-less');
      jQuery(this).parent().prev(".para-less").focus();
    });
  },

  VIEW_CONTACT:
    '<div class="title <%=widget_name%>_bg">' +
      '<div class="row-fluid">' +
        '<div id="contact-name" class="span8">'+
        '<a id="search-back" href="#"><div class="search-back <%=(count>1 ? "": "hide")%>"> <i class="arrow-left"></i> </div></a>'+
        '<a title="<%=Name%>" target="_blank" href="<%=url%>" class="sales-title salesforce-tooltip"><%=Name%></a></div>' +
        '<div class="span4 pt3"><span class="contact-search-result-type pull-right"><%=(type || "")%></span></div>'+
      '</div>' + 
    '</div>',
  VIEW_CONTACT_MULTIPLE_EMAILS:
    '<div class="title <%=widget_name%>_bg">' +
      '<div id="email-dropdown-div" class="view_filters mb10 hide"><div class="link_item"><a href class="drop-right nav-trigger" id="active_filter" menuid="#leftViewMenu"><%=current_email%></a></div><div class="fd-menu" id="leftViewMenu" style="display: none; visibility: visible;"></div></div>'+
      '<div class="single-result row-fluid">' +
        '<div id="contact-name" class="span8">'+
        '<a id="search-back" href="#"><div class="search-back <%=(count>1 ? "": "hide")%>"> <i class="arrow-left"></i> </div></a>'+
        '<a title="<%=Name%>" target="_blank" href="<%=url%>" class="sales-title salesforce-tooltip"><%=Name%></a></div>' +
        '<div class="span4 pt3"><span class="contact-search-result-type pull-right"><%=(type || "")%></span></div>'+
      '</div>' + 
    '</div>',
  CONTACT_SEARCH_RESULTS_MULTIPLE_EMAILS:
    '<div class="title <%=widget_name%>_bg">' +
      '<div id="email-dropdown-div" class="view_filters hide"><div class="link_item"><span class="pull-right"><%=resLength%> Results</span><a href class="drop-right nav-trigger" id="active_filter" menuid="#leftViewMenu"><%=current_email%></a></div><div class="fd-menu" id="leftViewMenu" style="display: none; visibility: visible;"></div></div>'+
      '<div id="search-results"><ul id="contacts-search-results"><%=resultsData%></ul></div>'+
    '</div>',
  CONTACT_SEARCH_RESULTS:
    '<div class="title <%=widget_name%>_bg">' +
      '<div id="number-returned"><b> <%=resLength%> results for <%=requester%> </b></div>'+
      '<div id="search-results"><ul id="contacts-search-results"><%=resultsData%></ul></div>'+
    '</div>',
  EMAIL_SEARCH_RESULTS_NA:
    '<div class="title salesforce_contacts_widget_bg">' +
      '<div id="email-dropdown-div" class="view_filters hide"><div class="link_item"><a href class="drop-right nav-trigger" id="active_filter" menuid="#leftViewMenu"><%=current_email%></a></div><div class="fd-menu" id="leftViewMenu" style="display: none; visibility: visible;"></div></div>'+
      '<div id="search-results" class="mt20">'+
      '<span id="contact-na">No results found for <%=current_email%></span>'+
      '</div>'+
    '</div>',
  OPPORTUNITY_SEARCH_RESULTS:
    '<div class="bottom_div mt10 mb10"></div>'+
    '<div class="title salesforce_contacts_widget_bg">' +
      '<div id="opportunities"><b>Opportunities</b></div>'+
      '<%=opportunityCreateLink%>'+
      '<div id="search-results"><ul id="contacts-search-results"><%=resultsData%></ul></div>'+
      '<%=opportunityForm%>'+
    '</div>',
  OPPORTUNITY_SEARCH_RESULTS_NA:
    '<div class="bottom_div mt10 mb10"></div>'+
    '<div class="title contact-na salesforce_contacts_widget_bg">' +
      '<div id="opportunities"><b>Opportunities</b></div>'+
      '<%=opportunityCreateLink%>'+
      '<div class="name"  id="contact-na">No opportunities found for this account</div>'+
      '<%=opportunityForm%>'+
    '</div>',
  OPPORTUNITY_FORM: new Template('<div id="create_sf_opportunity_#{account_id}" class="hide"> \
    <div id="salesforce-opportunity-validation-errors" class="alert alert-error mt0 mb16 hide"></div> \
    <div class="salesforce-opportunity-custom-errors alert alert-error mt0 mb16 hide"></div> \
    <form action="#" class="salesforceOpportunity form-horizontal" id="salesforce-opportunity-form"> \
      <div class="opportunity-form-contents"> \
          <div class="row-fluid control-group"> \
            <label class="span2">\
              Name<span class="required_star">*</span> \
            </label>\
            <div class="span10"> \
                <input class="input-block-level required" type="text" id="opportunity_name"> \
            </div> \
          </div> \
          <div class="row-fluid control-group"> \
            <label class="span2">\
              Stage<span class="required_star">*</span> \
            </label>\
            <div class="span10"> \
              <select id="opportunity_stage" class="select2 select2-offscreen"> \
                #{stage_options}\
              </select> \
            </div> \
          </div> \
          <div class="row-fluid control-group"> \
              <div class="span6"> \
                <label class="span4">\
                  CloseDate<span class="required_star">*</span> \
                </label>\
                <div class="datefield input-date-field span8"> \
                    <input id="opportunity_close_date" class="date datepicker_popover hasDatePicker" data-date-format="d M, yy" readonly="readonly" type="text"/> \
                    <button type="button" class="ui-datepicker-trigger"><i class="ficon-calendar"></i></button> \
                </div> \
              </div> \
              <div class="span6">\
                <label class="span4 pl11">\
                  Amount \
                </label>\
              <div class="span8"> \
                <input id="opportunity_amount" type="text"/> \
              </div> \
              </div> \
          </div> \
          <div class="row-fluid control-group pull-right submit-buttons"> \
            <input type="submit" id="opportunity-submit-#{account_id}" class="btn btn-primary pull-right ml10" value="Create"> \
            <input type="button" id="opportunity-cancel-#{account_id}" class="btn pull-right" value="Cancel" > \
          </div> \
      </div> \
    </form> \
  </div>')
}

//update widgets inner join applications on applications.id = widgets.application_id set script=replace(script, " token:", "oauth_token:") where applications.name="salesforce";
