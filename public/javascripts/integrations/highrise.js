var HighriseWidget = Class.create();
HighriseWidget.prototype= {

  initialize:function(highrise_options){
    jQuery("#highrise_widget").addClass('loading-fb');
    highrise_options.app_name = "Highrise";
    highrise_options.widget_name = "highrise_widget";
    highrise_options.ssl_enabled = true;
    highrise_options.username = highrise_options.k;
    this.highrise_options = highrise_options;
    this.freshdeskWidget = new Freshdesk.CRMWidget(highrise_options, this);
  },

  get_contact_request: function(highrise_options) {
    email = this.highrise_options.reqEmail;
    return {resource: "people/search.xml?criteria[email]=" + email };
  },

  parse_contact: function(contactsJson){
    contacts = [];
    if(contactsJson.nil_classes)
      return contacts;
    contactsJson.people.each(function(cntJson){
      var cLink = "https://"+this.highrise_options.domain+"/people/"+cntJson.id;
      fullName = (cntJson.first_name || "") + " " + (cntJson.last_name || "");
      contact_data = cntJson.contact_data;
      cCompany = cntJson.company_name;
      cCompanyUrl = (cntJson.company_id ? ("https://"+this.highrise_options.domain+"/companies/"+cntJson.company_id) : null);
      cPhone = contact_data.phone_numbers[0] ? contact_data.phone_numbers[0].number : "N/A";
      cMobile = contact_data.phone_numbers[1] ? contact_data.phone_numbers[1].number : "N/A";
      cWebsite = contact_data.web_addresses[0] ? contact_data.web_addresses[0].url : "N/A";
      address = contact_data.addresses[0] ? contact_data.addresses[0].street+", "+contact_data.addresses[0].city : "N/A";
      desig = cntJson.title;
      if(cCompany && !desig)
        desig = "Works"; 
      var cAddress = address || "N/A";
      contacts.push({ name: fullName,
                      url: cLink,
                      designation: desig,
                      company: cCompany,
                      company_url: cCompanyUrl,
                      address: cAddress,
                      address_type_span: "",
                      phone: cPhone,
                      mobile: cMobile,
                      website: cWebsite, 
                  });
    });
    return contacts;
  }
};

highriseWidget = new HighriseWidget(highrise_options);
