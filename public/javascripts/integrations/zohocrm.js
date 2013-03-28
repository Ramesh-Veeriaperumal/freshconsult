var ZohoCrmWidget = Class.create();
ZohoCrmWidget.prototype= {

  initialize:function(zohocrmBundle){
    jQuery("#zohocrm_widget").addClass('loading-fb');
    zohocrmWidget = this;
    zohocrmBundle.app_name = "ZohoCrm";
    zohocrmBundle.integratable_type = "crm";
    zohocrmBundle.auth_type = "UAuth";
    zohocrmBundle.url_token_key = "authtoken"
    zohocrmBundle.username = zohocrmBundle.k;
    zohocrmBundle.domain = "https://crm.zoho.com"
    this.zohocrmBundle = zohocrmBundle;
    freshdeskWidget = new Freshdesk.CRMWidget(zohocrmBundle, this);
  },

  get_contact_request: function() {
    return [{rest_url: "crm/private/json/Contacts/getSearchRecords?scope=crmapi&selectColumns=All&searchCondition=(Email|equals|"+this.zohocrmBundle.reqEmail+")"},
            {rest_url: "crm/private/json/Leads/getSearchRecords?scope=crmapi&selectColumns=All&searchCondition=(Email|equals|"+this.zohocrmBundle.reqEmail+")"}];
  },

  parse_contact: function(resJson){
    var contacts = [];
    if(resJson.response.result) {
      var resources = (resJson.response.result.Contacts ? resJson.response.result.Contacts : resJson.response.result.Leads).row;
      if(resources.length == undefined) resources = [resources];
      var cType = resJson.response.uri.indexOf("Contacts") == -1 ? "Lead" : "Contact"
      for(var i=0;i<resources.length;i++){
        var contact_data = {name: '', designation: null, company: '', company_url: null, phone: 'N/A', mobile: 'N/A', 
                              department: null, address: null, type: cType, url: ''};
        var row = resources[i].FL;
        for(var j=0;j<row.length;j++){
          key = row[j].val;
          value = row[j].content;
          if(key == 'First Name') contact_data['name'] = value + (contact_data['name'] ? ' '+contact_data['name'] : '');
          if(key == 'Last Name') contact_data['name'] = (contact_data['name'] ? contact_data['name']+' ' : '') + value;
          if(key == 'Designation') contact_data['designation'] = value;
          if(key == 'Account Name') contact_data['company'] = value;
          if(key == 'ACCOUNTID') contact_data['company_url'] = this.zohocrmBundle.domain+"/crm/ShowEntityInfo.do?module=Accounts&id="+value+"&isload=true";
          if(key == cType.toUpperCase()+'ID') contact_data['url'] = this.zohocrmBundle.domain+"/crm/ShowEntityInfo.do?module="+cType+"s&id="+value+"&isload=true";
          if(key == 'Phone') contact_data['phone'] = value;
          if(key == 'Mobile') contact_data['mobile'] = value;
          if(key == 'Department') contact_data['department'] = value;
          if(key == 'Mailing Zip') contact_data['address'] = (contact_data['address'] ? contact_data['address']+"-" : '') + value;
          if(['Mailing Street', 'Street', 'Mailing City', 'City', 'Mailing State', 'State', 'Mailing Country', 'Country'].indexOf(key) != -1 ) 
            contact_data['address'] = (contact_data['address'] ? contact_data['address']+", " : '') + value;
        }
        contact_data['address'] = contact_data['address'] || "N/A"
        contacts.push(contact_data);
      }
    }
    return contacts;
  }
}

zohocrmWidget = new ZohoCrmWidget(zohocrm_options);

// "[{\"content\": \"497946000000051003\", \"val\": \"CONTACTID\"}, {\"content\": \"Test\", \"val\": \"First Name\"}, {\"content\": \"1\", \"val\": \"Last Name\"}, {\"content\": \"test1@test.org\", \"val\": \"Email\"}, {\"content\": \"497946000000050003\", \"val\": \"SMCREATORID\"}, {\"content\": \"Rick Ross\", \"val\": \"Created By\"}, {\"content\": \"2012-01-26 06:29:28\", \"val\": \"Created Time\"}]"

