var MagentoWidget = Class.create()
MagentoWidget.prototype= {
    
    ORDERS_LIST: new Template(
        "<div class='order-wrapper'>"+
            "<div class='row-fluid order-details' >"+
                "<div class='span16'>" +
                    "<div class='mb2'><span class='magento-order-status label label-light'> #{status} </span></div>"+
                    "<div>" +
                        "<a class='order-id-link lazyload' data-show='##{increment_id}' rel='freshdialog' data-target='##{increment_id}' data-lazyload='true' data-template-footer='' href='#'>##{increment_id}</a>"+
                        "<span class='info-data'>&nbsp;(#{order_items_length} items)</span>"+
                        "<span class='pull-right'> #{website_name} </span>" +
                    "</div>" +
                    "<div class='date info-data pb0'>on: #{created_at}</div>"+
                    "<div>Total : #{store_currency_code} #{grand_total}</div>" +
                "</div>" +
            "</div>" + 
            "<div class='product-list hide' rel='lazyload' id='#{increment_id}'>#{line_items_html} </div>" +
        "</div>"
    ),

    ORDER_LINE_ITEM: new Template(
        '<tr class="#{total_row_class}">'
            + '<td>#{name}</td>'
            + '<td>#{quantity}</td>'
            + '<td>#{price}</td>'
            + '<td>#{tax_amount}</td>'
            + '<td>#{store_currency_code}&nbsp;#{row_total}</td>'
        + '</tr>'
    ),

    LINE_ITEM_HTML:new Template(
        '<table class="table">'
            + '<tr><th>Product</th><th>Qty</th><th>Price</th><th>Tax Amount</th><th>Row Total</th></tr>'
            + '#{line_items_html}'
        + '</table>'
    ),

    ORDER_POPUP_VIEW:new Template(
        '<div class="integ_invoice_modal">'
            + '<div>'
                + '<span class="integ_invoice_header"> Order ##{increment_id}</span>'
                + '<span class="pull-right magento-order-status label label-light">#{status}</span>'
            + '</div>'
            + '<div class="mt4"><span class="invoice_data_text">Created on: </span> #{created_at}</div>'
            + '<div class="mt4"><span class="invoice_data_text">Shipping: </span>#{street}</div>'
            + '<div class="mt4 ml60">#{city} - #{postcode}</div>'
            + '<div class="mt4 ml60">#{region}</div>'
        + '</div>'
    ),

    MAGENTO_ORDERS_HEADER:new Template(
        
        '<div class="mb5">' +
            '<span class="pull-right">' +
                '<a target="_blank" href="#{orders_link}">All Orders</a>' +
            '</span>' +
        '</div>' +
        '<div id="email-dropdown-div" class="clr-bth custom-select2 hide"><div class="select2-container">Orders for <select name="email_dropdown" id="magento-email-dropdown"></select></div></div>' +
        '<div id="magento_orders" class="clr-bth mt10">' +
        '</div>'
    ),

    MAGENTO_LOADING_INDICATOR: new Template("<div id='magento_loading' class='sloading loading-small loading-block'></div>"),

    ORDERS_LINK: "/index.php/admin/sales_order/index",

    ERROR_MESSAGE: "Unknown error. Please contact support@freshdesk.com",

    MAGENTO_NO_ORDERS: "No orders for this email.",

    MAGENTO_NO_EMAIL : 'Email not available for this requester. A valid Email is required to fetch the orders from Magento.',

    initialize:function(){
        var $this = this;
        this.email_list = magentoBundle.reqEmails.split(",");
        this.current_position = "0";
        this.current_email = magentoBundle.from_email;
        this.shop_names = [];
        if(this.current_email){

            this.freshdeskWidget = new Freshdesk.Widget({
                app_name: "magento",
                use_server_password: true,
                integratable_type:"crm",
                widget_name:"magento_widget",
                ssl_enabled:false,
            });

            $this.get_orders($this.current_position, $this.current_email);

            jQuery('#magento .content').on('change','#magento-email-dropdown', (function(ev){
                ev.preventDefault();
                jQuery('#magento .content').html($this.MAGENTO_LOADING_INDICATOR.evaluate({}));
                $this.current_email = jQuery(this).val();
                $this.get_orders($this.current_position, $this.current_email);
            }));
        } 
        else {
            jQuery("#magento .content").html($this.MAGENTO_NO_EMAIL);
        }
     },

    get_orders: function(position, email_id){
        var $this = this;
        this.freshdeskWidget.request({
            source_url: "/integrations/service_proxy/fetch",
            event: 'customer_orders',
            payload: JSON.stringify({position: position, email: email_id}),
            on_failure: $this.handlefailure,
            on_success: function(resData) {
                    $this.render_orders(resData.responseJSON);
            }
        });
    },

    render_orders:function(responseJSON) {
        var $this = this,
            shop_name = Object.keys(responseJSON)[0],
            orders = responseJSON[shop_name],
            orders_tag = "",
            email_list_html = "",
            domain_name = orders["domain"],
            orders_link = domain_name + $this.ORDERS_LINK;

        if(orders["message"].length == 0) {
            orders["status"] = 400;
            orders["message"] += $this.MAGENTO_NO_ORDERS;
        }

        if(orders["status"] == 400) {
            orders_tag += orders["message"];
        }
        else {
            var orders1 = orders["message"];
                
            Object.keys(orders1).sort().reverse().forEach(function(key){
                var val = orders1[key],
                    line_items_html = "";

                var created_at = $this.format_date(val.created_at);

                line_items_html += $this.ORDER_POPUP_VIEW.evaluate({increment_id: $this.escapeHtmlCustom(val.increment_id), 
                                    created_at: $this.escapeHtmlCustom(created_at),
                                    store_currency_code: $this.escapeHtmlCustom(val.store_currency_code), 
                                    status: val.status.humanize().capitalize(), 
                                    street: $this.escapeHtmlCustom(val.addresses[1].street), 
                                    city: $this.escapeHtmlCustom(val.addresses[1].city), 
                                    postcode: $this.escapeHtmlCustom(val.addresses[1].postcode),
                                    region: $this.escapeHtmlCustom(val.addresses[1].region)
                });
                jQuery.each(val.order_items,function(key1, val1) {   
                    line_items_html += $this.ORDER_LINE_ITEM.evaluate({name: $this.escapeHtmlCustom(val1.name),
                                        price: $this.escapeHtmlCustom(parseFloat(val1.price || 0).toFixed(2)), 
                                        tax_amount: $this.escapeHtmlCustom(parseFloat(val1.tax_amount || 0).toFixed(2)), 
                                        quantity: $this.escapeHtmlCustom(parseFloat(val1.qty_ordered || 0).toFixed(2)),
                                        store_currency_code: $this.escapeHtmlCustom(val.store_currency_code), 
                                        row_total: $this.escapeHtmlCustom(parseFloat(val1.row_total || 0).toFixed(2))
                                    });
                });

                line_items_html += $this.ORDER_LINE_ITEM.evaluate({tax_amount: "Shipping & Handling (incl tax)", 
                                        total_row_class: "integ_invoice_total_row",
                                        store_currency_code: $this.escapeHtmlCustom(val.store_currency_code), 
                                        row_total: $this.escapeHtmlCustom(parseFloat(val.shipping_incl_tax || 0).toFixed(2))
                                    });

                line_items_html += $this.ORDER_LINE_ITEM.evaluate({tax_amount: "Grand Total", 
                                        total_row_class: "integ_invoice_total_row",
                                        store_currency_code: $this.escapeHtmlCustom(val.store_currency_code), 
                                        row_total: $this.escapeHtmlCustom(parseFloat(val.grand_total || 0).toFixed(2))
                                    });

                line_items_html += $this.ORDER_LINE_ITEM.evaluate({tax_amount: "Total Paid", 
                                        total_row_class: "integ_invoice_total_row",
                                        store_currency_code: $this.escapeHtmlCustom(val.store_currency_code), 
                                        row_total: $this.escapeHtmlCustom(parseFloat(val.total_paid || 0).toFixed(2))
                                    });

                line_items_html = $this.LINE_ITEM_HTML.evaluate({line_items_html: line_items_html});

                var website_name = val.store_name.split("\n")[0];

                orders_tag +=  $this.ORDERS_LIST.evaluate({increment_id: $this.escapeHtmlCustom(val.increment_id), 
                                    order_items_length: val.order_items.length,
                                    website_name : $this.escapeHtmlCustom(website_name),
                                    created_at: $this.escapeHtmlCustom(created_at),
                                    store_currency_code: $this.escapeHtmlCustom(val.store_currency_code),
                                    grand_total: $this.escapeHtmlCustom(parseFloat(val.grand_total || 0).toFixed(2)),
                                    line_items_html: line_items_html,
                                    status: $this.escapeHtmlCustom(val.status.humanize().capitalize())
                                });
            });
        }


        jQuery("#magento_loading").remove();
        jQuery("#magento .content").html(this.MAGENTO_ORDERS_HEADER.evaluate({orders_link: orders_link}));
        
        if ($this.email_list.length > 1) {
            var email_dropdown_opts = [];
            for(var i = 0; i < $this.email_list.length; i++) {
                email_dropdown_opts.push({"ID" : $this.email_list[i], "Name" : $this.email_list[i]});
            }
            email_dropdown_opts = {'email_dropdown' : email_dropdown_opts};
            UIUtil.constructDropDown(email_dropdown_opts, 'hash', 'magento-email-dropdown', 'email_dropdown', 'ID', ['Name'], null, '', false);
            jQuery('#magento-email-dropdown').addClass('select2');
            UIUtil.chooseDropdownEntry('magento-email-dropdown', $this.current_email);
            UIUtil.hideLoading('magento','dropdown','-email');

            jQuery('#email-dropdown-div').show();
        }

        jQuery("#magento_orders").append(orders_tag);
    },

    format_date: function(datestring) {
        datestring += " GMT";
        var months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        var date = new Date(datestring);
        return months[date.getMonth()] + " " + date.getDate() + ", " + date.getFullYear() + " " +date.toLocaleTimeString();
    },

    handlefailure: function(evt) {
        jQuery("#magento_loading").remove();
        jQuery("#magento .content").html(this.ERROR_MESSAGE);
    },

    escapeHtmlCustom: function(val) {
        return (val || "").escapeHTML();
    }

}