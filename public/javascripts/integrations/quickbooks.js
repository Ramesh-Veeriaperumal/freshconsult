var QuickBooksWidget = Class.create();

QuickBooksWidget.prototype = {
    QUICKBOOKS_TIMEENTRY_FORM:new Template(
        '<form id="quickbooks-timeentry-form">' +
            '<div class="field first">' +
                '<label>Employee</label>' +
                '<select name="employee-id" id="quickbooks-timeentry-employee" class="full hide" onchange="Freshdesk.NativeIntegration.quickbooksWidget.changeEmployee(this.value);"></select>' +
                '<div class="loading-fb" id="quickbooks-employee-spinner"></div>' +
            '</div>' +
            '<div class="field">' +
                '<label>Customer</label>' +
                '<select name="client-id" id="quickbooks-timeentry-client" class="full hide"></select>' +
                '<div class="loading-fb" id="quickbooks-client-spinner"></div>' +
            '</div>' +
            '<div class="field">' +
                '<label id="quickbooks-timeentry-notes-label">Notes</label>' +
                '<textarea disabled name="request[notes]" id="quickbooks-timeentry-notes" wrap="virtual">' + jQuery('#quickbooks-note').html() + '</textarea>' +
            '</div>' +
            '<div class="field">' +
                '<label id="quickbooks-timeentry-hours-label">Hours</label>' +
                '<input type="text" disabled name="request[hours]" id="quickbooks-timeentry-hours">' +
            '</div>' +
            '<input type="submit" disabled id="quickbooks-timeentry-submit" value="Submit" onclick="Freshdesk.NativeIntegration.quickbooksWidget.logTimeEntry($(\'quickbooks-timeentry-form\'));return false;">' +
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
            '<input type="button" value="Add employee" onclick="Freshdesk.NativeIntegration.quickbooksWidget.addEmployee();">' +
            ' <input type="button" value="Cancel" onclick="Freshdesk.NativeIntegration.quickbooksWidget.cancelAddEmployee();">' +
        '</form>'
    ),

    initialize:function(quickbooksBundle, loadinline) {
        Freshdesk.NativeIntegration.quickbooksWidget = this;
        quickbooksBundle.quickbooksNote = jQuery('#quickbooks-note').html();
        this.executed_date = new Date();
        this.timeEntryJson = "";
        this.SyncToken = 0;

        var init_reqs = [];

        employee_all = {
            "query" : "select id, displayname, PrimaryEmailAddr from employee"
        };
        customer_all = {
            "query" : "select * from customer"
        };

        jQuery('#quickbooks_widget').append('<div id="quickbooks_timeentry_error" class="error"></div>');

        if (quickbooksBundle.remote_integratable_id) {
            init_reqs.push({
                rest_url : "v3/company/" + quickbooksBundle.companyId + "/timeactivity/" + quickbooksBundle.remote_integratable_id,
                method : "get",
                content_type : "application/json",
                on_failure : function(evt) {},
                on_success : Freshdesk.NativeIntegration.quickbooksWidget.loadTimeEntry.bind(this)
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
                var default_value = Freshdesk.NativeIntegration.quickbooksWidget.find_default_employee(employees);
                Freshdesk.NativeIntegration.quickbooksWidget.loadEmployee(employees, default_value);
            }.bind(this),
            on_failure: function(evt) {
                jQuery('#quickbooks_widget .content').hide();
                Freshdesk.NativeIntegration.quickbooksWidget.freshdeskWidget.resource_failure(evt, {}, null);
            }
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
                var default_value = Freshdesk.NativeIntegration.quickbooksWidget.find_default_client(clients);
                Freshdesk.NativeIntegration.quickbooksWidget.loadClient(clients, default_value);
            }.bind(this)
        };
        init_reqs.push(client_req_options);

        var quickbooksOptions = {};
        quickbooksOptions.app_name = "QuickBooks";
        quickbooksOptions.integratable_type = "timesheet";
        quickbooksOptions.widget_name = "quickbooks_widget";
        quickbooksOptions.auth_type = "OAuth1";
        quickbooksOptions.ssl_enabled = true;
        quickbooksOptions.application_id = quickbooksBundle.application_id;
        quickbooksOptions.domain = quickbooksBundle.domain;
        quickbooksOptions.init_requests = init_reqs;
        quickbooksOptions.application_html = function(){ return Freshdesk.NativeIntegration.quickbooksWidget.QUICKBOOKS_TIMEENTRY_FORM.evaluate({}); };

        this.freshdeskWidget = new Freshdesk.Widget(quickbooksOptions);
        if (loadinline) {
            this.convertToInlineWidget();
        }
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
            if (quickbooksBundle.remote_integratable_id){
                jQuery('.quickbooks_timetracking_widget .app-logo input:checkbox').attr('checked',true);
                jQuery('.quickbooks_timetracking_widget .integration_container').toggle(jQuery('.quickbooks_timetracking_widget .app-logo input:checkbox').prop('checked'));
                this.retrieveTimeEntry();
            }
            else{
                jQuery('.quickbooks_timetracking_widget .app-logo input:checkbox').attr('checked',false);
                jQuery('.quickbooks_timetracking_widget .integration_container').toggle(jQuery('.quickbooks_timetracking_widgets .app-logo input:checkbox').prop('checked'));
                this.resetTimeEntryForm();
            }
        }
    },

    retrieveTimeEntry: function(resultCallback) {
        if (quickbooksBundle.remote_integratable_id) {
            this.freshdeskWidget.request({
                rest_url : "v3/company/" + quickbooksBundle.companyId + "/timeactivity/" + quickbooksBundle.remote_integratable_id,
                method : "get",
                content_type : "application/json",
                on_success : Freshdesk.NativeIntegration.quickbooksWidget.loadTimeEntry.bind(this)
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

        employeeData = {"Empl" : employeeData};
        UIUtil.constructDropDown(employeeData, 'hash', 'quickbooks-timeentry-employee', 'Empl', 'ID', ['Name'], null, '', false);
        if (employees.length == 0 || default_value == '-') {
            // UIUtil.addDropdownEntry('quickbooks-timeentry-employee', '_addnew_', 'Add new employee', true);
            UIUtil.addDropdownEntry('quickbooks-timeentry-employee', '-', 'No matching employee found', true);
        }
        UIUtil.chooseDropdownEntry('quickbooks-timeentry-employee', default_value);
        UIUtil.hideLoading('quickbooks','employee','-timeentry');

        Freshdesk.NativeIntegration.quickbooksWidget.enableTimeentryElements();
    },

    loadClient: function(clients, default_value) {
        var clientData = [];

        if (clients.length > 0) {
            for (i = 0; i < clients.length; i++) {
                var client = clients[i];
                clientData.push({"ID" : client.Id.escapeHTML(), "Name" : client.DisplayName.escapeHTML()});
            }
        }

        clientData = {"Client" : clientData}
        UIUtil.constructDropDown(clientData, 'hash', 'quickbooks-timeentry-client', 'Client', 'ID', ['Name'], null, '', false);
        if (clients.length == 0 || default_value == '-') {
            UIUtil.addDropdownEntry('quickbooks-timeentry-client', '-', 'No matching customer found', true);
        }
        UIUtil.chooseDropdownEntry('quickbooks-timeentry-client', default_value);
        UIUtil.hideLoading('quickbooks', 'client', '-timeentry');

        Freshdesk.NativeIntegration.quickbooksWidget.enableTimeentryElements();
    },

    enableTimeentryElements: function() {
      $("quickbooks-timeentry-client").enable();      
      $("quickbooks-timeentry-hours").enable();
      $("quickbooks-timeentry-notes").enable();
      $("quickbooks-timeentry-submit").enable();
    },

    changeEmployee: function(changed_value) {
        if (changed_value == '_addnew_') {
            Freshdesk.NativeIntegration.quickbooksWidget.freshdeskWidget.options.application_html = function() { return Freshdesk.NativeIntegration.quickbooksWidget.QUICKBOOKS_EMPLOYEE_FORM.evaluate({firstname : quickbooksBundle.agentName, lastname : '.', email : quickbooksBundle.agentEmail}); };
            Freshdesk.NativeIntegration.quickbooksWidget.freshdeskWidget.display();
        }
    },

    addEmployee: function() {
        if (!Freshdesk.NativeIntegration.quickbooksWidget.validateEmployeeForm()) {
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

        Freshdesk.NativeIntegration.quickbooksWidget.freshdeskWidget.options.application_html = function() { return Freshdesk.NativeIntegration.quickbooksWidget.QUICKBOOKS_TIMEENTRY_FORM.evaluate({}); };
        Freshdesk.NativeIntegration.quickbooksWidget.freshdeskWidget.display();

        Freshdesk.NativeIntegration.quickbooksWidget.convertToInlineWidget();

        this.freshdeskWidget.request({
            rest_url : "v3/company/" + quickbooksBundle.companyId + "/employee",
            method : "post",
            body : body,
            on_success : Freshdesk.NativeIntegration.quickbooksWidget.returntoTimeentryForm.bind(this)
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
        Freshdesk.NativeIntegration.quickbooksWidget.freshdeskWidget.options.application_html = function() { return Freshdesk.NativeIntegration.quickbooksWidget.QUICKBOOKS_TIMEENTRY_FORM.evaluate({}); };
        Freshdesk.NativeIntegration.quickbooksWidget.freshdeskWidget.display();
        Freshdesk.NativeIntegration.quickbooksWidget.convertToInlineWidget();
        Freshdesk.NativeIntegration.quickbooksWidget.returntoTimeentryForm();
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

        // remove error div so that error message will be thrown as an alert
        jQuery('#quickbooks_timeentry_error').remove();

        var body = new Object();
        body = {
            "TxnDate" : Freshdesk.NativeIntegration.quickbooksWidget.format_date_timeentry(this.executed_date),
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
            "Description" : $("quickbooks-timeentry-notes").value,
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
            on_failure: function(evt) {
                alert("Time activity was not updated in QuickBooks because of invalid employee/customer/time entry.");
            }
        });
    },

    createTimeEntry: function(integratable_id,resultCallback) {
        if(integratable_id)
            this.freshdeskWidget.local_integratable_id = integratable_id;
        var employee_id = $("quickbooks-timeentry-employee").value;
        var client_id = $("quickbooks-timeentry-client").value;
        var minutes = Math.round(($("quickbooks-timeentry-hours").value || 0) * 60);
        var hours = Math.floor(minutes / 60);
        minutes = minutes % 60;

        // remove error div so that error message will be thrown as an alert
        jQuery('#quickbooks_timeentry_error').remove();

        var body = new Object();
        body = {
            "TxnDate" : Freshdesk.NativeIntegration.quickbooksWidget.format_date_timeentry(this.executed_date),
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
            "Description": $("quickbooks-timeentry-notes").value
        };

        body = JSON.stringify(body);

        this.freshdeskWidget.request({
            body: body,
            rest_url: "v3/company/" + quickbooksBundle.companyId + "/timeactivity",
            content_type: "application/json",
            method: "post",
            on_success: function(evt){
                this.handleTimeEntrySuccess(evt);
                Freshdesk.NativeIntegration.quickbooksWidget.add_quickbooks_resource_in_db();
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
            this.freshdeskWidget.request({
                rest_url : "v3/company/" + quickbooksBundle.companyId + "/timeactivity/" + remote_integratable_id,
                method : "get",
                content_type : "application/json",
                on_success : function(evt) {
                    if (evt.responseJSON.IntuitResponse.TimeActivity && evt.responseJSON.IntuitResponse.TimeActivity.BillableStatus == 'HasBeenBilled') {
                        alert('QuickBooks: The purchase cannot be deleted as it would make the invoice, it is linked to, blank.');
                        return;
                    }
                    var body = new Object();
                    body = {
                        "Id" : remote_integratable_id,
                        "SyncToken" : evt.responseJSON.IntuitResponse.TimeActivity.SyncToken
                    };

                    body = JSON.stringify(body);

                    // remove error div so that error message will be thrown as an alert
                    jQuery('#quickbooks_timeentry_error').remove();

                    this.freshdeskWidget.request({
                        body: body,
                        rest_url: "v3/company/" + quickbooksBundle.companyId + "/timeactivity?operation=delete",
                        content_type: "application/json",
                        method: "post",
                        operation: "delete",
                        on_success: function(evt) {
                            Freshdesk.NativeIntegration.quickbooksWidget.handleTimeEntrySuccess(evt);
                            this.delete_quickbooks_resource_in_db(integrated_resource_id, resultCallback);
                            if(resultCallback) resultCallback(evt);
                        }.bind(this)
                    });
                }.bind(this)
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
        $("quickbooks-timeentry-notes").value = (quickbooksBundle.quickbooksNote + "\n" + notes).escapeHTML();
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

    find_default_client: function(all_records) {
        var default_value = '-';
        for (i = 0; i < all_records.length; i++) {
            if (all_records[i].DisplayName == quickbooksBundle.reqCompany) {
                default_value = all_records[i].Id;
                break;
            }
        }

        if (default_value == '-') {
            var filtered_records = QuickBooksUtilWidget.filter_records_by_email(all_records, quickbooksBundle.reqEmail);
            if (filtered_records.length > 0) {
                default_value = filtered_records[0].Id;
            }
        }
        return default_value;
    },

    find_default_employee: function(all_records) {
        var default_value = '-';

        var filtered_records = QuickBooksUtilWidget.filter_records_by_email(all_records, quickbooksBundle.agentEmail);
        if (filtered_records.length > 0) {
            default_value = filtered_records[0].Id;
        }
        return default_value;
    }
};
