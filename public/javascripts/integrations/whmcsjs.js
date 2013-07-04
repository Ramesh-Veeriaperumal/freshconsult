Freshdesk.WhmcsWidget= Class.create(Freshdesk.Widget, {
 
    initialize:function(whmcsBundle,resJson){
        jQuery("#whmcs_widget .content").addClass('sloading');

        whmcsWidget = this;
        whmcsBundle.app_name = "WHMCS";
        whmcsBundle.integratable_type = "crm";
        whmcsBundle.auth_type = "NoAuth";
        whmcsBundle.domain ="default";
        this.content_element = $$("#whmcs_widget .content")[0];
        this.options = whmcsBundle;
        this.contacts = [];
        this.invoices =[];
        this.products = [];
        this.domains = [];
        if(resJson == undefined) this.renderContactNa(resJson);
        this.handleResponse(resJson);

    },
    parse_client: function(resJson){
        var contacts = [];
        var sso_url = resJson.sso_url;
                email = resJson.client['email'];
                company = resJson.client['companyname'];
                fullName = resJson.client['firstname'] +" "+resJson.client['lastname'];
                phone = resJson.client['phonenumber'];
 
                street = (resJson.client['address1']) ? (resJson.client['address1'] + "<br />")  : "";
                state = (resJson.client['state']) ? (resJson.client['state'] + "<br />")  : "";
                city = (resJson.client['city']) ? (resJson.client['city'])  : "";
                country = (resJson.client['country']) ? (city + ", " + resJson.client['country'])  : city;
                address = street + state + country;
                address = (address == "") ? null : address
                company = (company) ? (company) : "";

                //adding the domain name from the domain results.
                domainname = "N/A";
                if(resJson.domain){
                    domainname = resJson.domain['domainname'];
                }
                var cPhone = (phone) ? phone : "N/A";
                var cAddress = (address) ? address : "N/A";
                contacts.push({sso_url: sso_url,name: fullName, email: email, company: company,domain: domain, company_url: null, phone: cPhone, address: cAddress});

        return contacts;
    },
    parse_contact: function(resJson){
        var contacts = [];
        jQuery(resJson).each( function(index,contact_arr) {
           if(contact_arr){
              
                email = contact_arr.contact[0]['email'];
                company = contact_arr.contact[0]['companyname'];
                fullName = contact_arr.contact[0]['firstname'] +" "+contact_arr.contact[0]['lastname'];
                phone = contact_arr.contact[0]['phonenumber'];
                street = (contact_arr.contact[0]['address1']) ? (contact_arr.contact[0]['address1'] + "<br />")  : "";
                state = (contact_arr.contact[0]['state']) ? (contact_arr.contact[0]['state'] + "<br />")  : "";
                city = (contact_arr.contact[0]['city']) ? (contact_arr.contact[0]['city'])  : "";
                country = (contact_arr.contact[0]['country']) ? (city + ", " + contact_arr.contact[0]['country'])  : city;
                address = street + state + country;
                address = (address == "") ? null : address
                company = (company) ? (company) : "";
                var cPhone = (phone) ? phone : "N/A";
                var cAddress = (address) ? address : "N/A";
                contacts.push({name: fullName, email: email, domain:"N/A", company: company, company_url: null, phone: cPhone, address: cAddress});
            }
 
        });
        return contacts;
    },
    parse_invoices: function(resJson){
        var invoices = [];
        jQuery(resJson.invoice).each(function(index,invoice_arr){
            if(invoice_arr.length !=0 ){
                invoicenum = invoice_arr['id']
                companyname = invoice_arr['companyname']
                datepaid = invoice_arr['datepaid']
                duedate = invoice_arr['duedate']
                if(duedate!="0000-00-00"){
                 duedate = Date.parse(duedate).toString("ddd, MMM d")
                }else
                {
                    duedate = ""
                }
                total = invoice_arr['subtotal']
                status = invoice_arr['status']
                paymethod = invoice_arr['paymentmethod']
                currency = invoice_arr['currencycode']
                currencyprefix = invoice_arr['currencyprefix']
                currencysuffix = invoice_arr['currencysuffix']
                if(duedate!=""){// Dues to be paid
                    invoices.push({invoicenum: invoicenum,companyname: companyname,datepaid: datepaid,duedate: duedate,total: total,status: status,paymethod: paymethod,currency: currency,currencyprefix: currencyprefix,currencysuffix: currencysuffix})
                }

            }
        });
        return invoices
    },
     parse_products: function(resJson){
        var products = [];
        var sso_url = resJson.sso_url;
        jQuery(resJson.product).each(function(index,products_arr){

                name = products_arr['name'];
                productnum = products_arr['id'];
                groupname = products_arr['groupname'];
                regdate = products_arr['regdate'];
                duedate = products_arr['nextduedate'];
                firstpaymentamount = products_arr['firstpaymentamount'];
                status = products_arr['status'];
                paymethod = products_arr['paymentmethod'];
                domain= products_arr['domain'];
                orderid = products_arr['orderid'];
                products.push({name: name,product_num: productnum,domain: domain,orderid: orderid,groupname: groupname,regdate: regdate,duedate: duedate,firstpaymentamount: firstpaymentamount,status: status,paymethod: paymethod});
        });
        return products
    },
    parse_domains: function(resJson){
        var domains = [];
        jQuery(resJson.domain).each(function(index,domains_arr){
                domainname = domains_arr['domainname'];
                domainid = domains_arr['id'];
                registrar = domains_arr['registrar'];
                orderid = domains_arr['orderid'];
                regtype = domains_arr['regtype'];
                regdate = domains_arr['regdate'];

                domains.push({domainname: domainname,domainid: domainid,registrar: registrar,orderid: orderid,regtype: regtype,regdate: regdate});
        });
        return domains;
    },
    handleResponse: function(resJson){
        jQuery("#whmcs_widget .content").removeClass('sloading');

        if(resJson.contacts == undefined && resJson.client == undefined){
            this.renderContactNa(resJson);
            return;
        }
            var sso_url = resJson.sso_url;
            this.invoices = this.invoices.concat(this.parse_invoices(resJson.invoices));
            this.products = this.products.concat(this.parse_products(resJson.products));
            this.domains = this.domains.concat(this.parse_domains(resJson.domains));
            product_template ="";
            if(this.products){
                  product_template = this.renderSearchResults('products',sso_url);
            }
            if(resJson.client == undefined){
                this.contacts = this.contacts.concat(this.parse_contact(resJson))
            }
            else
            {
                this.contacts = this.contacts.concat(this.parse_client(resJson))
            }
            invoice_template =""
            if(this.invoices){
                  invoice_template = this.renderSearchResults('invoices',sso_url);
            }
            domain_template= ""
            if(this.domains){
                domain_template = this.renderSearchResults('domains',sso_url); 
            }
          
        if(this.contacts) {
            if ( this.contacts.length > 0) {
                    this.renderContactWidget(this.contacts[0],invoice_template,product_template,domain_template);
                    jQuery('#search-back').hide();
            } else {
                this.renderContactNa(resJson);
            }
        }

    },
    renderContactWidget:function(eval_params,invoice_template,product_template,domain_template){
        var cw = this;
        eval_params.app_name = this.options.app_name;
        eval_params.widget_name = this.options.widget_name;
        eval_params.type = eval_params.type?eval_params.type:"" ; // Required
        eval_params.department = eval_params.department?eval_params.department:null;
        eval_params.url = eval_params.url?eval_params.url:"#";
        eval_params.address_type_span = eval_params.address_type_span || " ";

        this.options.application_html = function(){ return _.template(cw.WHMCS_CONTACT, eval_params)+""+product_template+domain_template+invoice_template;   } 
           
        this.display();
        var obj = this;
    }, 
    renderContactNa:function(resJson){
        var cw=this;
        jQuery("#whmcs_widget .content").addClass("hide");
        jQuery("#whmcs_widget .error").removeClass("hide");
        jQuery("#whmcs_widget .error").html(resJson.message);

    },
    renderSearchResults:function(type,sso_url){
        var crmResults="";
        var data = this.invoices;
        if(type == 'products'){
            data = this.products;
            if(data.length>0){
                
                crmResults ='<div><h6>'+I18n.t('integrations.whmcs.products')+'</h6>';
                if(data.length>=5){
                    crmResults+= '<a href="#" onclick="jQuery(this).hide();jQuery(\'#products_all_data\').removeClass(\'hide\');return false;" class="pull-right">View all</a>'
                }
                for(var i=0; i<data.length; i++){
                    if(i==0){
                        crmResults+='<ul class="list-widget">'
                    }
                    if(i>=5){
                        crmResults +='<span class="hide" id="'+type+'_all_data">';
                    }
                    crmResults += '<li><a target="_blank" href="'+sso_url+'action=productdetails&id='+data[i].product_num+'">'+data[i].name+'</a>'+ 
                        '<span class="info-text">  (#'+data[i].product_num+')</span>'+
                        '<div class="info-text">'+data[i].domain+'</div></li>';
                        
                }
                if(data.length>=5) {
                            crmResults+='</span>';
                        }
                crmResults+='</ul></div>';
            }
        }
        else if (type == 'domains'){
            data = this.domains;

            if(data.length>0){

                crmResults ='<div><h6>'+I18n.t('integrations.whmcs.domains')+'</h6>';
                 if(data.length>=5){
                    crmResults+= '<a href="#" onclick="jQuery(this).hide();jQuery(\"#domains_all_data\").removeClass(\"hide\");return false;" class="pull-right">View all</a>';
                }
                 for(var i=0; i<data.length; i++){
                      if(i==0){
                        crmResults+='<ul class="list-widget">'
                    }
                    if(i>=5){
                        crmResults +='<span class="hide" id="'+type+'_all_data">';
                    }
                    crmResults += '<li><a target="_blank" href="'+sso_url+'action=domains&id='+data[i].domainid+'">'+data[i].domainname+'</a>'+
                            '<span class="info-text">  (#'+data[i].domainid+')</span></li>';                    
                }
                if(data.length>=5) {
                            crmResults+='</span>';
                        }
                crmResults+='</ul></div>';
            }
        }
        else{
                if(data.length>0){
                    crmResults ='<div><h6>'+I18n.t('integrations.whmcs.invoices')+'</h6>';
                    if(data.length>=5){
                        crmResults+= '<a href="#" onclick="jQuery(this).hide();jQuery(\"#domains_all_data\").removeClass(\"hide\");return false;" class="pull-right">View all</a>';
                    }
                    for(var i=0; i<data.length; i++){
                        if(i==0){
                            crmResults+='<ul class="list-widget">'
                        }
                        if(i>=5){
                            crmResults +='<span class="hide" id="'+type+'_all_data">';
                        }
                        crmResults+='<li>'+data[i].currencyprefix+''+data[i].total +' on '+
                                    '<span class="info-text">  '+data[i].duedate+'</span>'+ 
                                '<span class="info-text">  (#'+data[i].invoicenum+')</span></li>';
                    }
                    if(data.length>=5) {
                            crmResults+='</span>';
                    }
                    crmResults+='</ul></div>';
                }

            }
        return crmResults;

    },
    renderResults: function(result){
            data = result.products.product;
            var crmResults="";
            if(data.length>0){
                
                crmResults ='<div><h6>'+I18n.t('integrations.whmcs.products')+'</h6>';
                if(data.length>=5){
                    crmResults+= '<a href="#" onclick="jQuery(this).hide();jQuery(\'#products_all_data\').removeClass(\'hide\');return false;" class="pull-right">View all</a>'
                }
                for(var i=0; i<data.length; i++){
                    if(i==0){
                        crmResults+='<ul class="list-widget">'
                    }
                    if(i>=5){
                        crmResults +='<span class="hide" id="'+type+'_all_data">';
                    }
                    crmResults += '<li><a target="_blank" href="'+sso_url+'action=productdetails&id='+data[i].product_num+'">'+data[i].name+'</a>'+ 
                        '<span class="info-text">  (#'+data[i].id+')</span>'+
                        '<div class="info-text">'+data[i].domain+'</div></li>';
                        
                }
                if(data.length>=5) {
                            crmResults+='</span>';
                        }
                crmResults+='</ul></div>';
            }
        return crmResults;
    },
    WHMCS_CONTACT:'<div id="whmcs-widget">'+
    '<div>'+
        '<h6>'+I18n.t('integrations.whmcs.contacts')+'<a href="<%=sso_url%>" target="_blank"><%=name%></a> </h6><div></div>',
    CONTACT_NA:
    '<div id="whmcs-widget">'+
            '<div class="name"  id="contact-na">Cannot find requester in <%=app_name%></div>'+
        '</div>'

});