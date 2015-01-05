var SEOshopWidget = Class.create()
SEOshopWidget.prototype= {

	SEOSHOP_NO_CONTACT:new Template(
			'<div class="no_orders"><span class="empty_orders" >No SeoShop orders</span></div>'
			),

	initialize:function(seoshopBundle){
		var seoshopWidget = this;
		var init_reqs = []; 
		var reqEmail = seoshopBundle.reqEmail;
		if(reqEmail){
		init_reqs.push({
			rest_url : "customers.json?email="+seoshopBundle.reqEmail,
			method: "get",
			content_type: "application/json",
			on_success: seoshopWidget.parse_contact.bind(this),
			on_failure: seoshopWidget.handlefailure.bind(this)
		});

		this.freshdeskWidget = new Freshdesk.Widget({
			app_name: "seoshop",
			integratable_type:"crm",
			widget_name:"seoshop_widget",
			use_server_password:true,
			domain:seoshopBundle.domain,
			auth_type:"NoAuth",
			ssl_enabled:true,
			init_requests: init_reqs
		});
		} else {
			jQuery("#seoshop .content").html(seoshopWidget.SEOSHOP_NO_CONTACT.evaluate({}));
		}
	 },

	parse_contact: function(resJson){
		var orders = [];
		if(resJson.responseJSON.customers.length == 0){
			jQuery("#seoshop .content").html(seoshopWidget.SEOSHOP_NO_CONTACT.evaluate({}));
		}
		else {
			for(var i=0;i<resJson.responseJSON.customers.length;i++){
		    var customer = resJson.responseJSON.customers[i]
		    var customer_id = customer.id

		    this.freshdeskWidget.request({
				method: "get",
				entity_name: "request",
				rest_url: "orders.json?customer="+customer_id,
				body:"",
				on_success: seoshopWidget.orderResponse.bind(this),
				on_failure: seoshopWidget.handlefailure.bind(this)
			});
			}
		}
	},

	orderResponse:function(data){
		var orderdata = data.responseJSON.orders,
			orders = [],
			totalOrders = orderdata.length,
			ordersProcessed = 0; 
		
		if(totalOrders > 0){
			for(var i=0;i<totalOrders;i++){
				var order = orderdata[i];
				(function (order){
					var product_url = order.products.resource.url;
					seoshopWidget.freshdeskWidget.request({
						method: "get",
						entity_name: "request",
						rest_url: product_url+".json",
						body:"",
						on_success: function(evt){
							ordersProcessed++;
							var product_data = evt.responseJSON.orderProducts,
								line_items = [],
								order_date = new Date(order.createdAt)
								view_order = null;

							for(var j=0; j<product_data.length; j++) {
								var product = product_data[j];
								line_items.push({ id:product.id,
											      title:product.productTitle,
												  quantityOrdered:product.quantityOrdered,
												  priceExcl:product.priceIncl});
							}

							
							view_order = {
								name: order.id,
								customer: order.firstname+" "+ order.lastname,
								customer_id:order.customer.resource.id,
								date: order_date.toDateString()+
											' at '+
											order_date.toLocaleTimeString('IST', {hour: '2-digit', minute:'2-digit'}) ,
								financial_status: order.paymentStatus,
								amount: order.priceIncl,
								status:order.shipmentStatus,
								paymentStatus:order.paymentStatus,
								line_items:line_items,
								shipping_address1: order.addressShippingStreet,
								shipping_address2 :order.addressShippingNumber, 
								shipping_city:order.addressShippingCity,
								created_at: order_date
							}

							orders.push(view_order);

							if(ordersProcessed == totalOrders ) { 
								sorted_orders = orders.sort(function(obj1, obj2) {
           							 return obj2.created_at - obj1.created_at;
        						});
								seoshopWidget.renderOrders(sorted_orders);
							}

						}.bind(this),
						on_failure: function(evt){ ordersProcessed++ ; seoshopWidget.handlefailure(evt)} 
					});
				})(order);
			} //forloop
		} else {
			jQuery("#seoshop .content").html(seoshopWidget.SEOSHOP_NO_CONTACT.evaluate({}));
		}
	},

	renderOrders:function(orders)
	{
		var order_tag = "";
		for(var i=0; i<orders.length;i++)
		{
			var order_details = orders[i]
			var line_details = order_details.line_items;
			if(line_details.length > 0)
			{
				var line_items_html = "";
				for (var j=0; j<line_details.length; j++){		
					line_items_html += "<div class='row-fluid product'> "+ 
										"<div class='span8'>" + line_details[j].title +" </div>" +
										"<div class='span4 align-right'>" + line_details[j].priceExcl+"</div>" +
										"</div>"
				}
			}
			
			var product_list_id = "product-list-id-"+order_details.name;

			order_tag += "<div class='order-wrapper'>"+
						  "<div class='order-status'>"+
							 "<div class='label label-light'>"+order_details.status.humanize().capitalize()+"</div>"+
						 	 "<div class='label label-light pull-right'>"+order_details.paymentStatus.humanize().capitalize()+"</div>"+
						  "</div>"+

			"<div class='row-fluid order-details' id=order_details_"+order_details.name+">"+
				"<div class='span8'>" +
			    	"<a href='#' class='order-id-link' data-show='#"+product_list_id+"'>"+ '#'+order_details.name+"</a>"+
					"<span class='info-data'>(" + order_details.line_items.length + " items)</span>"+
					"<div class='date info-data'>on: "+ order_details.date+"</div>"+
				"</div>" +
				"<div class='span4 align-right amount'>"+ order_details.amount+"</div>" +
			"</div>" + 
			"<div class='product-list hide' id='"+product_list_id+"'>" +
				line_items_html +
				"<div class='row-fluid shipping-address'>"+
					"<div class='span4'>Shipping:</div>"+
					"<div class='span8 word-wrap'>"+ 
						"<div>"+order_details.shipping_address1+"</div>"+
						"<div>"+order_details.shipping_address2+"</div>"+
						"<div>"+order_details.shipping_city+"</div>"+
					"</div>"+
				"</div>"+
			"</div>"+
		"</div>"
		
		}

		jQuery("#seoshop .content").html(order_tag);

		jQuery('.order-id-link').click(function(ev){  
			ev.preventDefault();
			jQuery('#seoshop .product-list').hide(); 
			jQuery(jQuery(this).data("show")).show(); 
		});
	},

	handlefailure: function(evt) {
		var errorMessage = "Seoshop reports the error - :<br>" + evt.responseJSON.error.message +"<br>"
		errorMessage += "Check whether appropriate store api key,secret and language is configured. Contact support for assistance."
		jQuery("#seoshop_loading").remove();
		jQuery("#seoshop .error").append(errorMessage);
	}

}  
seoshopWidget = new SEOshopWidget(seoshopBundle);
