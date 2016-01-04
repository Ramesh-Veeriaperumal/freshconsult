var QuickBooksInvoiceWidget = Class.create();

QuickBooksInvoiceWidget.prototype = {
    QUICKBOOKS_NO_INVOICE:new Template(
        '<div class="integ_empty_invoices">No Invoices</div>'
    ),
    CONTACT_NA:new Template(
        '<div class="integ_empty_invoices">Cannot find #{reqName} in #{app_name}</div>'
    ),
    INVOICE_DATA_LI:new Template(
        '<li class="clearfix clear integ_invoice_each">'
            + '<a href="#" class="invoice_number mr8 lazyload" rel="freshdialog" data-target="#line_items_modal#{id}" data-lazyload="true" data-template-footer="">' + 'Invoice #' + "#{docnumber}</a>"
            + '<span class="pull-right #{invoice_status_class}">' + "#{status}</span>"
            + '<div class="mt4"><span class="invoice_data_text">Created on: </span>' + "#{txndate}</div>"
            + '<div class="mt4"><span class="invoice_data_text">Balance Due: </span>' + "#{balance}" + '<span class="invoice_data_text">, on </span>' + "#{duedate}</div>"
        + '</li>'
    ),
    INVOICE_DATA_MODAL:new Template(
        '<div class="integ_invoice_modal">'
            + '<div>'
                + '<span class="integ_invoice_header">' + 'Invoice #' + "#{docnumber}</span>"
                + '<a class="pull-right" href="https://qbo.intuit.com/app/invoice?txnId=#{id}" target="_blank">View on QuickBooks</a>'
            + '</div>'
            + '<div class="mt4"><span class="invoice_data_text">Created on: </span>' + "#{txndate}</div>"
            + '<div class="mt4">'
                + '<span class="invoice_data_text">Balance Due: </span>' + "#{balance}"
                + '<span class="invoice_data_text">, on </span>' + "#{duedate}"
                + '<span class="pull-right #{invoice_status_class}">' + "#{status}</span>"
            + '</div>'
        + '</div>'
    ),
    LINE_ITEMS_ROW:new Template(
        '<tr class="#{total_row_class}">'
            + '<td>#{Item}</td>'
            + '<td class="break-all">#{Description}</td>'
            + '<td>#{Qty}</td>'
            + '<td>#{Rate}</td>'
            + '<td>#{Amount}</td>'
        + '</tr>'
    ),
    INVOICE_DATA_LI_NONCOMMERCIAL:new Template(
        '<li class="clearfix clear integ_invoice_each">'
            + '<a href="#" class="invoice_number mr8 lazyload" rel="freshdialog" data-target="#line_items_modal#{id}" data-lazyload="true" data-template-footer="">' + 'Invoice #' + "#{docnumber}</a>"
            + '<span class="pull-right #{invoice_status_class}">' + "#{status}</span>"
            + '<div class="mt4"><span class="invoice_data_text">Created on: </span>' + "#{txndate}</div>"
            + '<div class="mt4"><span class="invoice_data_text">Due on: </span>' + "#{duedate}</div>"
        + '</li>'
    ),
    INVOICE_DATA_MODAL_NONCOMMERCIAL:new Template(
        '<div class="integ_invoice_modal">'
            + '<div>'
                + '<span class="integ_invoice_header">' + 'Invoice #' + "#{docnumber}</span>"
                + '<a class="pull-right" href="https://qbo.intuit.com/app/invoice?txnId=#{id}" target="_blank">View on QuickBooks</a>'
            + '</div>'
            + '<div class="mt4"><span class="invoice_data_text">Created on: </span>' + "#{txndate}</div>"
            + '<div class="mt4">'
                + '<span class="invoice_data_text">Due on: </span>' + "#{duedate}"
                + '<span class="pull-right #{invoice_status_class}">' + "#{status}</span>"
            + '</div>'
        + '</div>'
    ),
    LINE_ITEMS_ROW_NONCOMMERCIAL:new Template(
        '<tr>'
            + '<td>#{Item}</td>'
            + '<td class="break-all">#{Description}</td>'
            + '<td>#{Qty}</td>'
        + '</tr>'
    ),

    initialize:function(quickbooksBundle) {
        var $this = this;
        quickbooksBundle.quickbooksNote = jQuery('#quickbooks-note').html();
        var quickbooksOptions = {};
        quickbooksOptions.app_name = "QuickBooks";
        quickbooksOptions.widget_name = "quickbooks_side_bar_widget";
        quickbooksOptions.auth_type = "OAuth1";
        quickbooksOptions.ssl_enabled = true;
        quickbooksOptions.application_id = quickbooksBundle.application_id;
        quickbooksOptions.domain = quickbooksBundle.domain;

        $this.freshdeskWidget = new Freshdesk.Widget(quickbooksOptions);
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
      if (QuickBooksUtilWidget.customers.length > 0) {
        var id = [];
        if (QuickBooksUtilWidget.customers.length > 1) {
          $this.renderMultiCustomerInvoices(QuickBooksUtilWidget.customers);
          return;
        }
        id = jQuery.map(QuickBooksUtilWidget.customers, function(customer) {
          return customer.Id;
        });
        $this.populateInvoices(id, false);
      }
      else {
        jQuery("#quickbooks_side_bar_widget .content").html($this.CONTACT_NA.evaluate({reqName : quickbooksBundle.reqName, app_name : 'QuickBooks'}));
      }
    },

    renderMultiCustomerInvoices: function(customers) {
        var $this = this;
        var customer_list = '<ul id="multiple-invoices-ul">';
        for (j = 0; j < customers.length; j++) {
            customer_list += '<li><a class="multiple-customers-invoices" href="#" data-contact="' + parseInt(customers[j].Id) + '">' + customers[j].DisplayName.escapeHTML() + '</a></li>';
        }
        customer_list += '</ul>';

        jQuery("#quickbooks_side_bar_widget .content").html(customer_list);

        jQuery('#quickbooks_side_bar_widget').on('click', '#search-back-invoices', (function(ev) {
            ev.preventDefault();
            jQuery('.quickbooks_invoices_div').hide();
            jQuery('#multiple-invoices-ul').show();
        }));

        jQuery('#quickbooks_side_bar_widget').on('click', '.multiple-customers-invoices', (function(ev) {
            ev.preventDefault();
            var customer_id = jQuery(this).data('contact');

            if (jQuery('#invoice_widget_' + customer_id).length) {
                jQuery('#multiple-invoices-ul').hide();
                jQuery('#invoice_widget_' + customer_id).show();
            }
            else {
                jQuery('#multiple-invoices-ul').hide();
                jQuery("#quickbooks_side_bar_widget").addClass('sloading loading-small');
                $this.populateInvoices([customer_id], true);
            }
        }));
    },

    populateInvoices: function(customer_ids, multiple_customers) {
        var $this = this;
        var id_string = '';
        id_string = jQuery.map(customer_ids, function(value) {
            return "'" + value + "'";
        }).join(',');
        var invoice_query = {
            "query" : "select * from invoice where CustomerRef in (" + id_string + ") order by id desc maxresults 5"
        };

        this.freshdeskWidget.request({
            rest_url : "v3/company/" + quickbooksBundle.companyId + "/query",
            method : "get",
            encode_params : JSON.stringify(invoice_query),
            content_type : "application/json",
            on_success : function(resData) {
                var invoices = [];
                var item_ids = [];
                if (resData.responseJSON.IntuitResponse.QueryResponse) {
                    if (resData.responseJSON.IntuitResponse.QueryResponse.Invoice instanceof Array) {
                        invoices = resData.responseJSON.IntuitResponse.QueryResponse.Invoice;
                    }
                    else {
                        invoices.push(resData.responseJSON.IntuitResponse.QueryResponse.Invoice);
                    }

                    for (i = 0; i < invoices.length; i++) {
                        if (invoices[i].Line) {
                            for (j = 0; j < invoices[i].Line.length; j++) {
                                var item = invoices[i].Line[j];
                                if (item.DetailType == "SalesItemLineDetail" && item.SalesItemLineDetail) {
                                    item_ids.push(item.SalesItemLineDetail.ItemRef);
                                }
                            }
                        }
                    }
                    $this.fetch_items_parse_invoice(invoices, item_ids, customer_ids[0], multiple_customers);
                }
                else {
                    if (multiple_customers) {
                        jQuery('#quickbooks_side_bar_widget .content').append('<div id="invoice_widget_' + customer_ids[0] + '" class="quickbooks_invoices_div">' + $this.QUICKBOOKS_NO_INVOICE.evaluate({}) + '<div class="field bottom_div"></div><div class="external_link"><a id="search-back-invoices" href="#"> &laquo; Back </a></div></div>');
                        jQuery("#quickbooks_side_bar_widget").removeClass('sloading loading-small');
                    }
                    else {
                        jQuery("#quickbooks_side_bar_widget .content").html($this.QUICKBOOKS_NO_INVOICE.evaluate({}));
                    }
                }
            }
        });
    },

    fetch_items_parse_invoice: function(invoices, item_ids, customer_id, multiple_customers) {
        var $this = this;
        var id_string = '';
        id_string = jQuery.map(item_ids.uniq(), function(value) {
            return "'" + value + "'";
        }).join(',');
        var item_query = {
            "query" : "select id, name from item where id in (" + id_string + ")"
        };

        this.freshdeskWidget.request({
            rest_url : "v3/company/" + quickbooksBundle.companyId + "/query",
            method : "get",
            encode_params : JSON.stringify(item_query),
            content_type : "application/json",
            on_success : function(resData) {
                items = {};
                if (resData.responseJSON.IntuitResponse.QueryResponse) {
                    if (resData.responseJSON.IntuitResponse.QueryResponse.Item instanceof Array) {
                        var temp_items = resData.responseJSON.IntuitResponse.QueryResponse.Item;
                        for (i = 0; i < temp_items.length; i++) {
                            items[temp_items[i].Id] = temp_items[i].Name;
                        }
                    }
                    else {
                        items[resData.responseJSON.IntuitResponse.QueryResponse.Item.Id] = resData.responseJSON.IntuitResponse.QueryResponse.Item.Name;
                    }
                }

                $this.parse_invoice(invoices, items, customer_id, multiple_customers);
            }
        });
    },

    parse_invoice: function(invoices, items, customer_id, multiple_customers) {
        var $this = this;
        var invoice_html = '<ul class="integ_invoices">';
        for(i = 0; i < invoices.length; i++) {
          var invoice = invoices[i];
          var invoice_status = '';
          var invoice_status_class = '';

          if (parseFloat(invoice.Balance) == 0) {
            invoice_status = 'Paid';
            invoice_status_class = 'qb_paid';
          }
          else if ((moment().isBefore(invoice.DueDate) || moment().isSame(invoice.DueDate)) && parseFloat(invoice.Balance) == parseFloat(invoice.TotalAmt)) {
            invoice_status = 'Open';
            invoice_status_class = 'qb_open';
          }
          else if ((moment().isBefore(invoice.DueDate) || moment().isSame(invoice.DueDate)) && parseFloat(invoice.Balance) < parseFloat(invoice.TotalAmt)) {
            invoice_status = 'Partial';
            invoice_status_class = 'qb_partial';
          }
          else if (moment().isAfter(invoice.DueDate) && parseFloat(invoice.Balance) <= parseFloat(invoice.TotalAmt)) {
            invoice_status = 'Overdue';
            invoice_status_class = 'qb_overdue';
          }

          var eval_params = {
            id : invoice.Id,
            docnumber : invoice.DocNumber,
            status : invoice_status,
            duedate : $this.format_date(invoice.DueDate),
            txndate : $this.format_date(invoice.TxnDate),
            invoice_status_class : invoice_status_class
          };

          if (quickbooksBundle.invoice_option == '1') {
            eval_params.balance = invoice.CurrencyRef + ' ' + invoice.Balance;
            invoice_html += $this.INVOICE_DATA_LI.evaluate(eval_params);
          }
          else {
            invoice_html += $this.INVOICE_DATA_LI_NONCOMMERCIAL.evaluate(eval_params);
          }

          invoice_html += $this.get_invoice_modal_div(invoice, items, invoice_status, invoice_status_class);
        }
        invoice_html += "</ul>";

        if (multiple_customers) {
          invoice_html = '<div id="invoice_widget_' + customer_id + '" class="quickbooks_invoices_div">' + invoice_html;
          invoice_html += '<div class="field bottom_div"></div><div class="external_link"><a id="search-back-invoices" href="#"> &laquo; Back </a></div></div>';
          jQuery("#quickbooks_side_bar_widget .content").append(invoice_html);
          jQuery("#quickbooks_side_bar_widget").removeClass('sloading loading-small');
        }
        else {
          jQuery("#quickbooks_side_bar_widget .content").html(invoice_html);
        }
    },

    format_date: function(datestring) {
      var months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
      var date = new Date(datestring);
      return months[date.getMonth()] + " " + date.getDate() + ", " + date.getFullYear();
    },

    get_invoice_modal_div: function(invoice, items, invoice_status, invoice_status_class) {
      var $this = this;
      var html = '<div id="line_items_modal' + invoice.Id + '" class="hide" rel="lazyload">';
      var eval_params = {
        id : invoice.Id,
        docnumber : invoice.DocNumber,
        status : invoice_status,
        duedate : $this.format_date(invoice.DueDate),
        txndate : $this.format_date(invoice.TxnDate),
        invoice_status_class : invoice_status_class
      };
      if (quickbooksBundle.invoice_option == '1') {
        eval_params.balance = invoice.CurrencyRef + ' ' + invoice.Balance;
        html += $this.INVOICE_DATA_MODAL.evaluate(eval_params);
      }
      else {
          html += $this.INVOICE_DATA_MODAL_NONCOMMERCIAL.evaluate(eval_params);
      }
      html += '<table class="table">';
      if (quickbooksBundle.invoice_option == '1') {
        html += '<tr><th>Item</th><th>Description</th><th>Qty</th><th>Rate</th><th>Amount</th></tr>';
      }
      else {
        html += '<tr><th>Item</th><th>Description</th><th>Qty</th></tr>';
      }

      if (invoice.Line) {
        for (j = 0; j < invoice.Line.length; j++) {
          var item = invoice.Line[j];
          var quantity = '';
          var rate = '';
          var item_name = '';
          var description = '';
          var total_row_class = '';

          if (item.DetailType == "SalesItemLineDetail" && item.SalesItemLineDetail) {
            quantity = item.SalesItemLineDetail.Qty.escapeHTML();
            rate = item.SalesItemLineDetail.UnitPrice.escapeHTML();
            description = item.Description.escapeHTML();
            item_name = items[item.SalesItemLineDetail.ItemRef].escapeHTML();
          }
          if (item.DetailType == "SubTotalLineDetail") {
            rate = "Total";
            total_row_class = "integ_invoice_total_row";
          }

          if (quickbooksBundle.invoice_option == '1') {
            html += $this.LINE_ITEMS_ROW.evaluate({
              Item : item_name,
              Description : description,
              Qty : quantity,
              Rate : rate,
              Amount : item.Amount,
              total_row_class : total_row_class
            });
          }
          else {
            if (item.DetailType != "SubTotalLineDetail") {
              html += $this.LINE_ITEMS_ROW_NONCOMMERCIAL.evaluate({
                Item : item_name,
                Description : item.Description,
                Qty : quantity
              });
            }
          }
        }
      }
      html += '</table></div>';

      return html;
    }
};
