var QuickBooksUtilWidget = {
  customers: [],
  process: 'NONE',
  call_back: [],

	renew_token: function() {
		if (quickbooksBundle.token_renewal_date) {
			var token_renewal_date = new Date(quickbooksBundle.token_renewal_date);
			if (new Date() > token_renewal_date) {
				token_renewal_url = '/integrations/quickbooks/refresh_access_token';
				new Ajax.Request(token_renewal_url, {
					asynchronous: true,
					method: "post",
					onSuccess: function(){},
					onFailure: function(){}
				});
			}
		}
	},

  resetVars: function() {
    this.customers = [];
    this.process = 'NONE';
    this.call_back = [];
  },

  getQuery: function(query_type) {
    if (query_type == 'displayname') {
      return { "query" : "select * from customer where displayname = '" + quickbooksBundle.reqCompany + "'" };
    }
    else {
      return { "query" : "select * from customer where PrimaryEmailAddr like '%" + quickbooksBundle.reqEmail + "%'" };
    }
  },

	fetchCustomers: function(widget) {
    var customer_query;
    QuickBooksUtilWidget.process = 'PROCESSING';
    if (quickbooksBundle.reqCompany == '') {
			customer_query = QuickBooksUtilWidget.getQuery('email');
    }
    else {
      customer_query = QuickBooksUtilWidget.getQuery('displayname');
    }

    widget.freshdeskWidget.request({
      rest_url : "v3/company/" + quickbooksBundle.companyId + "/query",
      method : "get",
      encode_params : JSON.stringify(customer_query),
      content_type : "application/json",
      on_success : function(evt) {
      	QuickBooksUtilWidget.handleSuccess(evt, widget);
      }
    });
	},

	handleSuccess: function(resData, widget) {
  	if (resData.responseJSON.IntuitResponse.QueryResponse) {
  		if (resData.responseJSON.IntuitResponse.QueryResponse.Customer instanceof Array) {
  			QuickBooksUtilWidget.customers = resData.responseJSON.IntuitResponse.QueryResponse.Customer;
  		}
  		else {
  			QuickBooksUtilWidget.customers.push(resData.responseJSON.IntuitResponse.QueryResponse.Customer);
  		}

  		if(quickbooksBundle.reqCompany == '') {
  			QuickBooksUtilWidget.customers = QuickBooksUtilWidget.filter_records_by_email(QuickBooksUtilWidget.customers, quickbooksBundle.reqEmail);
  		}
  		QuickBooksUtilWidget.process = 'COMPLETED';
    	QuickBooksUtilWidget.executeCallback();
  	}
  	else {
  		if (quickbooksBundle.reqCompany) {
    		QuickBooksUtilWidget.fetchCustomersUsingEmail(widget);
    	}
    	else {
    		QuickBooksUtilWidget.process = 'COMPLETED';
    		QuickBooksUtilWidget.executeCallback();
    	}
  	}
  },

	fetchCustomersUsingEmail: function(widget) {
		widget.freshdeskWidget.request({
      rest_url : "v3/company/" + quickbooksBundle.companyId + "/query",
      method : "get",
      encode_params : JSON.stringify(QuickBooksUtilWidget.getQuery('email')),
      content_type : "application/json",
      on_success : function(evt) {
      	QuickBooksUtilWidget.process = 'COMPLETED';
      	if (evt.responseJSON.IntuitResponse.QueryResponse) {
      		if (evt.responseJSON.IntuitResponse.QueryResponse.Customer instanceof Array) {
      			QuickBooksUtilWidget.customers = evt.responseJSON.IntuitResponse.QueryResponse.Customer;
      		}
      		else {
      			QuickBooksUtilWidget.customers.push(evt.responseJSON.IntuitResponse.QueryResponse.Customer);
      		}
      		QuickBooksUtilWidget.customers = QuickBooksUtilWidget.filter_records_by_email(QuickBooksUtilWidget.customers, quickbooksBundle.reqEmail);
      	}
    		QuickBooksUtilWidget.executeCallback();
      }
    });
	},

	executeCallback: function() {
		for (var i = 0; i < QuickBooksUtilWidget.call_back.length; i++) {
			QuickBooksUtilWidget.call_back[i]();
		}
		QuickBooksUtilWidget.call_back = [];
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
};

QuickBooksUtilWidget.renew_token();

jQuery(document).on('pjax:beforeReplace', function(){
  QuickBooksUtilWidget.resetVars();
});
