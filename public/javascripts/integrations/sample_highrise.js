var SampleHighriseWidget = Class.create();
SampleHighriseWidget.prototype= {

  initialize:function(sample_highrise_options){
    sample_highrise_options.app_name = "Sample CRM";
    sample_highrise_options.widget_name = "sample_highrise_widget";
    sample_highrise_options.ssl_enabled = true;
    sample_highrise_options.username = sample_highrise_options.api_key;
    cnt_req = this.get_contact_request(sample_highrise_options.reqEmail);
    sample_highrise_options.init_requests = [cnt_req];
    this.freshdeskWidget = new Freshdesk.Widget(sample_highrise_options, this);
  },

  get_contact_request: function(email) {
    req_obj = { 
      rest_url: "people.xml?email="+email,
      on_success: this.handleContactSuccess.bind(this)
    };
    return req_obj;
  },

  handleContactSuccess:function(response){
    resJson = response.responseJSON;
    this.contacts = this.parse_contact(resJson.people[0]);
    if (this.contacts.length > 0) {
      this.renderContactWidget(this.contacts[0]);
    } else {
      this.freshdeskWidget.alert_failure("Cannot find contact in Highrise. To test this submit a ticket with support@freshdesk.com as a requester.");
    }
    jQuery("#"+this.options.widget_name).removeClass('loading-fb');
  },

  parse_contact: function(cntJson){
    contacts = [];
    if(cntJson) {
      var cLink = "https://"+this.freshdeskWidget.options.domain+"/people/"+cntJson.id;
      fullName = cntJson.first_name+" "+cntJson.last_name;
      contact_data = cntJson.contact_data
      cCompany = cntJson.company_name || ""
      cCompanyUrl = "https://"+this.freshdeskWidget.options.domain+"/companies/"+cntJson.company_id || ""
      cPhone = contact_data.phone_numbers[0] ? contact_data.phone_numbers[0].number : "N/A";
      cMobile = contact_data.phone_numbers[1] ? contact_data.phone_numbers[1].number : "N/A";
      cWebsite = contact_data.web_addresses[0] ? contact_data.web_addresses[0].url : "N/A";
      address = contact_data.addresses[0] ? contact_data.addresses[0].street+", "+contact_data.addresses[0].city : "N/A";
      desig = cntJson.title
      var cAddress = address || "N/A";
      var cType = "Contact";
      contacts.push({name: fullName, designation: desig, phone: cPhone, mobile: cMobile, website: cWebsite, 
                    address: cAddress, company: cCompany, company_url: cCompanyUrl, type: cType, url: cLink});
    }
    return contacts;
  },

  renderContactWidget:function(cnt){
    cw=this;
    this.freshdeskWidget.options.application_html = function(){ return _.template(cw.VIEW_CONTACT, cnt); } 
    this.freshdeskWidget.display();
    jQuery("#"+this.freshdeskWidget.options.widget_name+" .contact-type").show();
  },

  VIEW_CONTACT:
    '<div class="title"> <div> <div id="contact-name"><a target="_blank" href="<%=url%>"><%=name%></a></div>'+
      '<div id="contact-desig"><%=designation%> at <a target="_blank" href="<%=company_url%>"><%=company%></a> </div> </div> </div>' + 
    '<div id="crm-contact"> <label>Address</label> <span id="contact-address"><%=address%></span> </div>'+   
    '<div  id="crm-phone"> <label>Phone</label> <span id="contact-phone"><%=phone%></span> </div>' +
    '<div id="crm-mobile"> <label>Mobile</label> <span id="contact-mobile"><%=mobile%></span> </div>' +
    '<div  id="crm-dept"> <label>Website</label> <span id="contact-dept"><%=website%></span> </div>'+   
    '<div class="external_link"><a target="_blank" id="crm-view" href="<%=url%>">View <span id="crm-contact-type"><%=type%></span> in Highrise</a></div>',
}

sampleHighriseWidget = new SampleHighriseWidget(sample_highrise_options);
