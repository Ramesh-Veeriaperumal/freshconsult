var SugarWidget = Class.create();
SugarWidget.prototype= {

    SUGAR_CONTACT:new Template(
        '<div>' +
            '<span class="contact-type hide"></span>' +
            '<div class="title salesforce_contacts_widget_bg">' +
                '<div class="row-fluid">' +             
                    '<div class="span8">' +
                        '<a id="search-back" href="#"><div class="search-back"> <i class="arrow-left"></i> </div></a>'+
                        '<span id="sugar-contact-name"></span>' +
                        '<div id="sugar-contact-desig"></div>'+
                    '</div>' + 
                '</div>' + 
            '</div>' + 
            '<div id="sugar-populate-custom-fields"></div>'+
            '<div class="external_link"><a target="_blank" id="sugar-crm-view">View <span id="sugar-crm-contact-type"></span></a></div>' +
        '</div>'
    ),

    SUGAR_CONTACT_NA:new Template(
        '<div class="title contact-na salesforce_contacts_widget_bg">' +
        '<h5 id="sugarcrm_title" class="mb5">#{app_name}</h5>'+
            '<div id="sugar-contact-na"></div>'+
        '</div>'
    ),

    SUGAR_SEARCH_RESULTS:new Template(
        '<div id="sugar-search-results-div" class="title salesforce_contacts_widget_bg">' +
        '<h5 id="sugarcrm_title" class="mb5">#{app_name}</h5>'+
            '<div><ul id="sugar-contacts-search-results"></ul></div>'+
        '</div>'
    ),

    initialize:function(bundle){
        jQuery("#sugarcrm_contacts_widget").addClass('loading-fb');
        var $this = this;
        $this.bundle = bundle;
        this.sugarResults = "";
        this.totalCount = 0;
        this.email_list = $this.bundle.reqEmail.split(',');
        this.existing_user = false;
        if(!this.bundle.accounts){
            this.existing_user = true;
            this.bundle.contacts = "department,phone_work,phone_mobile,primary_address_street,primary_address_street_2,primary_address_street_3,primary_address_state,primary_address_city,primary_address_country";
            this.bundle.leads = this.bundle.contacts;
        }
        this.entryList = {};
        this.failureCount = 0;
        var init_reqs = [];
        if(bundle.domain) {
            $this.freshdeskWidget = new Freshdesk.Widget({
                app_name:           "SugarCRM",
                widget_name:        "sugarcrm_contacts_widget",
                application_id:     bundle.application_id,
                integratable_type:  "crm",
                domain:             bundle.domain,
                use_server_password:"true",
                ssl_enabled:        bundle.ssl_enabled || "false"
            });
            $this.check_sugar_session();
        }
        else {
            $this.processFailure();
        }
    },

    check_sugar_session:function (callBack) {
        var $this = this;
        $this.freshdeskWidget.request({
            source_url:   "/integrations/sugarcrm/check_session_id",
            content_type: "application/json",
            method:       "post",
            on_success:   function(evt) {
                var resJ = $this.get_json(evt);
                if(resJ["status"] == true){
                    $this.get_sugar_contact();
                }
                else {
                    $this.get_sugar_session();
                }
            },
            on_failure: $this.processVersionFailure.bind(this)
        });
    },

    get_sugar_contact:function(){
        var $this           = this,
            emailList       = "\'" + this.email_list.join("','") + "\'",
            selectFields    = "name\",\"title\",\"account_name\",\"account_id\",\"" + this.bundle.contacts.replace(/,/g,"\",\""),
            entry_list_body = 'method=get_entry_list&input_type=JSON&response_type=JSON&rest_data={"session":"%{SESSION_ID}","module_name":"Contacts","query":"#{email_query}","order_by":"", "offset":0,"select_fields":["#{select_fields}"],"link_name_to_fields_array":[],"max_results":"","deleted":0}';

        $this.freshdeskWidget.request({
            rest_url:     "service/v4/rest.php",
            method:       "post",
            body:         entry_list_body.interpolate({email_query: "contacts.id in (SELECT eabr.bean_id FROM email_addr_bean_rel eabr JOIN email_addresses ea ON (ea.id = eabr.email_address_id) WHERE eabr.deleted=0 AND ea.email_address in ("+ emailList +"))", select_fields: selectFields}),
            content_type: "", //Sugar accepts a mix of key-value pairs and json data as an input param as given in the above session_body variable. so content_type will not be json.
            on_failure:   $this.processFailure,
            on_success:   function(evt) {
                $this.handleSuccess(evt,"Contacts");
            }
        });
    },

    get_sugar_account:function(){
        var $this           = this, 
            selectFields    = this.bundle.accounts.replace(/,/g,"\",\""),
            entry_list_body = 'method=get_entry_list&input_type=JSON&response_type=JSON&rest_data={"session":"%{SESSION_ID}","module_name":"Accounts","query":"#{email_query}","order_by":"", "offset":0,"select_fields":["#{select_fields}"],"link_name_to_fields_array":[],"max_results":"","deleted":0}';

        $this.freshdeskWidget.request({
            rest_url:     "service/v4/rest.php",
            method:       "post",
            company_id:   $this.bundle.reqCompanyId, 
            body:         entry_list_body.interpolate({email_query: "accounts.name='%{company_name}'", select_fields: selectFields}),//replace is used to escape single quotes in the company name.
            content_type: "",
            on_failure:   $this.processFailure,
            on_success:   function(evt) {
                $this.handleSuccess(evt,"Accounts");
            }
        });
    },

    get_sugar_lead:function () {
        var $this           = this,
            emailList       = "\'" + this.email_list.join("','") + "\'",
            selectFields    = "name\",\"title\",\"account_name\",\"account_id\",\"" + this.bundle.leads.replace(/,/g,"\",\""),
            entry_list_body = 'method=get_entry_list&input_type=JSON&response_type=JSON&rest_data={"session":"%{SESSION_ID}","module_name":"Leads","query":"#{email_query}","order_by":"", "offset":0,"select_fields":["#{select_fields}"],"link_name_to_fields_array":[],"max_results":"","deleted":0}';

        $this.freshdeskWidget.request({
            rest_url:     "service/v4/rest.php",
            method:       "post",
            body:         entry_list_body.interpolate({email_query: "leads.id in (SELECT eabr.bean_id FROM email_addr_bean_rel eabr JOIN email_addresses ea ON (ea.id = eabr.email_address_id) WHERE eabr.deleted=0 AND ea.email_address in ("+ emailList +"))", select_fields: selectFields}),
            content_type: "", //Sugar accepts a mix of key-value pairs and json data as an input param as given in the above session_body variable. so content_type will not be json.
            on_failure:   $this.processFailure,
            on_success:   function(evt) {
                $this.handleSuccess(evt,"Leads");
            }
        });
    },

    handleSuccess:function(evt, module_name) {
        var resJ = this.get_json(evt) || {"result_count":0,"total_count":0,"next_offset":0,"entry_list":[],"relationship_list":[]};
        if (resJ.number != undefined && (resJ.number == 11)){
            this.failureCount += 1;
            if (this.failureCount < 3 ) {
                this.get_sugar_session();
            }
            else {
                this.processFailure();
                jQuery("#sugarcrm_contacts_widget").removeClass('loading-fb');
                return;
            }
        }
        else{
            if(module_name == "Accounts") {
                    this.entryList[module_name] = resJ.entry_list;
                    this.renderSearchResults(resJ);
                    this.get_sugar_lead();
            }
            else if(resJ.entry_list != []){
                this.entryList[module_name] = resJ.entry_list;
                this.renderSearchResults(resJ);
            }
            if(module_name == "Contacts"){
                if(this.bundle.reqCompanyId && this.bundle.accounts){
                    this.get_sugar_account();
                }
                else {
                    this.get_sugar_lead();
                }
            }
            else if(module_name == "Leads"){
                if(this.totalCount > 0){
                  this.get_sugar_contact_fields();
                }
                else{
                    this.renderSearchFinal();
                }
            }
        }
    },

    renderSearchResults:function(resData){
        for(var i=0; i<resData.result_count; i++){
            var name = escapeHtml(resData.entry_list[i].name_value_list.name.value),
                module = resData.entry_list[i].module_name;
            this.sugarResults += '<li><a class="multiple-contacts salesforce-tooltip" title="' + name + '" href="javascript:$this.contactChanged( '+ i + ',\'' + module + '\')">' + name +'</a><span class="contact-search-result-type pull-right">' + module.slice(0,-1) + '</span></li>';
        }
        this.totalCount += resData.result_count;
    },

    get_sugar_contact_fields:function(){
        var $this           = this,
            selectFields    = $this.bundle.contacts.replace(/,/g,"\",\""),
            entry_list_body = 'method=get_module_fields&input_type=JSON&response_type=JSON&rest_data={"session":"%{SESSION_ID}","module_name":"Contacts", "fields":["#{select_fields}"]}';

        $this.freshdeskWidget.request({
            rest_url:     "service/v4/rest.php",
            method:       "post",
            body:         entry_list_body.interpolate({select_fields: selectFields}),
            content_type: "",
            on_failure:   $this.processFailure,
            on_success:   function(evt) {
                $this.handleFieldsSuccess(evt,"Contacts");
            }
        });
    },
    
    get_sugar_account_fields:function() {
        var $this           = this,
            selectFields    = $this.bundle.accounts.replace(/,/g,"\",\""),
            entry_list_body = 'method=get_module_fields&input_type=JSON&response_type=JSON&rest_data={"session":"%{SESSION_ID}","module_name":"Accounts", "fields":["#{select_fields}"]}';

        $this.freshdeskWidget.request({
            rest_url:     "service/v4/rest.php",
            method:       "post",
            body:         entry_list_body.interpolate({select_fields: selectFields}),
            content_type: "",
            on_failure:   $this.processFailure,
            on_success:   function(evt) {
                $this.handleFieldsSuccess(evt,"Accounts");
            }
        });
    },
    
    get_sugar_lead_fields:function(){
        var $this           = this,
            selectFields    = $this.bundle.leads.replace(/,/g,"\",\""),
            entry_list_body = 'method=get_module_fields&input_type=JSON&response_type=JSON&rest_data={"session":"%{SESSION_ID}","module_name":"Leads", "fields":["#{select_fields}"]}';

        $this.freshdeskWidget.request({
            rest_url:     "service/v4/rest.php",
            method:       "post",
            body:         entry_list_body.interpolate({select_fields: selectFields}),
            content_type: "",
            on_failure:   $this.processFailure,
            on_success:   function(evt) {
                $this.handleFieldsSuccess(evt,"Leads");
            }
        });
    },

    handleFieldsSuccess:function(evt, module_name){
        var resJ = this.get_json(evt);
        if (resJ.number != undefined && resJ.number == 11){
            this.processFailure();
            jQuery("#sugarcrm_contacts_widget").removeClass('loading-fb');
            return;
        }
        else{
            if(module_name == "Leads"){
                this.lead_fields = JSON.parse(evt["responseText"])["module_fields"];
                this.get_sugar_version();
            }
            else if(module_name == "Accounts"){
                this.account_fields = JSON.parse(evt["responseText"])["module_fields"];
                if(this.entryList["Leads"]){
                    this.get_sugar_lead_fields();
                }
                else{
                    this.get_sugar_version();
                }
            }
            else if(module_name == "Contacts"){
                this.contact_fields = JSON.parse(evt["responseText"])["module_fields"];
                if(this.bundle.reqCompanyId){
                    this.get_sugar_account_fields();
                }
                else if(this.entryList["Leads"]){
                    this.get_sugar_lead_fields();
                }
                else{
                    this.get_sugar_version();
                }
            }
        }
    },

    contactChanged:function(value,moduleName){
        jQuery("#sugar-search-results-div").hide();
        jQuery("#sugarcrm_contacts_widget").addClass('loading-fb');
        var entry_list = this.entryList[moduleName][value];
        this.renderContact(entry_list);
    },

    renderContact:function(entry_list){
        this.entry_list = entry_list;
        this.displayContact();
    },

    renderContactNa:function(){
        var $this = this;
        $this.freshdeskWidget.options.application_html = function(){ return $this.SUGAR_CONTACT_NA.evaluate({});} 
        $this.freshdeskWidget.display();
        jQuery("#sugarcrm_contacts_widget").removeClass('loading-fb');       
    },

    renderContactWidget:function(){
        var $this = this;
        $this.freshdeskWidget.options.application_html = function(){ return $this.SUGAR_CONTACT.evaluate({});   } 
        jQuery('#sugarcrm_contacts_widget').on('click','#search-back', (function(ev){
            ev.preventDefault();
            $this.renderSearchFinal();
        }));
        $this.freshdeskWidget.display();
    },

    renderSearchResultsWidget:function(){
        var $this = this,
            app_name = $this.freshdeskWidget.options.app_name;
        $this.freshdeskWidget.options.application_html = function(){ return $this.SUGAR_SEARCH_RESULTS.evaluate({app_name : app_name}); } 
        $this.freshdeskWidget.display();
        jQuery("#sugarcrm_contacts_widget").removeClass('loading-fb');
    },

    get_sugar_session:function(callBack){
        var $this = this;
        $this.freshdeskWidget.request({
            source_url:   "/integrations/sugarcrm/renew_session_id",
            content_type: "application/json",
            method:       "get",
            on_success:   function(evt) {
                var resJ = $this.get_json(evt);
                $this.handleSessionSuccess(resJ)
            },
            on_failure: $this.processVersionFailure.bind(this)
        });
    },

    handleSessionSuccess:function(resJ) {
        if (resJ["status"] == false) {
            this.freshdeskWidget.alert_failure("Please verify your Sugar credentials and try again.")
            jQuery("#sugarcrm_contacts_widget").removeClass('loading-fb');
        }
        else {
            this.entryList = {};
            this.get_sugar_contact();
        }
    },

    get_sugar_version:function() {
        $this =this;
        var entry_list_body = 'method=get_server_info&input_type=JSON&response_type=JSON&rest_data={"session":"%{SESSION_ID}","module_name":"Administrator","order_by":"", "offset":0,"select_fields":[],"link_name_to_fields_array":[],"max_results":"","deleted":0}',
            $obj = this;
        $this.freshdeskWidget.request({
            rest_url: "service/v4/rest.php",
            method:"post",
            body:entry_list_body,
            content_type: "", //Sugar accepts a mix of key-value pairs and json data as an input param as given in the above session_body variable. so content_type will not be json.
            on_failure: $this.processVersionFailure,
            on_success: $this.handleVersionSuccess.bind(this)
        });
    },

    handleVersionSuccess:function(evt) {
        var responseText = this.removeRequestKeyword(evt.responseText),
            resJ = jQuery.parseJSON(responseText);
        if (resJ.version == undefined) {
            this.freshdeskWidget.alert_failure("Sugar CRM version couldn't be determined. Please try after sometime or contact support.")
            jQuery("#sugarcrm_contacts_widget").removeClass('loading-fb');
        }
        else {
            var version_arr = resJ.version.split(".");
            this.sugar_version = parseInt(version_arr[0]);
            this.renderSearchFinal();
        }
    },

    renderSearchFinal:function() {
        
        if (this.totalCount > 0) {
            this.renderSearchResultsWidget();
            jQuery('#sugar-contacts-search-results').html(this.sugarResults);
        }
        else {
            this.renderContactNa();
            jQuery('#sugar-contact-na').text("Cannot find " + this.email_list[0] + " in SugarCRM.");
        }
    },

    displayContact:function() {
        this.renderContactWidget();
        var contactJson = this.entry_list.name_value_list,
            title       = (contactJson.title == undefined) ? "" : escapeHtml(contactJson.title.value),
            account     = (contactJson.account_name == undefined) ? "" : escapeHtml(contactJson.account_name.value);
        if(account != ""){
            var account_link = this.get_sugar_link("Accounts", contactJson.account_id.value);
            account = "<a target='_blank' class='salesforce-tooltip' title='" + account + "' href='" + account_link +"'>" + account +"</a>"    
        }
        var desig         = (title != "" && account != "" ) ? (title + "<div>" + account + "</div>") : (title + account),
            custom_fields = "",
            module_name   = this.entry_list.module_name,
            contactLink   = this.get_sugar_link(module_name, this.entry_list.id);

        module_name       = module_name.slice(0,-1);
        jQuery('#sugar-crm-contact-type').text(module_name);
        jQuery('#sugarcrm_contacts_widget .contact-type').text(module_name).show();
        module_name       = module_name.toLowerCase();

        var module_fields = this[module_name+"_fields"],
            custom_labels = this.bundle[module_name+'_labels'].split(","),
            custom_array  = this.bundle[module_name+'s'].split(",");
        if (this.existing_user == true) {
            custom_fields += this.existingUsers(contactJson);
        }
        else {
            for (i=1; i<custom_array.length; i++) {
                if (custom_array[i] != "" && escapeHtml(module_fields[custom_array[i]]) != "undefined") {
                    switch (module_fields[custom_array[i]]["type"]) {
                        case 'iframe' :
                        case 'url'    : 
                            value         = (escapeHtml(contactJson[custom_array[i]].value) != "") ? escapeHtml(contactJson[custom_array[i]].value) : "N/A";
                            custom_fields += this.createCustomField(custom_labels[i],value, "link");
                            break;

                        case 'bool' :
                            var code      = escapeHtml(contactJson[custom_array[i]].value); 
                            code          = code ? (code === "0" ? "" : (code === "true" || code === "1" ? "1" : "2")) : "";
                            value         = (code != "")? escapeHtml(module_fields[custom_array[i]]["options"][code].value) : "N/A";
                            custom_fields += this.createCustomField(custom_labels[i],value, "");
                            break;

                        case 'date' :
                            var code      = escapeHtml(contactJson[custom_array[i]].value); 
                            value         = (code != "" && code != "false")? code : "N/A";
                            custom_fields += this.createCustomField(custom_labels[i],value, "");
                            break;

                        case 'enum' :
                        case 'radioenum' : 
                            var code      = escapeHtml(contactJson[custom_array[i]].value);
                            value         = (code != "")? escapeHtml(module_fields[custom_array[i]]["options"][escapeHtml(contactJson[custom_array[i]].value)].value) : "N/A";
                            custom_fields += this.createCustomField(custom_labels[i],value, "");
                            break;

                        case 'multienum' : 
                            var code = escapeHtml(contactJson[custom_array[i]].value).replace(/\^/g,"").split(",");
                            value    = (code[0] != "")? escapeHtml(module_fields[custom_array[i]]["options"][code[0]].value) : "N/A";
                            for(var t = 1; t<code.length; t++) {
                                value += ", " + (escapeHtml(module_fields[custom_array[i]]["options"][code[t]].value));
                            }
                            custom_fields += this.createCustomField(custom_labels[i],value, "");
                            break;

                        case "image" : 
                            value = (escapeHtml(contactJson[custom_array[i]].value) != "") ? (this.bundle.domain + "/rest/v10/" + this.entry_list["module_name"] + "/" + this.entry_list["id"] + "/file/"+custom_array[i]+"?format=sugar-html-json&platform=base&_hash=" + escapeHtml(contactJson[custom_array[i]].value)) : "N/A";
                            custom_fields += this.createCustomField(custom_labels[i],value, "link");
                            break;

                        case "email" : 
                            if (escapeHtml(contactJson[custom_array[i]].value) != ""){
                                value = contactJson[custom_array[i]].value[0].email_address;
                                for(var j=1; j<contactJson[custom_array[i]].value.length; j++){
                                    value += ", " + contactJson[custom_array[i]].value[j].email_address;
                                }
                            }
                            else {
                                value = "N/A";
                            }
                            custom_fields += this.createCustomField(custom_labels[i],value, "");
                            break;

                        default : 
                            value = (escapeHtml(contactJson[custom_array[i]].value) != "") ? escapeHtml(contactJson[custom_array[i]].value) : "N/A";
                            custom_fields += this.createCustomField(custom_labels[i],value, "");
                    }
                }
            }
        }
        var fullName = "<a target='_blank' class='salesforce-tooltip' title='"+ escapeHtml(contactJson.name.value) +"' href='" + contactLink  +"'>"+ escapeHtml(contactJson.name.value)+"</a>";
        jQuery('#sugar-contact-widget').show();
        jQuery('#sugar-contact-name').html(fullName);
        jQuery('#sugar-contact-desig').html(desig);
        jQuery('#sugar-populate-custom-fields').html(custom_fields);
        jQuery('#sugar-crm-view').attr("href",contactLink);
        jQuery("#sugarcrm_contacts_widget").removeClass('loading-fb');
    },

    createCustomField:function(label, value, style){
        if (style == "link" && value != "N/A") {
            var temp = '<div class="salesforce-widget">' + 
                            '<div class="clearfix">' +
                                '<span>' + label + '</span>' +
                                '<label class="ellipsis tooltip" title="Link">' + 
                                        '<a target=_blank rel="noreferrer" href="' + this.escapeJavascript(value) + '">Link</a>' + 
                                '</label>' +
                            '</div>' +
                        '</div>';
        }else {
          var temp = '<div class="salesforce-widget">' + 
                        '<div class="clearfix">' +
                           '<span>' + label + '</span>' +
                            '<label class="ellipsis tooltip" title="'+ value +'">' + value +
                            '</label>' +
                        '</div>' +
                    '</div>';
            }
        return temp;
    },

    escapeJavascript:function(url){
        url = url.substr(0, 4) == "http" ? url : "http://" + url;
        return url;
    },

    existingUsers: function(contactJson){     
        var department    = (escapeHtml(contactJson.department.value) != "") ? escapeHtml(contactJson.department.value) : "N/A",
            phone         = (escapeHtml(contactJson.phone_work.value) != "") ? escapeHtml(contactJson.phone_work.value) : "N/A",
            mobile        = (escapeHtml(contactJson.phone_mobile.value) != "") ? escapeHtml(contactJson.phone_mobile.value) : "N/A",
            custom_fields = '<div class="field"><label>Department</label> <span class="">' + department+'</span></div>';
        custom_fields    += '<div class="field"><label>Phone</label> <span class="">' + phone +'</span></div>';
        custom_fields    += '<div class="field"><label>Mobile</label> <span class="">' + mobile +'</span></div>';
        if(this.entry_list.module_name == "Contacts"){
            var address   = escapeHtml(this.get_formatted_address(contactJson));
            address       = (address != "") ? address : "N/A" ;
            custom_fields += '<div class="field"><label>Contact</label> <span class="">' + address +'</span></div>';
        }
        return custom_fields;
    },

    get_formatted_address:function(contactJson){ 
        var street1      = (escapeHtml(contactJson.primary_address_street.value == "")) ? "" : (escapeHtml(contactJson.primary_address_street.value)+", "),
            street2      = (escapeHtml(contactJson.primary_address_street_2.value == "")) ? "" : (escapeHtml(contactJson.primary_address_street_2.value)+", "),
            street3      = (escapeHtml(contactJson.primary_address_street_3.value == "")) ? "" : (escapeHtml(contactJson.primary_address_street_3.value)+", "),
            state        = (escapeHtml(contactJson.primary_address_state.value == "")) ? "" : (escapeHtml(contactJson.primary_address_state.value)+", "),
            city         = (escapeHtml(contactJson.primary_address_city.value == "")) ? "" : (escapeHtml(contactJson.primary_address_city.value)+", "),
            country      = (escapeHtml(contactJson.primary_address_country.value == "")) ? "" : escapeHtml(contactJson.primary_address_country.value),
            address      = street1+street2+street3+city+state+country,
            addressLine1 = street1+street2+street3,
            addressLine2 = (addressLine1=="") ? "" : (addressLine1);
        city             = state+city;
        addressLine2     = addressLine2 + ((city=="") ? "" : city);
        var addressLine  = (addressLine2=="") ? "" : (addressLine2);
        addressLine      = addressLine + ((country=="") ? "" : country);
        return addressLine;
    },

    processVersionFailure:function(evt){
        this.freshdeskWidget.alert_failure("Unable to establish connection with SugarCRM and determine the version. Please contact Support at support@freshdesk.com")
    },

    removeRequestKeyword:function(responseText){
        return responseText.replace(/request{/g,"{");   
    },

    get_sugar_link:function(module_name, id){
        var link = "";
        if(this.sugar_version < 7) {
            link = this.bundle.domain + "/" + "index.php?action=ajaxui#ajaxUILoc=index.php%3Fmodule%3D"+module_name+"%26action%3DDetailView%26record%3D"+id; 
        } else {
            link = this.bundle.domain + "/#" + module_name + "/" + id;
        }
        return link;
    },

    get_json:function(resData){
        var responseText = resData.responseText,
            responseText = this.removeRequestKeyword(responseText);
        return jQuery.parseJSON(responseText);
    },

    processFailure:function(evt){
        this.freshdeskWidget.alert_failure("Unable to establish connection with SugarCRM. Please contact Support at support@freshdesk.com")
    }
};