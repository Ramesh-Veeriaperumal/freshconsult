var NimbleWidget = Class.create();
NimbleWidget.prototype= {

  initialize:function(nimbleBundle){
    jQuery("#nimble_widget").addClass('loading-fb');
    nimbleWidget = this;
    nimbleBundle.app_name = "Nimble";
    nimbleBundle.integratable_type = "crm";
    nimbleBundle.auth_type = "OAuth";
    nimbleBundle.url_token_key = "access_token"
    nimbleBundle.domain = "https://api.nimble.com"
    this.nimbleBundle = nimbleBundle;
    freshdeskWidget = new Freshdesk.CRMWidget(nimbleBundle, this);
  },

  get_contact_request: function() {
    return { rest_url: "/api/v1/contacts/list?keyword="+this.nimbleBundle.reqEmail };
  },

  parse_contact: function(resJson, response){
    var contacts = [];
    var nimble_domain = response.getHeader('x-nimble-domain');
    for(var i=0;i<resJson.resources.length;i++){
      var resource = resJson.resources[i];
      var contact_data = {name: '', designation: null, company: '', company_url: null, phone: 'N/A', mobile: 'N/A', department: null, 
                            address: 'N/A', type: 'Contact', url: "http://" + nimble_domain +"/#app/contacts/view?id="+resource.id};
      if(resource.fields['first name']) contact_data['name'] = resource.fields['first name'][0].value;
      if(resource.fields['last name']) contact_data['name'] = contact_data['name'] + " " + resource.fields['last name'][0].value;
      if(resource.fields['parent company']) {
        var comp = resource.fields['parent company'][0];
        contact_data['company'] = comp.value;
        contact_data['company_url'] = "http://" + nimble_domain +"/#app/contacts/view?id="+comp.extra_value;
      }
      var phones = resource.fields['phone'];
      if(phones) {
        for(var j=0;j<phones.length;j++){
          var type = phones[j]["modifier"];
          if(type == 'work') contact_data['phone'] = phones[j].value;
          if(type == 'home' && contact_data['phone'] == 'N/A') contact_data['phone'] = phones[j].value;
          if(type == 'mobile') contact_data['mobile'] = phones[j].value;
        }
      }
      var addresses = resource.fields['address'];
      if(addresses) {
        contact_data['address'] = "";
        for(var j=0;j<addresses.length;j++){
          var type = addresses[j]["modifier"];
          if(type == 'work') contact_data['address'] = this.getFormattedAddress(addresses[j].value);
          if(type == 'home' && contact_data['address'] == 'N/A') {
            contact_data['address'] = this.getFormattedAddress(addresses[j].value);
          }
        }
      }
      if(resource.fields['title']) contact_data['designation'] = resource.fields['title'][0].value;
      if(resource.fields['lead type']) contact_data['type'] = resource.fields['lead type'][0].value;
      contacts.push(contact_data);
    }
    return contacts;
  },

  getFormattedAddress: function(addr_val){
    var addr = "";var sep = "";
    addr_val = JSON.parse(addr_val);
    for (var key in addr_val) {
      addr += sep + addr_val[key]; sep=", ";
    }
    return addr;
  }
}

nimbleWidget = new NimbleWidget(nimbleBundle);
