var InfusionsoftWidget = Class.create();
InfusionsoftWidget.prototype= {
    
    initialize:function(bundle){
        jQuery("#infusionsoft_contacts_widget").addClass('loading-fb');
        var $this = this;
        this.bundle = bundle;
        $this.setValues();
        if($this.bundle.domain) {
            $this.freshdeskWidget = new Freshdesk.Widget({
                app_name: "Infusionsoft",
                widget_name: "infusionsoft_contacts_widget",    
                integratable_type: "crm",
                use_server_password: "true",
                auth_type: "OAuth",
                oauth_token: $this.bundle.token,
                domain: $this.bundle.domain,
                init_requests: $this.getContactRequest()
            });
            if(!$this.freshdeskWidget.options.init_requests){
                this.freshdeskWidget.alert_failure('Email or Company Name not available for this requester. Please make sure a valid Email or Company Name is set for this requester.');
            }
        }
    },

    setValues: function(){
        this.contactInfo = this.mapFieldLabels(this.bundle.contactFields,this.bundle.contactLabels);
        this.accountInfo = this.mapFieldLabels(this.bundle.accountFields,this.bundle.accountLabels);
        this.contactCustomDataType = this.mapFieldLabels(this.bundle.contactCustomFields,this.bundle.contactDataTypes);
        this.companyCustomDataType = this.mapFieldLabels(this.bundle.companyCustomFields,this.bundle.companyDataTypes);
        this.userCount = false; 
        this.contacts = [];
        this.accounts = [];
        this.contactIDs = [];
        this.associatedCompanyIDs = [];
        this.associatedCompanyDetails = {};
    },

    mapFieldLabels: function(fields,labels){
        var fieldLabels ={},
            fieldsArr = fields.split(","),
            labelsArr = labels.split(",");      
        for (var i=0;i<fieldsArr.length;i++){
            fieldLabels[fieldsArr[i]] = labelsArr[i];   
        }
        return fieldLabels;
    },

    getContactRequest: function(){
        var requestUrls = [],
            custEmail = this.bundle.reqEmail.split(','),
            custCompany = this.bundle.reqCompany;
        this.searchCount = custEmail.length;
        this.searchResultsCount = 0;
        if( this.bundle.reqEmail ){
            for(var i=0; i < custEmail.length; i++){
                requestUrls.push(this.getContactRequestParams(custEmail[i]));
            }  
        }
        else if( custCompany ){
            requestUrls.push(this.getAccountRequestParams("Company", custCompany));
        }
        if(!requestUrls.length){
            return;
        } 
        return requestUrls;
    },

//making the API call for the contact
    getContactRequestParams: function( custEmail ){
        var $this = this,
            contactBody =  $this.constructRequestForContact(custEmail);
        return({
            rest_url: "crm/xmlrpc/v1?access_token=",
            body: contactBody,
            content_type: "application/xml",
            method: "post",
            on_success: function(res){
                var resData = res.responseXML;
                var parsedValue = $this.parseContact(resData);
                if(!parsedValue) return;
                $this.handleContactSuccess(parsedValue, custEmail); 
            }
        })
    },

//making the API call for the account
    getAccountRequestParams: function(searchField, entityName){
        var $this = this,
            accountBody = $this.constructRequestForAccount(searchField, entityName);
        return({
            rest_url: "crm/xmlrpc/v1?access_token=",
            body: accountBody,
            content_type: "application/xml",
            method: "post",
            on_success: function(res){
                $this.handleCompanySuccess(res, searchField, entityName);
            }
        })
    },
//construct the request body for contacts
    constructRequestForContact: function( entityName ){
        var contactfields = this.bundle.contactFields.split(",");
        var requestBody = "<?xml version='1.0' encoding='UTF-8'?>" +
            "<methodCall>" +
                "<methodName>ContactService.findByEmail</methodName>" +
                "<params>" +
                    "<param><value><string>privateKey</string></value></param>" +
                    "<param>" +
                       "<value><string>" + entityName + "</string></value>" +
                    "</param>" +
                    "<param><value><array><data>";
        for( var i=0;i < contactfields.length; i++ ){
            requestBody += "<value><string>"+ contactfields[i] +"</string></value>";
        }      
        requestBody +=  "   <value><string>CompanyId</string></value>" +
                        "   <value><string>Id</string></value>" +
                        "   <value><string>Company</string></value>" +
                        "   <value><string>LastName</string></value>" +
                        "</data></array></value></param>" +
                        "</params>" +
                        "</methodCall>";
        return requestBody;
    }, 
//construct the request body for accounts
    constructRequestForAccount: function(searchField, entityName ) {
        var accountfields = this.bundle.accountFields.split(",");
        var requestBody = "<?xml version='1.0' encoding='UTF-8'?>" +
            "<methodCall>" + 
                "<methodName>DataService.findByField</methodName>" +
                "<params>" +
                    "<param><value><string>privateKey</string></value></param>" +
                    "<param><value><string>Company</string></value></param>" +
                    "<param><value><int>1000</int></value></param>" +
                    "<param><value><int>0</int></value></param>" +
                    "<param><value><string>"+ searchField +"</string></value></param>" +
                    "<param><value><string>"+ entityName +"</string></value></param>";
                    
        requestBody += "<param><value><array><data>";
        for(var i=0;i< accountfields.length;i++){
            requestBody += "<value><string>"+ accountfields[i] +"</string></value>";
        }
        requestBody +=  "   <value><string>CompanyId</string></value>" +
                        "   <value><string>Id</string></value>" +
                        "   <value><string>Company</string></value>" +
                        "</data></array></value></param>" + 
                        "</params>" +
                        "</methodCall>";
        return requestBody;
    },

    parseContact: function(resData){
        var contacts = [];
        var contactsNode = XmlUtil.extractEntities(resData, "struct");
        if(contactsNode.length){
            for(var i=0;i < contactsNode.length;i++){
                iscontacts = this.parseSingleContact(contactsNode[i]);
                if(!iscontacts) return;
                contacts.push(iscontacts);
            }
        }   
        return contacts;  
    },

//The resonse is the xml document therefore need to parse to get the json format
    parseSingleContact: function(contact) {
        var contactFieldMembers = XmlUtil.extractEntities(contact, "member");
        var iscontacts = {};
        iscontacts["userDataType"] = [];
        for(var j=0; j < contactFieldMembers.length;j++){
            var contactFieldPresent = XmlUtil.getNodeValueStr(contactFieldMembers[j], "name");
            if( contactFieldPresent == "faultCode" ){
                this.handleError(contactFieldMembers[1]);
                return;
            }
            var contactNodeValue = contactFieldMembers[j].childNodes[1];
            if(contactNodeValue.childElementCount >0 ){
                var contactFieldValue = this.getDataTypeValue(contactNodeValue, contactFieldPresent);
                if( this.checkDataType(this.DATA_TYPES.user,contactFieldPresent) || contactFieldPresent == this.DATA_TYPES.ownerId){
                    if(contactFieldValue == 0){
                        contactFieldValue = "N/A";
                    } else {
                        if(!this.userCount){
                            this.userCount = true;
                        }
                        iscontacts["userDataType"].push(contactFieldPresent);  
                    }                               
                }
            }
            else{
                contactFieldValue = XmlUtil.getNodeValueStr(contactFieldMembers[j], "value");
                if( this.checkDataType(this.DATA_TYPES.userListBox, contactFieldPresent)){
                    if(!this.userCount){
                        this.userCount = true;
                    }
                    iscontacts["userDataType"].push(contactFieldPresent);
                }
            }
            iscontacts[contactFieldPresent] = contactFieldValue;
        }
        return iscontacts;
    },

//check if custom field with a particular data type has been selected or not 
    checkDataType: function(dataType, contactFieldPresent) {
        var dataTypeForContact = this.contactCustomDataType[contactFieldPresent],
            dataTypeForCompany = this.companyCustomDataType[contactFieldPresent];
        if (dataTypeForContact == dataType || dataTypeForCompany == dataType){
            return true;
        }
        return false; 
    },

//The response gives the integer values of certain custom fields with a particular data type, therefore need to get the actual value
    getDataTypeValue: function(contactNodeValue, contactFieldPresent){
        var contactFieldValue = contactNodeValue.textContent;

        if( this.checkDataType(this.DATA_TYPES.dayOfWeek, contactFieldPresent )){
            contactFieldValue = this.DAYS[parseInt(contactFieldValue)-1];
        } 
        else if( this.checkDataType(this.DATA_TYPES.month, contactFieldPresent )){
            contactFieldValue = this.MONTHS[parseInt(contactFieldValue)-1];
        }
        else if( this.checkDataType(this.DATA_TYPES.yesNo, contactFieldPresent )){
            contactFieldValue == 1 ? contactFieldValue = "Yes" : contactFieldValue = "No";
        }
        else if( contactNodeValue.getElementsByTagName(this.DATA_TYPES.dateTime).length){
            var date = contactFieldValue;
            date = date.substring(0,4)+"-"+date.substring(4,6)+"-"+date.slice(6);
            contactFieldValue = new Date(date).toUTCString();
        }
        return contactFieldValue;
    },

//This function handles the error that a custom field has been deleted from the infusionsoft.
    handleError: function(faultCode){
        var errorMessage = XmlUtil.getNodeValueStr(faultCode, "value").split(":")[1].trim(' ').split('.');
        var type = errorMessage[0];
        var field = errorMessage[1];
        if(type == 'Contact'){
            this.freshdeskWidget.alert_failure("The field '"+this.contactInfo[field]+ "' has been removed from Infusionsoft "+type+" table");
        }
        else{
            this.freshdeskWidget.alert_failure("The field '"+this.accountInfo[field]+ "' has been removed from Infusionsoft "+type+" table");
        }
    },

 //The API response for the contact contains both the company and contact records. Therefore need to filter the contact records.
    handleContactSuccess: function(parsedValue, custEmail){
        $this = this;
        for(var i=0;i < parsedValue.length; i++){
            var searchContact = parsedValue[i];
            if(searchContact['CompanyId'] != searchContact['Id'] && this.contactIDs.indexOf(searchContact['Id']) == -1){
                searchContact['type'] = 'Contact';
                searchContact['Name'] = '';
                if(searchContact['FirstName']){
                    searchContact['Name'] += searchContact['FirstName'] + " ";
                }
                if(searchContact['LastName']){
                    searchContact['Name'] += searchContact['LastName'];
                }
                searchContact['Name'] = escapeHtml(searchContact['Name']);   
                searchContact['Email'] = custEmail;
                searchContact['url'] = location.protocol+"//"+this.bundle.accountUrl+"/Contact/manageContact.jsp?view=edit&ID="+searchContact['Id'];
                this.contacts.push(searchContact);
                this.contactIDs.push(searchContact['Id']);
                if( searchContact['CompanyId'] != 0 ){
                    if(this.associatedCompanyIDs.indexOf(searchContact['CompanyId']) == -1){
                        this.associatedCompanyIDs.push(searchContact['CompanyId']);
                    }  
                } 
            }                      
        }   
        if ( !this.allResponsesReceived() ){ 
            return;
        }
        var custCompany = this.bundle.reqCompany;
        if( custCompany || this.associatedCompanyIDs.length > 0){
            this.searchCount = this.associatedCompanyIDs.length;
            this.searchResultsCount = 0;
            if( custCompany ){
                this.searchCount++;
                $this.freshdeskWidget.request($this.getAccountRequestParams("Company", custCompany));
            }
            for( var i=0; i < this.associatedCompanyIDs.length; i++){
                $this.freshdeskWidget.request($this.getAccountRequestParams("CompanyId", this.associatedCompanyIDs[i]));
            }
        }
        else{
            $this.getUserInfo();
        }
    },      

    handleCompanySuccess: function(response, searchField, entityName){
        var resData = response.responseXML;
        var parsedValue = this.parseContact(resData);
        if(!parsedValue){
            return;
        }
        for(var i=0 ;i < parsedValue.length;i++){
            var comp = parsedValue[i];
            comp['type'] = 'Account'; 
            comp['Name'] = comp['Company'];
            comp['url'] = location.protocol+"//"+this.bundle.accountUrl+"/Company/manageCompany.jsp?view=edit&ID="+comp['Id'];
            if( searchField == "CompanyId" ){
                this.associatedCompanyDetails[entityName] = comp;
            }
            else if (searchField == "Company"){
                this.accounts.push(comp);
            }
        }
        if ( !this.allResponsesReceived() ){ 
           return;
        }
        this.getUserInfo();
    },

//The User and userListBox data types gives the user id when making the API call, therefore need to get the username with the corresponding user id.
    getUserInfo: function(){
        var $this =this;        
        $this.userIDs = {};
        if($this.userCount){
            $this.freshdeskWidget.request({
                rest_url: "crm/xmlrpc/v1?access_token=",
                source_url: "/integrations/infusionsoft/fetch_user",
                body: $this.USER_REQUEST_BODY,
                content_type: "application/xml",
                method: "post",
                on_success: function(res){
                    var resData = res.responseXML;
                    var parsedValue = $this.parseContact(resData);
                    if(!parsedValue){
                        return;
                    } 
                    for(var i=0; i < parsedValue.length;i++){
                        var userInfo = parsedValue[i].FirstName+ " " +parsedValue[i].LastName;
                        $this.userIDs[parsedValue[i].Id] = userInfo;
                    }
                    $this.handleUserInfo( $this.contacts );
                    $this.handleUserInfo( $this.accounts );
                    $this.handleUserInfo( Object.values($this.associatedCompanyDetails));
                    $this.handleRender();
                }
            });
        }
        else{
            $this.handleRender();
        } 
    }, 

//Replacing the user ids of the custom fields with their names.
    handleUserInfo: function( type ){
        for(var i=0;i < type.length;i++){
            var obj = type[i];
            for(var j=0; j < obj["userDataType"].length;j++){
                var userId= obj[obj["userDataType"][j]].split(',');
                for(var k=0;k < userId.length;k++){
                    if(!this.userIDs[userId[k]]){
                        this.userIDs[userId[k]] = "N/A";
                    }               
                    if(k==0){
                        type[i][obj["userDataType"][j]] = this.userIDs[userId[k]];
                    }
                    else{
                        if(this.userIDs[userId[k]] == "N/A"){
                            continue;
                        }
                        if(type[i][obj["userDataType"][j]] == "N/A"){
                            type[i][obj["userDataType"][j]] = this.userIDs[userId[k]];
                        }
                        else{
                            type[i][obj["userDataType"][j]] += ","+ this.userIDs[userId[k]];
                        }
                    }       
                }
            }
        }
    },
    
    handleRender:function(){
        if ( this.contacts.length > 0 || this.accounts.length > 0) {
            this.renderSearchResults();
        } 
        else{
            this.renderContactNa();
            jQuery('#contact-na').text('Cannot find '+this.bundle.reqName +' in Infusionsoft');
        }
        jQuery("#infusionsoft_contacts_widget").removeClass('loading-fb');       
    },

    renderSearchResults:function(){
        var crmResults="";
        for( i=0; i< this.contacts.length; i++){
            if( i == 0){
                crmResults += '<span class="contact-search-result-type">Contacts</span>';
            }
            if( i == 2 ){
                crmResults += '<span class="hide" id="contact_all_data">';
            }             
            crmResults += '<li><a class="multiple-contacts infusionsoft-contacts salesforce-tooltip" title="'+escapeHtml(this.contacts[i].Name)+' ('+escapeHtml(this.contacts[i].Email)+')" href="#" data-contact="' + i + '">'+escapeHtml(this.contacts[i].Name)+' (' + escapeHtml(this.contacts[i].Email) +')</a></li>';           
        }
        if(this.contacts.length >=3){
            crmResults+='<div id="less_contact_button" class="external_link"><a href="#" onclick="jQuery(this).parent().hide();jQuery(\'#more_contact_button\').show();jQuery(\'#contact_all_data\').addClass(\'hide\');return false;">&nbsp;&nbsp;&nbsp;&nbsp;less</a></div>';
            crmResults+= '</span><div id="more_contact_button" class="external_link"><a href="#" onclick="jQuery(this).parent().hide();jQuery(\'#less_contact_button\').show();jQuery(\'#contact_all_data\').removeClass(\'hide\');return false;" >&nbsp;&nbsp;&nbsp;&nbsp;more</a></div>';
        }
        for(var j=0; j< this.accounts.length; j++){
            if( j == 0){
                crmResults += '<span class="contact-search-result-type">Accounts</span>';
            }
            if( j == 2 ){
                crmResults += '<span class="hide" id="account_all_data">';
            }  
            crmResults += '<li><a class="multiple-accounts infusionsoft-contacts salesforce-tooltip" href="#" data-account="' + j + '">'+escapeHtml(this.accounts[j].Name)+'</a></li>';
        }
        if(this.accounts.length >=3){
            crmResults+='<div id="less_account_button" class="external_link"><a href="#" onclick="jQuery(this).parent().hide();jQuery(\'#more_account_button\').show();jQuery(\'#account_all_data\').addClass(\'hide\');return false;">&nbsp;&nbsp;&nbsp;&nbsp;less</a></div>';
            crmResults+= '</span><div id="more_account_button" class="external_link"><a href="#" onclick="jQuery(this).parent().hide();jQuery(\'#less_account_button\').show();jQuery(\'#account_all_data\').removeClass(\'hide\');return false;" >&nbsp;&nbsp;&nbsp;&nbsp;more</a></div>';
        }
        var resultsNumber = {resultsData: crmResults};
        this.renderSearchResultsWidget(resultsNumber);
        var obj = this;
        jQuery('#infusionsoft_contacts_widget').on('click','.multiple-contacts', (function(ev){
            ev.preventDefault();
            jQuery('.twipsy-arrow').hide();
            jQuery('.twipsy-inner').hide();
            obj.renderContactWidget(obj.contacts[jQuery(this).data('contact')], jQuery(this).data('contact'));
        }));
        jQuery('#infusionsoft_contacts_widget').on('click','.multiple-accounts', (function(ev){
            ev.preventDefault();
            obj.renderContactWidget(obj.accounts[jQuery(this).data('account')]);
        }));
    },

    renderSearchResultsWidget:function(resultsNumber){
        var $this=this;
        resultsNumber.widget_name = "infusionsoft_contacts_widget";
        resultsNumber.app_name=this.freshdeskWidget.options.app_name;
        this.freshdeskWidget.options.application_html = function(){ return _.template($this.CONTACT_SEARCH_RESULTS, resultsNumber);} 
        this.freshdeskWidget.display();
    },
    
    renderContactNa: function(){
        var $this = this;
        var appName = this.freshdeskWidget.options.app_name;
        this.freshdeskWidget.options.application_html = function(){ return $this.CONTACT_NA.evaluate({app_name :appName}); }
        this.freshdeskWidget.display();
    },
    
//showing the selected fields for the contact or the account
    renderContactWidget:function(evalParams, index){
        var $this = this;
        evalParams.app_name = "Infusionsoft";
        evalParams.widget_name = "infusionsoft_contacts_widget";
        evalParams.type = evalParams.type?evalParams.type:"" ; 
        evalParams.url = evalParams.url?evalParams.url:"#";
        var contactFieldsTemplate="";
        var contactFieldsTemplate = this.getTemplate(evalParams);

        this.freshdeskWidget.options.application_html = function(){ return _.template($this.VIEW_CONTACT, evalParams)+""+contactFieldsTemplate;    } 
        this.freshdeskWidget.display();
        jQuery('#infusionsoft_contacts_widget').on('click','#search-back-Contact', (function(ev){
            ev.preventDefault();
            $this.renderSearchResults();
        }));
        jQuery('#infusionsoft_contacts_widget').on('click','.linked-accounts', (function(ev){
            ev.preventDefault();
            jQuery('.twipsy-arrow').hide();
            jQuery('.twipsy-inner').hide();
            $this.renderContactWidget($this.associatedCompanyDetails[jQuery(this).data('account')], index);
        }));
        jQuery('#infusionsoft_contacts_widget').on('click','#search-back-Account', (function(ev){
            ev.preventDefault();
            if( index >= 0 ){
                $this.renderContactWidget($this.contacts[index], index);
            }
            else{
                $this.renderSearchResults();
            }
        }));
    },

    getTemplate:function(evalParams){
        var contactTemplate ="",
            labels = this.contactInfo,
            fields = this.bundle.contactFields.split(",");
        if(evalParams.type == "Account"){
            fields = this.bundle.accountFields.split(",");
            labels = this.accountInfo;
        }
        for(var i=0;i<fields.length;i++){
            var value = evalParams[fields[i]];
            if(i==4){
                contactTemplate+='<span class="hide" id="'+evalParams.type+'_all_data">';
            }
            if(value==null || value == undefined){
                value ="N/A";
            }
            contactTemplate+= '<div class="salesforce-widget">' +
                '<div class="clearfix">' +
                    '<span>'+escapeHtml(labels[fields[i]])+':</span>';
                    if(evalParams.type == "Contact" && evalParams.CompanyId != 0 && labels[fields[i]] == "Company" ){
                        contactTemplate += '<label><a id="contact-'+escapeHtml(fields[i])+'" class="linked-accounts ellipsis tooltip"  href="#" title="'+escapeHtml(value)+'" data-account="' + evalParams.CompanyId + '">'+escapeHtml(value)+'</a></label>' +
                        '</div></div>';
                    }
                    else{         
                        contactTemplate += '<label id="contact-'+escapeHtml(fields[i])+'" class="ellipsis tooltip" title="'+escapeHtml(value)+'">'+escapeHtml(value)+'</label>' +
                        '</div></div>';
                    } 
        }
        if(fields.length>=5){
            contactTemplate+='<div id="less_'+evalParams.type+'_button" class="external_link"><a href="#" onclick="jQuery(this).parent().hide();jQuery(\'#more_'+evalParams.type+'_button\').show();jQuery(\'#'+evalParams.type+'_all_data\').addClass(\'hide\');return false;">less</a></div>';
            contactTemplate+= '</span><div id="more_'+evalParams.type+'_button" class="external_link"><a href="#" onclick="jQuery(this).parent().hide();jQuery(\'#less_'+evalParams.type+'_button\').show();jQuery(\'#'+evalParams.type+'_all_data\').removeClass(\'hide\');return false;" >more</a></div>';
        }
        return contactTemplate;
    },

    allResponsesReceived:function(){
        return (this.searchCount <= ++this.searchResultsCount );
    },

    VIEW_CONTACT:
        '<div class="title salesforce_contacts_widget_bg">' +
            '<div class="row-fluid">' +
                '<div id="contact-name" class="span8">'+
                '<a id="search-back-<%=type%>" href="#"><div class="search-back"> <i class="arrow-left"></i> </div></a>'+
                '<a title="<%=Name%>" target="_blank" href="<%=url%>" class="sales-title salesforce-tooltip"><%=Name%></a></div>' +
                '<div class="span4"><span class="contact-search-result-type pull-right"><%=(type || "")%></span></div>'+
            '</div>' + 
        '</div>',

    CONTACT_SEARCH_RESULTS:
        '<div class="title salesforce_contacts_widget_bg">' +
            '<h5 id="infusionsoft_title"><%=app_name%></h5>'+
            '<div id="search-results"><ul id="infusionsoft-contacts-search-results"><%=resultsData%></ul></div>'+
        '</div>',

    CONTACT_NA: new Template(
        '<div class="title contact-na">' +
            '<h5 id="infusionsoft_title">#{app_name}</h5>'+
            '<div class="name"  id="contact-na"></div>'+
        '</div>'),

    MONTHS:
        ['January','February','March','April','May','June','July','August','September','October','November','December'],

    DAYS:
        ['Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'],

    USER_REQUEST_BODY:
        "<?xml version='1.0' encoding='UTF-8'?>"+
        "<methodCall>"+
            "<methodName>DataService.findByField</methodName>"+
            "<params>"+
                "<param>"+
                    "<value><string>privateKey</string></value>"+
                "</param>"+
                "<param>"+
                    "<value><string>User</string></value>"+
                "</param>"+
                "<param>"+
                    "<value><int>1000</int></value>"+
                "</param>"+
                "<param>"+
                    "<value><int>0</int></value>"+
                "</param>"+
                "<param>"+
                    "<value><string>Id</string></value>"+
                "</param>"+
                "<param>"+
                    "<value><string>%</string></value>"+
                "</param>"+
                "<param>"+
                    "<value><array>"+
                        "<data>"+
                            "<value><string>FirstName</string></value>"+
                            "<value><string>LastName</string></value>"+
                            "<value><string>Id</string></value>"+
                        "</data>"+
                    "</array></value>"+
                "</param>"+
            "</params>"+
        "</methodCall>",

    DATA_TYPES: {
        user: "22",
        userListBox: "25",
        dayOfWeek: "9",
        month: "8",
        yesNo: "6",
        dateTime: "dateTime.iso8601",
        ownerId: "OwnerID"
    },
}
   