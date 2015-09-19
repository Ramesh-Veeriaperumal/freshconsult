var QuickBooksContactsWidget = Class.create();

QuickBooksContactsWidget.prototype = {
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
				'</div>'
		),
		CONTACT_SEARCH_RESULTS:new Template(
				'<div id="search_results_div" class="title #{widget_name}_bg">' +
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
				jQuery("#quickbooks_contacts_widget").addClass('sloading loading-small loading-block');
				var $this = this;
				quickbooksBundle.quickbooksNote = jQuery('#quickbooks-note').html();
				var quickbooksOptions = {};
				quickbooksOptions.app_name = "QuickBooks";
				quickbooksOptions.widget_name = "quickbooks_contacts_widget";
				quickbooksOptions.auth_type = "OAuth1";
				quickbooksOptions.ssl_enabled = true;
				quickbooksOptions.application_id = quickbooksBundle.application_id;
				quickbooksOptions.domain = quickbooksBundle.domain;

				this.freshdeskWidget = new Freshdesk.Widget(quickbooksOptions);
				$this.initiateProcess();
		},

  	initiateProcess: function() {
  		var $this = this;
      if (QuickBooksUtilWidget.process == 'NONE') {
      	QuickBooksUtilWidget.customers = [];
        QuickBooksUtilWidget.call_back.push(function() { $this.handleContactSuccess($this) });
        QuickBooksUtilWidget.fetchCustomers($this);
      }
      else if (QuickBooksUtilWidget.process == 'COMPLETED') {
        $this.handleContactSuccess($this);
      }
      else {
        QuickBooksUtilWidget.call_back.push(function() { $this.handleContactSuccess($this) });
      }
    },

    handleContactSuccess: function($this) {
    	if (quickbooksBundle.reqCompany == '' && QuickBooksUtilWidget.customers.length == 1) {
				$this.createCompanyinFreshdesk(QuickBooksUtilWidget.customers);
			}
      $this.parse_contact(QuickBooksUtilWidget.customers);
    },

		createCompanyinFreshdesk: function(contacts) {
				this.freshdeskWidget.request({
						source_url : "/integrations/quickbooks/create_company",
						method : "post",
						name : contacts[0].DisplayName,
						requester_email : quickbooksBundle.reqEmail,
						on_success : function() {},
						on_failure : function() {}
				});
		},

		parse_contact: function(customers) {
			var $this = this;
				if (customers && customers.length > 1) {
						$this.renderSearchResults(customers);
				}
				else if (customers && customers.length > 0) {
						$this.renderContactWidget(customers[0], false);
						jQuery('#search-back').hide();
				}
				else {
						var contact_html = $this.CONTACT_NA.evaluate({
								reqName : quickbooksBundle.reqName,
								widget_name : "quickbooks_contacts_widget",
								app_name : "QuickBooks"
						});

						jQuery("#quickbooks_contacts_widget .content").html(contact_html);
						jQuery("#quickbooks_contacts_widget").removeClass('sloading loading-small');
				}
		},

		renderContactWidget: function(params, multiple_contacts) {
			var $this = this;
				var full_name = '';
				full_name = (params.Title ? params.Title.escapeHTML() + ' ' : '')
						+ (params.GivenName ? params.GivenName.escapeHTML() + ' ' : '')
						+ (params.MiddleName ? params.MiddleName.escapeHTML() + ' ' : '')
						+ (params.FamilyName ? params.FamilyName.escapeHTML() + ' ' : '')
						+ (params.Suffix ? params.Suffix.escapeHTML() : '');
				var contact_html = $this.QUICKBOOKS_CONTACTS.evaluate({
						app_name : "QuickBooks",
						widget_name : "quickbooks_contacts_widget",
						display_name : params.DisplayName.escapeHTML() || 'N/A',
						email : params.PrimaryEmailAddr ? params.PrimaryEmailAddr.Address.replace(/,/g, ', ').escapeHTML() : 'N/A',
						phone : params.PrimaryPhone ? params.PrimaryPhone.FreeFormNumber.escapeHTML() : 'N/A',
						mobile : params.Mobile ? params.Mobile.FreeFormNumber.escapeHTML() : 'N/A',
						address : params.BillAddr ? $this.format_address(params.BillAddr).escapeHTML() : 'N/A',
						billto : full_name == '' ? 'N/A' : full_name,
						url : "https://qbo.intuit.com/app/customerdetail?nameId=" + params.Id
				});

				if (multiple_contacts) {
						jQuery('#quickbooks_contacts_widget .content').append('<div id="contact_widget_' + params.Id + '" class="quickbooks_contacts_div">' + contact_html + '<div class="field bottom_div"></div><div class="external_link"><a id="search-back" href="#"> &laquo; Back </a></div></div>');
				}
				else {
						jQuery("#quickbooks_contacts_widget .content").html(contact_html);
				}
				jQuery("#quickbooks_contacts_widget").removeClass('sloading loading-small');
		},

		renderSearchResults: function(customers) {
			var $this = this;
				var contact_list = '<ul>';
				for (i = 0; i < customers.length; i++) {
						contact_list += '<li><a class="multiple-contacts" href="#" data-contact="' + i + '">' + customers[i].DisplayName + '</a></li>';
				}
				contact_list += '</ul>';
				var contact_html = $this.CONTACT_SEARCH_RESULTS.evaluate({resLength : customers.length, requester : quickbooksBundle.reqEmail, resultsData : contact_list});
				jQuery("#quickbooks_contacts_widget .content").html(contact_html);
				jQuery("#quickbooks_contacts_widget").removeClass('sloading loading-small');

				jQuery('#quickbooks_contacts_widget').on('click', '#search-back', (function(ev) {
						ev.preventDefault();
						jQuery('.quickbooks_contacts_div').hide();
						jQuery('#search_results_div').show();
				}));

				jQuery('#quickbooks_contacts_widget').on('click', '.multiple-contacts', (function(ev) {
						ev.preventDefault();

						var contact_index = customers[jQuery(this).data('contact')].Id;
						if (jQuery('#contact_widget_' + contact_index).length) {
								jQuery('#search_results_div').hide();
								jQuery('#contact_widget_' + contact_index).show();
						}
						else {
								jQuery('#search_results_div').hide();
								jQuery("#quickbooks_contacts_widget").addClass('sloading loading-small');
								$this.renderContactWidget(customers[jQuery(this).data('contact')], true);
						}
				}));
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
};
