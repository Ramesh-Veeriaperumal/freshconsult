var QuickBooksWidget = Class.create();

QuickBooksWidget.prototype = {
    QUICKBOOKS_TIMEENTRY_FORM:new Template(
        '<form id="quickbooks-timeentry-form">' +
            '<div class="field first">' +
                '<label>Employee</label>' +
                '<select name="employee-id" id="quickbooks-timeentry-employee" class="full hide" onchange="quickbooksWidget.changeEmployee(this.value);"></select>' +
                '<div class="loading-fb" id="quickbooks-employee-spinner"></div>' +
            '</div>' +
            '<div class="field">' +
                '<label>Customer</label>' +
                '<select name="client-id" id="quickbooks-timeentry-client" class="full hide"></select>' +
                '<div class="loading-fb" id="quickbooks-client-spinner"></div>' +
            '</div>' +
            '<div class="field">' +
                '<label id="quickbooks-timeentry-notes-label">Notes</label>' +
                '<textarea disabled name="request[notes]" id="quickbooks-timeentry-notes" wrap="virtual">' + jQuery('#quickbooks-note').html().escapeHTML() + '</textarea>' +
            '</div>' +
            '<div class="field">' +
                '<label id="quickbooks-timeentry-hours-label">Hours</label>' +
                '<input type="text" disabled name="request[hours]" id="quickbooks-timeentry-hours">' +
            '</div>' +
            '<input type="submit" disabled id="quickbooks-timeentry-submit" value="Submit" onclick="quickbooksWidget.logTimeEntry($(\'quickbooks-timeentry-form\'));return false;">' +
        '</form>'
    ),
    QUICKBOOKS_EMPLOYEE_FORM:new Template(
        '<form id="quickbooks-employee-form">' +
            '<div class="field">' +
                '<label>First name</label>' +
                '<input type="text" id="quickbooks-employee-firstname" maxlength="25" value="#{firstname}">' +
            '</div>' +
            '<div class="field">' +
                '<label>Last name</label>' +
                '<input type="text" id="quickbooks-employee-lastname" maxlength="25" value="#{lastname}">' +
            '</div>' +
            '<div class="field">' +
                '<label>Email</label>' +
                '<input type="text" id="quickbooks-employee-email" value="#{email}" readonly="readonly">' +
            '<div>' +
            '<input type="button" value="Add employee" onclick="quickbooksWidget.addEmployee();">' +
            ' <input type="button" value="Cancel" onclick="quickbooksWidget.cancelAddEmployee();">' +
        '</form>'
    ),
    QUICKBOOKS_CONTACTS:new Template(
        '<div class="title #{widget_name}_bg">' +
            '<div class="name">' +
                '<div id="contact-name" class="contact-name"><a title="#{display_name}" target="_blank" href="#{url}">#{display_name}</a>' +
                '</div>' +
            '</div>' +
        '</div>' +
        '<div class="field">' +
            '<div id="crm-billto">' +
                '<label>Bill To</label>' +
                '<span id="contact-billto">#{billto}</span>' +
            '</div>' +
        '</div>' +
        '<div class="field">' +
            '<div id="crm-email">' +
                '<label>Email</label>' +
                '<span id="contact-email">#{email}</span>' +
            '</div>' +
        '</div>' +
        '<div class="field">' +
            '<div id="crm-contact">' +
                '<label>Billing Address</label>' +
                '<span id="contact-address">#{address}</span>' +
            '</div>' +
        '</div>' +
        '<div class="field">' +
            '<div  id="crm-phone">' +
                '<label>Phone</label>' +
                '<span id="contact-phone">#{phone}</span>' +
            '</div>' +
        '</div>' +
        '<div class="field">' +
            '<div id="crm-mobile">' +
                '<label>Mobile</label>' +
                '<span id="contact-mobile">#{mobile}</span>' +
            '</div>' +
        '</div>' +
        '<div class="field bottom_div">' +
        '</div>' +
        '<div class="external_link"><a id="search-back" href="#"> &laquo; Back </a></div>'
    ),
    CONTACT_SEARCH_RESULTS:new Template(
        '<div class="title #{widget_name}_bg">' +
            '<div id="number-returned" class="name"> #{resLength} results returned for #{requester} </div>' +
            '<div id="search-results">#{resultsData}</div>' +
        '</div>'
    ),
    CONTACT_NA:new Template(
        '<div class="title contact-na #{widget_name}_bg">' +
            '<div class="name" id="contact-na">Cannot find #{reqName} in #{app_name}</div>'+
        '</div>'
    ),

    initialize:function(quickbooksBundle) {
        quickbooksWidget = this;
        quickbooksBundle.quickbooksNote = jQuery('#quickbooks-note').html();
        this.executed_date = new Date();
        this.clientData = "";
        this.emplData = "";
        this.timeEntryJson = "";
        this.SyncToken = 0;
        this.contacts = [];

        var init_reqs = [];

        employee_all = {
            "query" : "select id, displayname, PrimaryEmailAddr from employee"
        }
        contact_by_email = {
            "query" : "select * from customer where PrimaryEmailAddr like '%" + quickbooksBundle.reqEmail + "%'"
        };
        contact_by_display_name = {
            "query" : "select * from customer where displayname = '" + quickbooksBundle.reqCompany + "'"
        };
        customer_all = {
            "query" : "select * from customer"
        };

        if (quickbooksBundle.token_renewal_date) {
            var token_renewal_date = new Date(quickbooksBundle.token_renewal_date);
            if (new Date() > token_renewal_date) {
                token_renewal_url = '/integrations/quickbooks/refresh_access_token';
                new Ajax.Request(token_renewal_url, {
                    asynchronous: true,
                    method: "get",
                    onSuccess: function(){},
                    onFailure: function(){}
                })
            }
        }

        if (quickbooksBundle.widget_type == '_contacts') {
            jQuery('#quickbooks_contacts_widget').append('<div class="error"></div>');
            jQuery("#quickbooks").prepend('<h3 class="title">QuickBooks</h3>');

            var contact_query = contact_by_display_name;
            if (quickbooksBundle.reqCompany == '') {
                contact_query = contact_by_email;
            }

            init_reqs.push({
                rest_url : "v3/company/" + quickbooksBundle.companyId + "/query",
                encode_params : JSON.stringify(contact_query),
                method : "get",
                on_success : function(evt) {
                    if (evt.responseJSON.IntuitResponse.QueryResponse) {
                        if (evt.responseJSON.IntuitResponse.QueryResponse.Customer instanceof Array) {
                            this.contacts = evt.responseJSON.IntuitResponse.QueryResponse.Customer;
                        }
                        else {
                            this.contacts.push(evt.responseJSON.IntuitResponse.QueryResponse.Customer);
                        }

                        if (quickbooksBundle.reqCompany == '') {
                            this.contacts = quickbooksWidget.filter_records_by_email(this.contacts, quickbooksBundle.reqEmail);
                        }
                    }
                    else {
                        this.contacts = [];
                    }

                    if (quickbooksBundle.reqCompany != '' && this.contacts.length == 0) {
                        quickbooksWidget.fetch_contacts_by_email();
                    }
                    else {
                        quickbooksWidget.parse_contact();
                    }
                }.bind(this),
                on_failure : function(evt) {}
            });
        }
        else {
            if (quickbooksBundle.remote_integratable_id) {
                init_reqs.push({
                    rest_url : "v3/company/" + quickbooksBundle.companyId + "/timeactivity/" + quickbooksBundle.remote_integratable_id,
                    method : "get",
                    content_type : "application/json",
                    on_failure : function(evt) {},
                    on_success : quickbooksWidget.loadTimeEntry.bind(this)
                });
            }

            employee_req_options = {
                rest_url : "v3/company/" + quickbooksBundle.companyId + "/query",
                method : "get",
                encode_params : JSON.stringify(employee_all),
                content_type: "application/json",
                on_success: function(evt) {
                    var query_response = evt.responseJSON.IntuitResponse.QueryResponse;
                    var employees = [];

                    if (query_response && query_response.Employee) {
                        if (query_response.Employee instanceof Array) {
                            employees = query_response.Employee;
                        }
                        else {
                            employees.push(query_response.Employee);
                        }
                    }
                    var default_value = quickbooksWidget.find_default_employee(employees);
                    quickbooksWidget.loadEmployee(employees, default_value);
                }.bind(this),
                on_failure: function() {}
            };
            init_reqs.push(employee_req_options);

            client_req_options = {
                rest_url : "v3/company/" + quickbooksBundle.companyId + "/query",
                method : "get",
                encode_params : JSON.stringify(customer_all),
                content_type: "application/json",
                on_success: function(evt) {
                    var query_response = evt.responseJSON.IntuitResponse.QueryResponse;
                    var clients = [];
                    if (query_response && query_response.Customer) {
                        if (query_response.Customer instanceof Array) {
                            clients = query_response.Customer;
                        }
                        else {
                            clients.push(query_response.Customer);
                        }
                    }
                    var default_value = quickbooksWidget.find_default_client(clients);
                    quickbooksWidget.loadClient(clients, default_value);
                }.bind(this),
                on_failure: function() {}
            };
            init_reqs.push(client_req_options);
        }

        var quickbooksOptions = {};
        quickbooksOptions.app_name = "QuickBooks";
        quickbooksOptions.integratable_type = "timesheet";
        quickbooksOptions.widget_name = quickbooksBundle.widget_type == '_contacts' ? "quickbooks_contacts_widget" : "quickbooks_widget";
        quickbooksOptions.auth_type = "OAuth1";
        quickbooksOptions.ssl_enabled = true;
        quickbooksOptions.application_id = quickbooksBundle.application_id;
        quickbooksOptions.domain = quickbooksBundle.domain;
        quickbooksOptions.init_requests = init_reqs;

        if (quickbooksBundle.widget_type != '_contacts')
            quickbooksOptions.application_html = function(){ return quickbooksWidget.QUICKBOOKS_TIMEENTRY_FORM.evaluate({}); };

        this.freshdeskWidget = new Freshdesk.Widget(quickbooksOptions);

        if (quickbooksBundle.widget_type != '_contacts')
            this.convertToInlineWidget();
    },

    fetch_contacts_by_email: function() {
        this.freshdeskWidget.request({
            rest_url : "v3/company/" + quickbooksBundle.companyId + "/query",
            encode_params : JSON.stringify(contact_by_email),
            method : "get",
            on_success : function(evt) {
                if (evt.responseJSON.IntuitResponse.QueryResponse) {
                    if (evt.responseJSON.IntuitResponse.QueryResponse.Customer instanceof Array) {
                        this.contacts = evt.responseJSON.IntuitResponse.QueryResponse.Customer;
                    }
                    else {
                        this.contacts.push(evt.responseJSON.IntuitResponse.QueryResponse.Customer);
                    }
                    this.contacts = quickbooksWidget.filter_records_by_email(this.contacts, quickbooksBundle.reqEmail);
                }
                else {
                    this.contacts = [];
                }
                quickbooksWidget.parse_contact();
            }.bind(this),
            on_failure : function(evt) {}
        });
    },

    parse_contact: function() {
        var customers = this.contacts;

        if (customers && customers.length > 1) {
            quickbooksWidget.renderSearchResults();
        }
        else if (customers && customers.length > 0) {
            quickbooksWidget.renderContactWidget(customers[0]);
            jQuery('#search-back').hide();
        }
        else {
            var contact_html = quickbooksWidget.CONTACT_NA.evaluate({
                reqName : quickbooksBundle.reqName,
                widget_name : "quickbooks_contacts_widget",
                app_name : "QuickBooks"
            });

            jQuery("#quickbooks_contacts_widget .content").html(contact_html);
            jQuery("#quickbooks_loading").remove();
        }
    },

    renderContactWidget: function(params) {
        var full_name = '';
        full_name = (params.Title ? params.Title.escapeHTML() + ' ' : '')
            + (params.GivenName ? params.GivenName.escapeHTML() + ' ' : '')
            + (params.MiddleName ? params.MiddleName.escapeHTML() + ' ' : '')
            + (params.FamilyName ? params.FamilyName.escapeHTML() + ' ' : '')
            + (params.Suffix ? params.Suffix.escapeHTML() : '');
        var contact_html = quickbooksWidget.QUICKBOOKS_CONTACTS.evaluate({
            app_name : "QuickBooks",
            widget_name : "quickbooks_contacts_widget",
            display_name : params.DisplayName.escapeHTML() || 'N/A',
            email : params.PrimaryEmailAddr ? params.PrimaryEmailAddr.Address.replace(/,/g, ', ').escapeHTML() : 'N/A',
            phone : params.PrimaryPhone ? params.PrimaryPhone.FreeFormNumber.escapeHTML() : 'N/A',
            mobile : params.Mobile ? params.Mobile.FreeFormNumber.escapeHTML() : 'N/A',
            address : params.BillAddr ? quickbooksWidget.format_address(params.BillAddr).escapeHTML() : 'N/A',
            billto : full_name == '' ? 'N/A' : full_name,
            url : "https://qbo.intuit.com/app/customerdetail?nameId=" + params.Id
        });

        jQuery('#quickbooks_contacts_widget').on('click', '#search-back', (function(ev) {
            ev.preventDefault();
            quickbooksWidget.renderSearchResults();
        }));

        jQuery("#quickbooks_contacts_widget .content").html(contact_html);
        jQuery("#quickbooks_loading").remove();
    },

    renderSearchResults: function() {
        var contact_list = "";
        var customers = this.contacts;

        for (i = 0; i < customers.length; i++) {
            contact_list += '<a class="multiple-contacts" href="#" data-contact="' + i + '">' + customers[i].DisplayName + '</a><br>';
        }
        contact_html = quickbooksWidget.CONTACT_SEARCH_RESULTS.evaluate({resLength : customers.length, requester : quickbooksBundle.reqEmail, resultsData : contact_list});

        var obj = this;
        jQuery('#quickbooks_contacts_widget').on('click', '.multiple-contacts', (function(ev) {
            ev.preventDefault();
            quickbooksWidget.renderContactWidget(obj.contacts[jQuery(this).data('contact')]);
        }));

        jQuery("#quickbooks_contacts_widget .content").html(contact_html);
        jQuery("#quickbooks_loading").remove();
    },

    loadTimeEntry: function(resData) {
        if (resData) {
            this.timeEntryJson = resData.responseJSON;
            this.SyncToken = resData.responseJSON.IntuitResponse.TimeActivity.SyncToken;
            this.resetTimeEntryForm();
        }
    },

    resetIntegratedResourceIds: function(integrated_resource_id, remote_integratable_id, local_integratable_id, is_delete_request) {
        quickbooksBundle.integrated_resource_id = integrated_resource_id;
        quickbooksBundle.remote_integratable_id = remote_integratable_id;
        this.freshdeskWidget.local_integratable_id = local_integratable_id;
        this.freshdeskWidget.remote_integratable_id = remote_integratable_id;
        if (!is_delete_request){
            if (quickbooksBundle.remote_integratable_id)
                this.retrieveTimeEntry();
            else
                this.resetTimeEntryForm();
        }
    },

    retrieveTimeEntry: function(resultCallback) {
        if (quickbooksBundle.remote_integratable_id) {
            this.freshdeskWidget.request({
                rest_url : "v3/company/" + quickbooksBundle.companyId + "/timeactivity/" + quickbooksBundle.remote_integratable_id,
                method : "get",
                content_type : "application/json",
                on_failure : function(evt){},
                on_success : quickbooksWidget.loadTimeEntry.bind(this)
            });
        }
    },

    resetTimeEntryForm: function(){
        if(this.timeEntryJson) {
            // Editing the existing entry. Select already associated entry in the drop-downs that are already loaded.
            var employee_id = this.timeEntryJson.IntuitResponse.TimeActivity.EmployeeRef;
            UIUtil.chooseDropdownEntry("quickbooks-timeentry-employee", employee_id);

            var client_id = this.timeEntryJson.IntuitResponse.TimeActivity.CustomerRef;
            UIUtil.chooseDropdownEntry("quickbooks-timeentry-client", client_id);
            this.timeEntryJson = ""; // Required drop downs already populated using this xml. reset this to empty, otherwise all other methods things still it needs to use this xml to load them.
        }

        if ($("quickbooks-timeentry-hours")) {
            $("quickbooks-timeentry-hours").value = "";
            $("quickbooks-timeentry-notes").value = quickbooksBundle.quickbooksNote.escapeHTML();
            $("quickbooks-timeentry-notes").focus();
        }
    },

    loadEmployee: function(employees, default_value) {
        var employeeData = [];

        if (employees.length > 0) {
            for (i = 0; i < employees.length; i++) {
                var employee = employees[i];
                employeeData.push({"ID" : employee.Id.escapeHTML(), "Name" : employee.DisplayName.escapeHTML()});
            }
        }

        this.emplData = {"Empl" : employeeData};
        UIUtil.constructDropDown(this.emplData, 'hash', 'quickbooks-timeentry-employee', 'Empl', 'ID', ['Name'], null, '', false);
        if (employees.length == 0 || default_value == '-') {
            // UIUtil.addDropdownEntry('quickbooks-timeentry-employee', '_addnew_', 'Add new employee', true);
            UIUtil.addDropdownEntry('quickbooks-timeentry-employee', '-', 'No matching employee found', true);
        }
        UIUtil.chooseDropdownEntry('quickbooks-timeentry-employee', default_value);
        UIUtil.hideLoading('quickbooks','employee','-timeentry');

        $("quickbooks-timeentry-employee").enable();      
        $("quickbooks-timeentry-hours").enable();
        $("quickbooks-timeentry-notes").enable();
        $("quickbooks-timeentry-submit").enable();
    },

    loadClient: function(clients, default_value) {
        var clientData = [];

        if (clients.length > 0) {
            for (i = 0; i < clients.length; i++) {
                var client = clients[i];
                clientData.push({"ID" : client.Id.escapeHTML(), "Name" : client.DisplayName.escapeHTML()});
            }
        }

        this.clientData = {"Client" : clientData}
        UIUtil.constructDropDown(this.clientData, 'hash', 'quickbooks-timeentry-client', 'Client', 'ID', ['Name'], null, '', false);
        if (clients.length == 0 || default_value == '-') {
            UIUtil.addDropdownEntry('quickbooks-timeentry-client', '-', 'No matching customer found', true);
        }
        UIUtil.chooseDropdownEntry('quickbooks-timeentry-client', default_value);
        UIUtil.hideLoading('quickbooks', 'client', '-timeentry');

        $("quickbooks-timeentry-client").enable();      
        $("quickbooks-timeentry-hours").enable();
        $("quickbooks-timeentry-notes").enable();
        $("quickbooks-timeentry-submit").enable();
    },

    changeEmployee: function(changed_value) {
        if (changed_value == '_addnew_') {
            quickbooksWidget.freshdeskWidget.options.application_html = function() { return quickbooksWidget.QUICKBOOKS_EMPLOYEE_FORM.evaluate({firstname : quickbooksBundle.agentName, lastname : '.', email : quickbooksBundle.agentEmail}); };
            quickbooksWidget.freshdeskWidget.display();
        }
    },

    addEmployee: function() {
        if (!quickbooksWidget.validateEmployeeForm()) {
            return false;
        }

        var body = new Object();
        body.GivenName = $("quickbooks-employee-firstname").value;
        body.FamilyName = $("quickbooks-employee-lastname").value;
        body.PrimaryEmailAddr = {
            "Address" : $("quickbooks-employee-email").value
        };
        body.PrimaryAddr = {
            "Line1" : "Freshdesk address line1",
            "City" : "Freshdesk city",
            "CountrySubDivisionCode" : "CA",
            "PostalCode" : "93242"
        };

        body = JSON.stringify(body);

        quickbooksWidget.freshdeskWidget.options.application_html = function() { return quickbooksWidget.QUICKBOOKS_TIMEENTRY_FORM.evaluate({}); };
        quickbooksWidget.freshdeskWidget.display();

        quickbooksWidget.convertToInlineWidget();

        this.freshdeskWidget.request({
            rest_url : "v3/company/" + quickbooksBundle.companyId + "/employee",
            method : "post",
            body : body,
            on_success : quickbooksWidget.returntoTimeentryForm.bind(this),
            on_failure : function() {}
        });
    },

    validateEmployeeForm: function() {
        if ($("quickbooks-employee-firstname").value == '') {
            alert("First name is required.");
            $("quickbooks-employee-firstname").focus();
            return false;
        }
        if ($("quickbooks-employee-lastname").value == '') {
            alert("Last name is required.");
            $("quickbooks-employee-lastname").focus();
            return false;
        }
        if ($("quickbooks-employee-email").value == '') {
            alert("Email is required.");
            $("quickbooks-employee-email").focus();
            return false;
        }
        return true;
    },

    returntoTimeentryForm: function(resJson) {
        this.freshdeskWidget.request(employee_req_options);
        this.freshdeskWidget.request(client_req_options);
    },

    cancelAddEmployee: function() {
        quickbooksWidget.freshdeskWidget.options.application_html = function() { return quickbooksWidget.QUICKBOOKS_TIMEENTRY_FORM.evaluate({}); };
        quickbooksWidget.freshdeskWidget.display();

        quickbooksWidget.convertToInlineWidget();

        quickbooksWidget.returntoTimeentryForm();
    },

    logTimeEntry: function(integratable_id) {
        if(integratable_id) this.freshdeskWidget.local_integratable_id = integratable_id;
        if (quickbooksBundle.remote_integratable_id) {
            this.updateTimeEntry();
        } else {
            this.createTimeEntry();
        }
    },

    updateTimeEntry: function() {
        var employee_id = $("quickbooks-timeentry-employee").value;
        var client_id = $("quickbooks-timeentry-client").value;
        var minutes = Math.round(($("quickbooks-timeentry-hours").value || 0) * 60);
        var hours = Math.floor(minutes / 60);
        minutes = minutes % 60;

        var body = new Object();
        body = {
            "TxnDate" : quickbooksWidget.format_date_timeentry(this.executed_date),
            "NameOf" : "Employee",
            "EmployeeRef" : {
                "value" : employee_id,
            },
            "CustomerRef" : {
                "value" : client_id,
            },
            "BillableStatus" : "Billable",
            "HourlyRate" : "0",
            "Hours" : hours,
            "Minutes" : minutes,
            "Description" : "Freshdesk Ticket # " + quickbooksBundle.ticketId + "\n" + $("quickbooks-timeentry-notes").value,
            "Id" : quickbooksBundle.remote_integratable_id,
            "SyncToken" : this.SyncToken
        };

        body = JSON.stringify(body);

        this.freshdeskWidget.request({
            body: body,
            rest_url: "v3/company/" + quickbooksBundle.companyId + "/timeactivity",
            content_type: "application/json",
            method: "post",
            on_success: function(evt){
                this.handleTimeEntrySuccess(evt);
                this.resetIntegratedResourceIds();
                if (resultCallback) {
                    this.result_callback = resultCallback;
                    resultCallback(evt);
                }
            }.bind(this),
            on_failure: function(evt) {}
        });
    },

    createTimeEntry: function(resultCallback) {
        var employee_id = $("quickbooks-timeentry-employee").value;
        var client_id = $("quickbooks-timeentry-client").value;
        var minutes = Math.round(($("quickbooks-timeentry-hours").value || 0) * 60);
        var hours = Math.floor(minutes / 60);
        minutes = minutes % 60;

        var body = new Object();
        body = {
            "TxnDate" : quickbooksWidget.format_date_timeentry(this.executed_date),
            "NameOf" : "Employee",
            "EmployeeRef" : {
                "value" : employee_id,
            },
            "CustomerRef" : {
                "value" : client_id,
            },
            "BillableStatus" : "Billable",
            "HourlyRate" : "0",
            "Hours": hours,
            "Minutes": minutes,
            "Description": "Freshdesk Ticket # " + quickbooksBundle.ticketId + "\n" + $("quickbooks-timeentry-notes").value
        };

        body = JSON.stringify(body);

        this.freshdeskWidget.request({
            body: body,
            rest_url: "v3/company/" + quickbooksBundle.companyId + "/timeactivity",
            content_type: "application/json",
            method: "post",
            on_success: function(evt){
                this.handleTimeEntrySuccess(evt);
                quickbooksWidget.add_quickbooks_resource_in_db();
                if (resultCallback) {
                    this.result_callback = resultCallback;
                    resultCallback(evt);
                }
            }.bind(this),
            on_failure: function(evt) {
                alert("Time activity was not pushed to QuickBooks because of invalid employee/customer/time entry.");
            }
        });
    },

    deleteTimeEntry: function(resultCallback) {
        if (quickbooksBundle.remote_integratable_id) {
            deleteTimeEntryUsingIds(quickbooksBundle.remote_integratable_id, quickbooksBundle.integrated_resource_id, resultCallback);
        } else {
            alert('QuickBooks widget is not loaded properly. Please delete the entry manually.');
        }
    },

    deleteTimeEntryUsingIds: function (integrated_resource_id, remote_integratable_id, resultCallback) {
        if (remote_integratable_id) {
            var body = new Object();
            body = {
                "Id" : remote_integratable_id,
                "SyncToken" : this.SyncToken
            };

            body = JSON.stringify(body);

            this.freshdeskWidget.request({
                body: body,
                rest_url: "v3/company/" + quickbooksBundle.companyId + "/timeactivity?operation=delete",
                content_type: "application/json",
                method: "post",
                operation: "delete",
                on_success: function(evt) {
                    quickbooksWidget.handleTimeEntrySuccess(evt);
                    this.delete_quickbooks_resource_in_db(integrated_resource_id, resultCallback);
                    if(resultCallback) resultCallback(evt);
                }.bind(this),
                on_failure: function(evt) {}
            });
        }
    },

    handleTimeEntrySuccess: function(resData) {
        var resJSON = resData.responseJSON;
        if (resJSON.TimeActivity) {
            this.freshdeskWidget.remote_integratable_id = resJSON.TimeActivity.Id;
            this.resetTimeEntryForm();
        }
    },

    updateNotesAndTimeSpent:function(notes, timeSpent, billable, executed_date) {
        $("quickbooks-timeentry-hours").value = timeSpent;
        $("quickbooks-timeentry-notes").value = (notes+"\n"+quickbooksBundle.quickbooksNote).escapeHTML();
        this.executed_date = new Date(executed_date);
    },

    convertToInlineWidget: function() {
        $("quickbooks-timeentry-hours-label").hide();
        $("quickbooks-timeentry-notes-label").hide();
        $("quickbooks-timeentry-hours").hide();
        $("quickbooks-timeentry-notes").hide();
        $("quickbooks-timeentry-submit").hide();
    },

    // This is method needs to be called by the external time entry code to map the remote and local integrated resorce ids.
    set_timesheet_entry_id: function(integratable_id) {
        if (!quickbooksBundle.remote_integratable_id) {
            this.freshdeskWidget.local_integratable_id = integratable_id;
            this.add_quickbooks_resource_in_db();
        }
    },

    add_quickbooks_resource_in_db:function() {
        this.freshdeskWidget.create_integrated_resource(function(evt){
            resJ = evt.responseJSON;
            if (resJ['status'] != 'error') {
                quickbooksBundle.integrated_resource_id = resJ['integrations_integrated_resource']['id'];
                quickbooksBundle.remote_integratable_id = resJ['integrations_integrated_resource']['remote_integratable_id'];
            } else {
                alert("QuickBooks: Error while associating the remote resource id with local integrated resource id in db.");
            }
            if (result_callback) 
                result_callback(evt);
            this.result_callback = null;
        }.bind(this));
    },

    delete_quickbooks_resource_in_db: function(integrated_resource_id, resultCallback) {
        if (integrated_resource_id) {
            this.freshdeskWidget.delete_integrated_resource(integrated_resource_id);
            quickbooksBundle.integrated_resource_id = "";
            quickbooksBundle.remote_integratable_id = "";
        }
    },

    format_date: function(datestring) {
        var months = ['January', 'February', 'March', 'April', 'May', 'June',
            'July', 'August', 'September', 'October', 'November', 'December'];
        var date = new Date(datestring);
        return months[date.getMonth()] + " " + date.getDate() + ", " + date.getFullYear();
    },

    format_date_timeentry: function(date_input) {
        var year = date_input.getFullYear();
        var month = date_input.getMonth() + 1;
        var date = date_input.getDate();

        if (month < 10)
            month = '0' + month
        if (date < 10)
            date = '0' + date

        return year + '-' + month + '-' + date;
    },

    format_address: function(address) {
        var formatted_address = '';

        if (address.Line1)
            formatted_address += address.Line1;
        if (address.City) {
            if (formatted_address != '') {
                formatted_address += ', ';
            }
            formatted_address += address.City;
        }
        if (address.CountrySubDivisionCode) {
            if (formatted_address != '') {
                formatted_address += ', ';
            }
            formatted_address += address.CountrySubDivisionCode;
        }
        if (address.PostalCode) {
            if (formatted_address != '') {
                formatted_address += ', ';
            }
            formatted_address += address.PostalCode;
        }

        return formatted_address;
    },

    filter_records_by_email: function(all_records, emailid) {
        filtered_records = [];
        for (i = 0; i < all_records.length; i++) {
            if (all_records[i].PrimaryEmailAddr) {
                var email_string = all_records[i].PrimaryEmailAddr.Address;
                if(email_string.split(',').indexOf(emailid) >= 0) {
                    filtered_records.push(all_records[i]);
               }
            }
        }
        return filtered_records;
    },

    find_default_client: function(all_records) {
        var default_value = '-';
        for (i = 0; i < all_records.length; i++) {
            if (all_records[i].DisplayName == quickbooksBundle.reqCompany) {
                default_value = all_records[i].Id;
                break;
            }
        }

        if (default_value == '-') {
            var filtered_records = quickbooksWidget.filter_records_by_email(all_records, quickbooksBundle.reqEmail);
            if (filtered_records.length > 0) {
                default_value = filtered_records[0].Id;
            }
        }
        return default_value;
    },

    find_default_employee: function(all_records) {
        var default_value = '-';

        var filtered_records = quickbooksWidget.filter_records_by_email(all_records, quickbooksBundle.agentEmail);
        if (filtered_records.length > 0) {
            default_value = filtered_records[0].Id;
        }
        return default_value;
    }
}

quickbooksWidget = new QuickBooksWidget(quickbooksBundle);