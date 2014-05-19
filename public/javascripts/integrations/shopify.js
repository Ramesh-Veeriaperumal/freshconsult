var ShopifyWidget = Class.create();
ShopifyWidget.prototype= {

    initialize:function(shopifyBundle){
        jQuery("#shopify_widget").addClass('loading-fb');
        shopifyWidget = this;
        shopifyBundle.app_name = "shopify";
        shopifyBundle.integratable_type = "crm";
        shopifyBundle.auth_type = "OAuth";
        shopifyBundle.handleRender = true;
        shopifyBundle.url_auth = true;
        shopifyBundle.url_token_key = "access_token";
        shopifyBundle.use_server_password = "true";
        shopifyBundle.password = "<shopifyauthtoken>";
        shopifyBundle.domain = shopifyBundle.domain;
        this.shopifyBundle = shopifyBundle;
        freshdeskWidget = new Freshdesk.CRMWidget(shopifyBundle, this);
    },

    get_contact_request: function() {
        return { rest_url: "admin/orders/search.json?query=email:"+this.shopifyBundle.reqEmail };
    },

    parse_contact: function(resJson, response){
        orders = [];
        for(var i=0;i<resJson.orders.length;i++){
            order = resJson.orders[i]

            order_date = new Date(order.created_at)
            view_order = {name: order.name,
                customer: order.customer.first_name+" "+ order.customer.last_name,
                customer_id:order.customer.id,
                date: order_date.toDateString()+' at '+order_date.toLocaleTimeString('IST', {hour: '2-digit', minute:'2-digit'}) ,
                number: order["number"],
                fulfillment_status: order.fulfillment_status == null ? "not fulfilled" : order.fulfillment_status,
                financial_status: order.financial_status,
                amount: order.total_price,
                shipping_address: order.shipping_address,
                billing_address: order.billing_address,
                notes: order.note == "" ? "No notes" : order.note ,
                line_items: order.line_items,
                order_url: this.shopifyBundle.domain+"/admin/orders/"+order.id,
                currency: order.currency};

           orders.push(view_order)

        }
        return orders;
    },


    handleRender:function(contacts,crmWidget){

        if ( contacts.length > 0) {
              this.renderSearchResults(contacts,crmWidget);

        } else {
            this.renderContactNa(crmWidget);
        }
        jQuery("#"+crmWidget.options.widget_name).removeClass('loading-fb');
    },

    renderContactNa:function(crmWidget){

        var results_number ={resLength: 0}
        this.renderSearchResultsWidget(results_number,crmWidget);

    },

    renderSearchResults:function(orders,crmWidget){

        var open_orders_final = "",
            completed_orders_final ="";

        var cw=this;

        for(var i=0; i<orders.length; i++){
            line_items="";
            for(var j=0; j<orders[i]["line_items"].length; j++)
            {
                line_items += '<div class="product">'+orders[i]["line_items"][j]["quantity"]+'x '+orders[i]["line_items"][j]["name"]+'</div>'

            }
            line_items += orders[i]["line_items"].length>1 ? '<div>'+(orders[i]["line_items"].length-1)+' more... </div>' : '';
            orders[i].line_items_html = line_items


            order_html =  _.template(cw.ORDER, orders[i]);

            if(orders[i]["fulfillment_status"]=="fulfilled"){
                completed_orders_final += order_html
            }
            else
            {
                open_orders_final += order_html
            }

        }

        var results_number = {
            resLength: orders.length,
            requester: orders[0]["customer"],
            customer_url:  this.shopifyBundle.domain+"/admin/customers/"+orders[0]["customer_id"],
            order_url: this.shopifyBundle.domain+"/admin/orders",
            completed_orders: completed_orders_final == "" ? "<span class='empty_orders'> No completed orders </span> " : completed_orders_final ,
            open_orders: open_orders_final == "" ? "<span class='empty_orders' >No open orders</span>" : open_orders_final
        };


        this.renderSearchResultsWidget(results_number,crmWidget);

    },


    renderSearchResultsWidget:function(results_number,crmWidget){
        var cw=this;
        results_number.widget_name = crmWidget.options.widget_name;
        if(results_number.resLength == 0)
        {
            crmWidget.options.application_html = function(){ return _.template(cw.NO_ORDERS, results_number);}
        }
        else
        {
            crmWidget.options.application_html = function(){ return _.template(cw.CUSTOMER_ORDERS, results_number);}
        }
        crmWidget.display();
    },


    ORDER:
        '<div class="seperator"></div>' +
            '<div class="order" onclick=\'selected_address=jQuery(this).children(".address"); jQuery(".address").not(selected_address).removeAttr("style"); selected_address.toggle(); \'>' +
            '<div class="status">'+
            '<div class="label label-default shipping_status"><%= fulfillment_status %></div>'+
            '<div class="payment_status label label-default"><%= financial_status %></div>'+
            '</div>'+
            '<br>'+
            '<div class="price">'+
            '<div class="order_details"><a href="<%= order_url %>" class="number" target="_blank"> <%= name %> </a>  <span class="items">( <%= number %> items)</span></div>'+
            '<div class="amount" > <%= amount+ " " + currency %> </div>'+
            '</div>'+
            '<br>'+
            '<div class="date"> <%= date %></div>'+
            '<div class="line_items"> <%= line_items_html %> </div>'+
            '<div class="address hide">'+
            '<div class="notes">Notes: <%= notes %> </div>'+
            'Shipping:<%= shipping_address.address1 %> <div class="shipping_address"> <%= shipping_address.address2 %> , <%= shipping_address.city %> <br> <%= shipping_address.country %>  <%= shipping_address.zip %> </div>'+
            'Billing: <span class="address_1"> <%= billing_address.address1 %></span><div class="shipping_address"> <%= billing_address.address2 %> , <%= billing_address.city %> <br> <%= billing_address.country %>  <%= billing_address.zip %> </div>'+
            '</div>'+
            '</div>',

    NO_ORDERS:
        '<div class="shopify_orders"><span class="empty_orders" >No Shopify orders</span></div>',

    CUSTOMER_ORDERS:
        '<div class="shopify_customer"><a class="name" href="<%= customer_url %>" target="_blank" ><%= requester %></a> <a href="<%= order_url  %>" target="_blank" style="float: right;">All orders</a></div>'+
        '<h4 class="shopify_orders_type">Open orders</h4>'+
        '<div class="shopify_orders">'+
           '<%= open_orders %>'+
        '</div>'+
        '<h4 class="shopify_orders_type">Completed orders</h4>'+
            '<div class="shopify_orders">'+
            '<%= completed_orders %>'+
            '</div>'


}


shopifyWidget = new ShopifyWidget(shopifyBundle);


