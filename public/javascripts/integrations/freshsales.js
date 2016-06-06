var FreshsalesWidget = Class.create();
FreshsalesWidget.prototype = {

  initialize:function(freshsalesBundle){
    jQuery("#freshsales_contacts_widget").addClass('loading-fb');
    freshsalesWidget = this;
    freshsalesBundle.app_name = "freshsales";
    freshsalesBundle.integratable_type = "crm";
    freshsalesBundle.auth_type = "NoAuth";
    freshsalesBundle.widget_name = "freshsales_contacts_widget";
    freshsalesBundle.handleRender = true;
    this.freshsalesBundle = freshsalesBundle;
    this.contactInfo = this.mapFieldLabels(freshsalesBundle.contactFields,freshsalesBundle.contactLabels);
    this.leadInfo = this.mapFieldLabels(freshsalesBundle.leadFields,freshsalesBundle.leadLabels);
    this.accountInfo = this.mapFieldLabels(freshsalesBundle.accountFields,freshsalesBundle.accountLabels);
    this.dealInfo = this.mapFieldLabels(freshsalesBundle.dealFields,freshsalesBundle.dealLabels);
    this.resourceMapper = { "contact":"contacts", "sales_account":"sales_accounts", "lead":"leads", "deal":"deals" }
    this.resourceType = { "contact":["Contact","contacts"], "sales_account":["Account","accounts"], "lead":["Lead","leads"], "deal":["Deal","deals"] }
    this.initDealHash();
    freshdeskWidget = new Freshdesk.CRMWidget(freshsalesBundle, this);
  },

  mapFieldLabels: function(fields,labels){
    var fieldLabelMapping = {};
    fieldsArray = (fields != undefined && fields != null) ? fields.split(",") : [];
    labelsArray = (labels != undefined && labels != null)? labels.split(",") : [];
    for(i=0;i<fieldsArray.length;i++){
      fieldLabelMapping[fieldsArray[i]] = escapeHtml(labelsArray[i]);
    }
    return fieldLabelMapping;
  },

  get_contact_request: function() {
    var requestUrls = [];
    var custEmail = this.freshsalesBundle.reqEmail;
    requestUrls.push( { type:"contact", value:{email:custEmail} } )
    requestUrls.push( { type:"lead", value:{email:custEmail} } )
    var custCompany = this.freshsalesBundle.reqCompany;
    var ticket_company = freshsalesBundle.ticket_company;
    if( this.freshsalesBundle.accountFields && this.freshsalesBundle.accountFields.length > 0 ) { //accountFields is configured
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
      requestUrls[i] = {  
                        event:"fetch_user_selected_fields", 
                        source_url:"/integrations/service_proxy/fetch",
                        app_name:"freshsales",
                        payload: JSON.stringify(requestUrls[i]) 
                       }
    }
    this.searchCount = requestUrls.length;
    this.searchResultsCount = 0;
    return requestUrls; 
  },

  getRelatedDeals:function(eval_params,crmWidget,linkFlag){
    this.showLoadingIcon(crmWidget.options.widget_name);
    var obj = this;
    freshdeskWidget.request({
        event:"fetch_user_selected_fields", 
        source_url:"/integrations/service_proxy/fetch",
        app_name:"freshsales",
        payload: JSON.stringify({ type:"deal", value:{ account_id:eval_params.id }, ticket_id:freshsalesBundle.ticket_id }),
        on_success: function(response){
          response = response.responseJSON
          obj.loadDeals(response,eval_params,crmWidget,linkFlag);
        },
        on_failure: function(response){
          var message = "Problem occured while fetching Deals";
          obj.processFailure(eval_params,crmWidget,message);
        } 
    });
  },

  parse_contact:function(resJson){
    var resources = [];
    var resource_type = resJson.type;
    resJson[this.resourceMapper[resource_type]].each(function(resource){
      var freshsalesResource = {};
      freshsalesResource["type"] = resource_type;
      freshsalesResource["url"] = this.freshsalesBundle.domain + "/" + this.freshsalesWidget.resourceType[resource_type][1] + "/" + resource["id"];
      if(resource_type == "contact"){
        if(this.freshsalesBundle.contactFields != undefined){
          contactfields = this.freshsalesBundle.contactFields.split(",");
          for (var i=0;i<contactfields.length;i++){
            freshsalesResource[contactfields[i]] = escapeHtml(this.freshsalesWidget.eliminateNullValues(resource[contactfields[i]]));
          }
        }
      }
      else if(resource_type == "sales_account"){
        freshsalesResource["id"] = resource["id"]; // This sets the freshsales account id as reference to fetch deals
        if(this.freshsalesBundle.accountFields != undefined){
          accountfields = this.freshsalesBundle.accountFields.split(",");
          for (var i=0;i<accountfields.length;i++){
            freshsalesResource[accountfields[i]] = escapeHtml(this.freshsalesWidget.eliminateNullValues(resource[accountfields[i]]));
          }
        }
      }
      else{
        if(this.freshsalesBundle.leadFields != undefined){
          leadFields = this.freshsalesBundle.leadFields.split(",");
          for (var i=0;i<leadFields.length;i++){
            freshsalesResource[leadFields[i]] = escapeHtml(this.freshsalesWidget.eliminateNullValues(resource[leadFields[i]]));
          }
        }
      }
      resources.push(freshsalesResource);
    });
    return resources;
  },

  resourceSectionTemplate:function(fields,labels,eval_params){
    var contactTemplate ="";
    for(var i=0;i<fields.length;i++){
      var value = eval_params[fields[i]];
      if((fields[i]== "name" || fields[i] == "display_name") && eval_params.type != "deal"){ 
        continue;
      }
      
      if(value==null || value == undefined){
        value ="N/A";
      }
        contactTemplate+= '<div class="freshsales-widget">' +
          '<div class="clearfix">' +
            '<span class="ellipsis"><span class="tooltip" title="'+labels[fields[i]]+'">'+labels[fields[i]]+':</span></span>' +
          '<label class="para-less fs-resource-'+fields[i]+'">'+value+'</label>' +
          '<span class="toggle-para q-para-span hide"><p class="q-marker-more"></p></span>'+
          '</div></div>'; 
    }
    if(eval_params.type == "deal"){
      contactTemplate = _.template('<div class="deal_details mt5 ml12 hide"><%=contactTemplate%></div>',{contactTemplate:contactTemplate});
    }
    return contactTemplate;
  },

  getTemplate:function(eval_params,crmWidget){
    var resourceTemplate = "";
    var fields = undefined;
    var labels = undefined;
    if(eval_params.type == "lead"){
      fields = this.freshsalesBundle.leadFields.split(",");
      labels = this.leadInfo;
      resourceTemplate = this.resourceSectionTemplate(fields,labels,eval_params);
    }
    else if(eval_params.type == "sales_account"){
      fields = this.freshsalesBundle.accountFields.split(",");
      labels = this.accountInfo;
      var accountsTemplate = this.resourceSectionTemplate(fields,labels,eval_params);
      var deal_records = this.freshsalesBundle.dealHash[eval_params.id];
      resourceTemplate = accountsTemplate;
      if(deal_records && freshsalesBundle.dealView == "1"){
        if(deal_records.length){
          resourceTemplate += this.getDealsTemplate(deal_records,eval_params,crmWidget);
        }
        else{
          resourceTemplate += this.getEmptyDealsTemplate(eval_params,crmWidget);
        }
      }
    }
    else if(eval_params.type == "contact"){
      labels = this.contactInfo;
      fields = this.freshsalesBundle.contactFields.split(",");
      resourceTemplate = this.resourceSectionTemplate(fields,labels,eval_params);
    }
    return resourceTemplate;
  },

  handleRender:function(resources,crmWidget){
    if ( !this.allResponsesReceived() ) {
      return;
    }
    this.loadIntegratedRemoteResource();
    if(resources.length > 0) {
      if(resources.length == 1) {
        this.processSingleResult(resources[0],crmWidget);
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

  processSingleResult:function(resource,crmWidget){
    if(resource.type == "sales_account" && freshsalesBundle.dealView == "1"){
      this.getRelatedDeals(resource,crmWidget); //This will render single account and it also triggers related deals
    }
    else{
      this.renderContactWidget(resource,crmWidget);
    }
  },

  loadIntegratedRemoteResource:function(){
    var obj = this;
    freshdeskWidget.request({
      event:"integrated_resource", 
      source_url:"/integrations/service_proxy/fetch",
      app_name:"freshsales",
      payload: JSON.stringify({ ticket_id:freshsalesBundle.ticket_id }),
      on_success: function(response){
        response = response.responseJSON;
        if(!_.isEmpty(response)){
          freshsalesBundle.remote_integratable_id = response.remote_integratable_id;
        }
        else{
          freshsalesBundle.remote_integratable_id = "";
        }
      },
      on_failure: function(response){} 
    });
  },

  loadDeals:function(response,eval_params,crmWidget,linkFlag){
    var deal_records = response.deals;
    var error=undefined;
    if(deal_records.length){
      var deal_fields = this.freshsalesBundle.dealFields.split(",");
      for(i=0;i<deal_records.length;i++){
        for(j=0;j<deal_fields.length;j++){
          if(typeof deal_records[i][deal_fields[j]] == "boolean"){
            continue;
          }
          deal_records[i][deal_fields[j]] = escapeHtml(this.eliminateNullValues(deal_records[i][deal_fields[j]]));
          if(deal_fields[j] == "expected_close" || deal_fields[j] == "closed_date"){ //Converting close date to user readable format
            if(deal_records[i][deal_fields[j]] && deal_records[i][deal_fields[j]] != "NA"){
              deal_records[i][deal_fields[j]] = new Date(deal_records[i][deal_fields[j]]).toString("dd MMM, yyyy");
            }
          }
        }
      }
      this.freshsalesBundle.dealHash[eval_params.id] = deal_records;
    }
    else{
      this.freshsalesBundle.dealHash[eval_params.id] = [];
    }
    if(eval_params.error){ // This will show error in the deals section
      error = eval_params.error;
      eval_params.error = undefined;
      this.processFailure(eval_params,crmWidget,error);
    }
    else{
      this.renderContactWidget(eval_params,crmWidget);
    }
  },

  getDealsTemplate:function(deal_records,eval_params,crmWidget){
    var deals_template = "";
    for(var i=0;i<deal_records.length;i++){
      deals_template += this.getDealDetailsTemplate(deal_records[i]);
    }
    var deal = this.getDealCreateTemplate(eval_params);
    deals_template = _.template(this.DEAL_SEARCH_RESULTS,{resultsData:deals_template,dealCreateLink:deal.create_template,dealForm:deal.form_template});
    return deals_template;
  },

  getDealDetailsTemplate:function(deal_record){
      var deal_template = "";
      var deal_list_item = "";
      var deal_link_template = "<span class='hide deal_link pull-right'><a href='#' class='freshsales-#{deal_status}' id='#{deal_id}'>#{deal_status}</a></span>";
      var link_status = (deal_record["link_status"] == undefined) ? "" : deal_record["link_status"];
      var unlink_status = (deal_record["unlink_status"] == undefined) ? "" : deal_record["unlink_status"];
      deal_link_template = (freshsalesBundle.agentSettings == "1") ? deal_link_template : "";
      if(link_status && unlink_status){
        deal_link_template += "<div class='deal-flag pull-right'>Linked</div>";
        deal_list_item += deal_link_template.interpolate({deal_id:deal_record.id,deal_status:"Unlink"});
      }
      else if(link_status === false){
        deal_list_item += deal_link_template.interpolate({deal_id:deal_record.id,deal_status:"Link"});
      }
      deal_record["type"] = "deal";
      deal_template += '<li><a class="multiple-opportunities salesforce-opportunity-tooltip" title="'+deal_record.name+'" href="#">'+deal_record.name+'</a>'+deal_list_item+'</li>';
      deal_template += this.resourceSectionTemplate(this.freshsalesBundle.dealFields.split(","),this.dealInfo,deal_record);
      return deal_template;
  },

  getEmptyDealsTemplate:function(eval_params,crmWidget){
    var deal = this.getDealCreateTemplate(eval_params);
    var deals_template = _.template(this.DEAL_SEARCH_RESULTS_NA,{dealCreateLink:deal.create_template,dealForm:deal.form_template});
    return deals_template;
  },

  getDealCreateTemplate:function(eval_params){
    var deal_create_template = "";
    var deal_form = "";
    var result = undefined;
    if(!freshsalesBundle.remote_integratable_id && freshsalesBundle.ticket_id){
      if(freshsalesBundle.agentSettings == "1"){
        deal_create_template += '<div class="deal_create pull-right"><span class="contact-search-result-type"><a id="create_new_deal" href="#" rel="freshdialog" data-target="#create_freshsales_deal_'+eval_params.id+'" data-title="Create Deal" data-width="500" data-keyboard="false" data-template-footer="">Create New</a></span></div>';
        var stage_options = freshsalesBundle.deal_stage;
        var stage_dropdown_options = "";
        for(i=0;i<stage_options.length;i++){
          stage_dropdown_options += '<option id="'+i+'" value="'+stage_options[i][1]+'">'+stage_options[i][0]+'</option>';
        }
        deal_form += this.DEAL_FORM.evaluate({stage_options:stage_dropdown_options,account_id:eval_params.id});
      }
    }
    result = {create_template:deal_create_template,form_template:deal_form};
    return result;
  },

  processFailure:function(eval_params,crmWidget,msg){
    this.renderContactWidget(eval_params,crmWidget);
    this.showError(msg);
  },

  processEmptyResults:function(crmWidget){
    var customer_emails = freshsalesBundle.reqEmails.split(",");
    if(customer_emails.length > 1){
      this.renderEmailSearchEmptyResults(crmWidget);
    }
    else{
      crmWidget.renderContactNa();
    }
  },

  renderContactWidget:function(eval_params,crmWidget){
    var cw = this;
    var customer_emails = freshsalesBundle.reqEmails.split(",");
    eval_params.count = crmWidget.contacts.length;
    eval_params.app_name = crmWidget.options.app_name;
    eval_params.widget_name = crmWidget.options.widget_name;
    eval_params.type = eval_params.type?eval_params.type:"" ; // Required
    eval_params.url = eval_params.url?eval_params.url:"#";
    eval_params.current_email = this.freshsalesBundle.reqEmail;
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
      obj.resetDealDialog();
      obj.renderSearchResults(crmWidget);
    }));
    if(eval_params.type == "sales_account"){
      this.handleDealsSection(eval_params,crmWidget);
    }
  },

  handleDealsSection:function(eval_params,crmWidget){
    var obj = this;
    var deal_records = this.freshsalesBundle.dealHash[eval_params.id];
    if(jQuery("#create_new_deal").length){
      jQuery(".freshsales_contacts_widget_bg").on('click','#create_new_deal',(function(ev){
        ev.preventDefault();
        obj.bindDealSubmitEvents(eval_params,crmWidget);
      }));
    }
    if(deal_records && deal_records.length){
        obj.bindDealEvents(deal_records);
        obj.bindDealLinkEvents(eval_params,crmWidget);
    }
  },

  bindDealEvents:function(deal_records){
    jQuery(".multiple-opportunities").click(function(ev){
      ev.preventDefault();
      if(jQuery(this).parent().next(".deal_details").css('display') != 'none'){
        jQuery(".deal_link").hide();
        jQuery(".deal-flag").show();
        jQuery(this).css('color','');
        jQuery(this).parent().next(".deal_details").hide();
      }
      else{
        jQuery(".deal_link").hide();
        jQuery(".multiple-opportunities").css('color','')
        jQuery(".deal_details").hide();
        jQuery(this).siblings(".deal-flag").hide();
        jQuery(this).next(".deal_link").show();
        jQuery(this).css('color','#000');
        jQuery(this).parent().next(".deal_details").show();
      }
    });
  },

  // link and unlink classes has to be changed to avoid clash with salesforce
  bindDealLinkEvents:function(eval_params,crmWidget){
    var obj = this;
    jQuery(".freshsales-Link").off('click').on('click',function(ev){
      ev.preventDefault();
      var deal_id = jQuery(this).attr('id');
      obj.linkDeal(deal_id,eval_params,crmWidget);
    });
    jQuery(".freshsales-Unlink").off('click').on('click',function(ev){
      ev.preventDefault();
      var deal_id = jQuery(this).attr('id');
      obj.unlinkDeal(deal_id,eval_params,crmWidget);
    });
  },

  bindDealSubmitEvents:function(eval_params,crmWidget){
    var obj = this;
    var account_id = eval_params.id;
    this.clearDealFormErrors();
    jQuery("#deal-submit-"+account_id).off('click').on('click',function(ev){
      ev.preventDefault();
      jQuery(this).attr("disabled","disabled").val("Creating...");
      obj.createDeal(eval_params,crmWidget);
    });
    jQuery("#deal-cancel-"+account_id).off('click').on('click',function(ev){
      ev.preventDefault();
      jQuery("#create_freshsales_deal_"+account_id).modal("hide")
      obj.resetDealForm(account_id);
    });
    jQuery("#create_freshsales_deal_"+account_id+" .close").on('click',function(ev){
      ev.preventDefault();
      obj.resetDealForm(account_id);
    });
  },

  createDeal:function(eval_params,crmWidget){
    var obj = this;
    if(freshsalesWidget.validateInput()){
      jQuery("#freshsales-deal-validation-errors").hide();
      var date = "";
      if(jQuery("#deal_close_date").val().trim() != ""){
        date = new Date(jQuery("#deal_close_date").val()).toString("yyyy-MM-dd");
      }
      var stage_name = jQuery("#deal_stage").val();
      var name = jQuery("#deal_name").val();
      var amount = jQuery("#deal_amount").val();
      var deal_params = { ticket_id:freshsalesBundle.ticket_id, sales_account_id:eval_params.id,name:name, expected_close:date, deal_stage_id:stage_name, amount:amount};
      freshdeskWidget.request({
        event:"create_deal", 
        source_url:"/integrations/service_proxy/fetch",
        app_name:"freshsales",
        payload: JSON.stringify(deal_params),
        on_success:function(response){
          response = response.responseJSON;
          obj.processDealPostCreate(response,eval_params,crmWidget);
        },
        on_failure:function(response){
          var message = response.responseJSON.message || response.responseJSON;
          jQuery("#deal-submit-"+eval_params.id).removeAttr('disabled').val("Create");
          jQuery(".freshsales-deal-custom-errors").show().html("<span>Deal creation failed."+" "+message+"</span>");
        } 
      });
    }
    else{
      jQuery(".freshsales-deal-custom-errors").hide();
      jQuery("#deal-submit-"+eval_params.id).removeAttr('disabled').val("Create");
    }
  },

  processDealPostCreate:function(response,eval_params,crmWidget){
    jQuery("#create_freshsales_deal_"+eval_params.id).modal("hide");
    this.resetDealForm(eval_params.id);
    if(response.error){
      eval_params.error = response.error;
      freshsalesBundle.remote_integratable_id = response.remote_id;
      this.removeOtherAccountDeals(eval_params);
      this.resetDealDialog();
      this.getRelatedDeals(eval_params,crmWidget);
    }
    else{
      this.linkDeal(response.deal.id,eval_params,crmWidget);
    }
  },

  linkDeal:function(deal_id,eval_params,crmWidget){
    var obj = this;
    this.resetDealDialog();
    this.showLoadingIcon("freshsales_contacts_widget");
    freshdeskWidget.request({
      event:"link_deal", 
      source_url:"/integrations/service_proxy/fetch",
      app_name:"freshsales",
      payload: JSON.stringify({ ticket_id:freshsalesBundle.ticket_id, remote_id:deal_id }),
      on_success: function(response){
        response = response.responseJSON;
        obj.handleDealLink(response,eval_params,crmWidget,deal_id,true);
      },
      on_failure: function(response){
        var message = response.responseJSON.message || response.responseJSON;
        obj.processFailure(eval_params,crmWidget,message);
      } 
    });
  },

  unlinkDeal:function(deal_id,eval_params,crmWidget){
    var obj = this;
    this.showLoadingIcon("freshsales_contacts_widget");
    freshdeskWidget.request({
      event:"unlink_deal", 
      source_url:"/integrations/service_proxy/fetch",
      app_name:"freshsales",
      payload: JSON.stringify({ ticket_id:freshsalesBundle.ticket_id, remote_id:deal_id }),
      on_success: function(response){
        response = response.responseJSON;
        obj.handleDealLink(response,eval_params,crmWidget,deal_id,false);
      },
      on_failure: function(response){
        var message = response.responseJSON.message || response.responseJSON;
        obj.processFailure(eval_params,crmWidget,message);
      } 
    });
  },

  handleDealLink:function(response,eval_params,crmWidget,deal_id,linkStatus){
    if(response.error){
      eval_params.error = response.error;
      freshsalesBundle.remote_integratable_id = response.remote_id;
      this.removeOtherAccountDeals(eval_params);
      this.getRelatedDeals(eval_params,crmWidget);
    }
    else{
      freshsalesBundle.remote_integratable_id = linkStatus ? deal_id : "";
      this.resetOtherAccountDeals(eval_params,linkStatus);
      this.getRelatedDeals(eval_params,crmWidget,linkStatus);
    }
  },

  resetOtherAccountDeals:function(eval_params,link_status){
    var records = undefined;
    for(key in this.freshsalesBundle.dealHash){
      records = this.freshsalesBundle.dealHash[key];
      if (key != eval_params.id && records.length){
        for(i=0;i<records.length;i++){
          records[i]["link_status"] = link_status;
        }
        this.freshsalesBundle.dealHash[key] = records;
      }
    }
  },

  removeOtherAccountDeals:function(eval_params){
    for(key in this.freshsalesBundle.dealHash){
      if (key != eval_params.id){
        this.freshsalesBundle.dealHash[key] = undefined;
      }
    }
  },

  resetDealForm:function(account_id){
    this.clearDealFormErrors();
    jQuery("#deal-submit-"+account_id).removeAttr('disabled').val("Create");
    jQuery("#deal_stage").select2("val",freshsalesBundle.deal_stage[0][1]);
    jQuery("#freshsales-deal-form")[0].reset();
  },

  validateInput:function(){
    var datecheck = new Date($("deal_close_date").value.trim());
    jQuery(".freshsales-deal-custom-errors").hide();
    if(!$("deal_name").value.trim()){
      this.showValidationErrors("Please enter a name");
      return false;
    }
    if(!$("deal_stage").value.trim()){
      this.showValidationErrors("Please select a deal stage");
      return false;
    }
    if($("deal_close_date").value.trim() != "" && datecheck.toString() == "Invalid Date"){
      this.showValidationErrors("Enter value for close date");
      return false;
    }
    if(!$("deal_amount").value.trim() || isNaN($("deal_amount").value)){
      this.showValidationErrors("Please enter valid amount");
      return false;
    }
    return true;
  },

  clearDealFormErrors:function(){
    jQuery("#freshsales-deal-validation-errors").hide();
    jQuery(".freshsales-deal-custom-errors").hide();
  },

  renderSearchResults:function(crmWidget){
    var crmResults="";
    for(var i=0; i<crmWidget.contacts.length; i++){
      var name = crmWidget.contacts[i].name || crmWidget.contacts[i].display_name;
      crmResults += '<li><a class="multiple-contacts salesforce-tooltip" title="'+name+'" href="#" data-contact="' + i + '">'+name+'</a><span class="contact-search-result-type pull-right">'+this.resourceType[crmWidget.contacts[i].type][0]+'</span></li>';
    }
    var results_number = {resLength: crmWidget.contacts.length, requester: crmWidget.options.reqEmail, resultsData: crmResults};
    this.renderSearchResultsWidget(results_number,crmWidget);
    var obj = this;
    var freshsales_resource = undefined;
    jQuery('#' + crmWidget.options.widget_name).off('click','.multiple-contacts').on('click','.multiple-contacts', (function(ev){
      ev.preventDefault();
      freshsales_resource = crmWidget.contacts[jQuery(this).data('contact')];
      obj.handleFreshsalesResource(freshsales_resource,crmWidget);
    }));
  },

  handleFreshsalesResource:function(freshsales_resource,crmWidget){
    if(freshsales_resource.type == "sales_account" && freshsalesBundle.dealView == "1"){ // This will handle deals if the deal_view is enabled
      var deal_records = this.freshsalesBundle.dealHash[freshsales_resource.id];
      if(deal_records == undefined){
        this.getRelatedDeals(freshsales_resource,crmWidget);
      }
      else{
        this.renderContactWidget(freshsales_resource,crmWidget);
      }
    }
    else{
      this.renderContactWidget(freshsales_resource,crmWidget);
    }
  },

  renderSearchResultsWidget:function(results_number,crmWidget){
    var cw=this;
    var customer_emails = freshsalesBundle.reqEmails.split(",");
    results_number.widget_name = crmWidget.options.widget_name;
    results_number.current_email = this.freshsalesBundle.reqEmail;
    var resultsTemplate = "";
    resultsTemplate = customer_emails.length > 1 ? cw.CONTACT_SEARCH_RESULTS_MULTIPLE_EMAILS : cw.CONTACT_SEARCH_RESULTS;
    crmWidget.options.application_html = function(){ return _.template(resultsTemplate, results_number); } 
    crmWidget.display();
    if(customer_emails.length > 1){
      cw.showMultipleEmailResults();
    }
  },

  renderEmailSearchEmptyResults:function(crmWidget){
    var cw=this;
    crmWidget.options.application_html = function(){ return _.template(cw.EMAIL_SEARCH_RESULTS_NA,{current_email:cw.freshsalesBundle.reqEmail});} 
    crmWidget.display();
    cw.showMultipleEmailResults();
  },

  showMultipleEmailResults:function(){
    var customer_emails = freshsalesBundle.reqEmails.split(",");
    var email_dropdown_opts = "";
    var selected_opt = undefined;
    var active_class= undefined;
    for(var i = 0; i < customer_emails.length; i++) {
      selected_opt = "";
      active_class = "";
      if(this.freshsalesBundle.reqEmail == customer_emails[i]){
        selected_opt += '<span class="icon ticksymbol"></span>'
        active_class = " active";
      }
      email_dropdown_opts += '<a href="#" class="cust-email'+active_class+'" data-email="'+customer_emails[i]+'">'+selected_opt+customer_emails[i]+'</a>';
    }
    jQuery("#leftViewMenu.fd-menu").html(email_dropdown_opts);
    jQuery('#email-dropdown-div').show();
    this.bindEmailChangeEvent();
  },

  bindEmailChangeEvent:function(){
    var obj = this;
    //This will re-instantiate the freshsales object for every user email
    jQuery(".fd-menu .cust-email").on('click',function(ev){
      ev.preventDefault();
      obj.resetDealDialog();
      jQuery("#freshsales_contacts_widget .content").html("");
      var email = jQuery(this).data('email');
      var newFreshsalesBundle = obj.resetFreshsalesBundle(obj.freshsalesBundle);
      newFreshsalesBundle.reqEmail = email;
      new FreshsalesWidget(newFreshsalesBundle);
    });
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

  resetDealDialog:function(){
    if(jQuery("#create_new_deal").data("freshdialog")){
      jQuery("#"+ jQuery("#create_new_deal").data("freshdialog").$dialogid).remove();
    }
  },

  resetFreshsalesBundle:function(freshsalesBundle){
    var newFreshsalesBundle = {};
    var bundleProperties = [
                              "domain","ticket_id","reqCompany","reqEmails",
                              "contactFields","dealFields","accountFields",
                              "contactLabels","dealLabels","accountLabels",
                              "leadLabels","leadFields","reqName"
                           ]
    for(i=0;i<bundleProperties.length;i++){
      newFreshsalesBundle[bundleProperties[i]] = freshsalesBundle[bundleProperties[i]];
    }
    return newFreshsalesBundle;
  },

  allResponsesReceived:function(){
    return (this.searchCount <= ++this.searchResultsCount );
  },

  eliminateNullValues:function(input){
    input = (input == null)? "NA":input
    return input;
  },

  showValidationErrors:function(msg){
    jQuery("#freshsales-deal-validation-errors").text(msg);
    jQuery("#freshsales-deal-validation-errors").show();
  },

  showLoadingIcon:function(widget_name){
    jQuery("#"+widget_name+" .content").html("");
    jQuery("#"+widget_name).addClass('sloading loading-small');
  },

  showError:function(message){
    freshdeskWidget.alert_failure("The following error is reported:"+" "+message);
  },

  removeError:function(){
    jQuery("#freshsales_contacts_widget .error").html("").addClass('hide');
  },
  removeLoadingIcon:function(){
    jQuery("#freshsales_contacts_widget").removeClass('sloading loading-small');
  },

  initDealHash:function(){
    this.freshsalesBundle.dealHash = {};
  },

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
    '<div class="title freshsales_contacts_widget_bg">' +
      '<div id="email-dropdown-div" class="view_filters hide"><div class="link_item"><a href class="drop-right nav-trigger" id="active_filter" menuid="#leftViewMenu"><%=current_email%></a></div><div class="fd-menu" id="leftViewMenu" style="display: none; visibility: visible;"></div></div>'+
      '<div id="search-results" class="mt20">'+
      '<span id="contact-na">No results found for <%=current_email%></span>'+
      '</div>'+
    '</div>',

  VIEW_CONTACT:
    '<div class="title <%=widget_name%>_bg">' +
      '<div class="row-fluid">' +
        '<div id="contact-name" class="span8">'+
        '<a id="search-back" href="#"><div class="search-back <%=(count>1 ? "": "hide")%>"> <i class="arrow-left"></i> </div></a>'+
        '<a title="<%=name || display_name%>" target="_blank" href="<%=url%>" class="sales-title salesforce-tooltip"><%=name || display_name%></a></div>' +
        '<div class="span4 pt3"><span class="contact-search-result-type pull-right"><%=(freshsalesWidget.resourceType[type][0] || "")%></span></div>'+
      '</div>' + 
    '</div>',

  VIEW_CONTACT_MULTIPLE_EMAILS:
    '<div class="title <%=widget_name%>_bg">' +
      '<div id="email-dropdown-div" class="view_filters mb10 hide"><div class="link_item"><a href class="drop-right nav-trigger" id="active_filter" menuid="#leftViewMenu"><%=current_email%></a></div><div class="fd-menu" id="leftViewMenu" style="display: none; visibility: visible;"></div></div>'+
      '<div class="single-result row-fluid">' +
        '<div id="contact-name" class="span8">'+
        '<a id="search-back" href="#"><div class="search-back <%=(count>1 ? "": "hide")%>"> <i class="arrow-left"></i> </div></a>'+
        '<a title="<%=name || display_name%>" target="_blank" href="<%=url%>" class="sales-title salesforce-tooltip"><%=name || display_name%></a></div>' +
        '<div class="span4 pt3"><span class="contact-search-result-type pull-right"><%=(freshsalesWidget.resourceType[type][0] || "")%></span></div>'+
      '</div>' + 
    '</div>',

  DEAL_SEARCH_RESULTS:
    '<div class="bottom_div mt10 mb10"></div>'+
    '<div class="title freshsales_contacts_widget_bg">' +
      '<div id="deals"><b>Deals</b></div>'+
      '<%=dealCreateLink%>'+
      '<div id="search-results"><ul id="contacts-search-results"><%=resultsData%></ul></div>'+
      '<%=dealForm%>'+
    '</div>',

  DEAL_SEARCH_RESULTS_NA:
    '<div class="bottom_div mt10 mb10"></div>'+
    '<div class="title contact-na freshsales_contacts_widget_bg">' +
      '<div id="deals"><b>Deals</b></div>'+
      '<%=dealCreateLink%>'+
      '<div class="name"  id="contact-na">No Deals found for this account</div>'+
      '<%=dealForm%>'+
    '</div>',

  DEAL_FORM: new Template('<div id="create_freshsales_deal_#{account_id}" class="hide"> \
    <div id="freshsales-deal-validation-errors" class="alert alert-error mt0 mb16 hide"></div> \
    <div class="freshsales-deal-custom-errors alert alert-error mt0 mb16 hide"></div> \
    <form action="#" class="freshsalesDeal form-horizontal" id="freshsales-deal-form"> \
      <div class="deal-form-contents"> \
          <div class="row-fluid control-group"> \
            <label class="span3">\
              Name<span class="required_star">*</span> \
            </label>\
            <div class="span9"> \
                <input class="input-block-level required" type="text" id="deal_name"> \
            </div> \
          </div> \
          <div class="row-fluid control-group"> \
                <label class="span3">\
                  Deal Value <span class="required_star">*</span> \
                </label>\
              <div class="span4"> \
                <input id="deal_amount" type="text"/> \
              </div> \
          </div> \
          <div class="row-fluid control-group"> \
            <label class="span3">\
              Deal Stage<span class="required_star">*</span> \
            </label>\
            <div class="stagefield span4"> \
              <select id="deal_stage" class="dropdown select2 select2-offscreen"> \
                #{stage_options}\
              </select> \
            </div> \
          </div> \
          <div class="row-fluid control-group"> \
            <label class="span3">\
              Expected close date \
            </label>\
            <div class="datefield input-date-field span4 mt6"> \
                <input id="deal_close_date" class="date datepicker_popover hasDatePicker" data-date-format="d M, yy" readonly="readonly" type="text"/> \
                <button type="button" class="ui-datepicker-trigger"><i class="ficon-calendar"></i></button> \
            </div> \
          </div> \
          <div class="row-fluid control-group pull-right submit-buttons"> \
            <input type="submit" id="deal-submit-#{account_id}" class="btn btn-primary pull-right ml10" value="Create"> \
            <input type="button" id="deal-cancel-#{account_id}" class="btn pull-right" value="Cancel" > \
          </div> \
      </div> \
    </form> \
  </div>')
}