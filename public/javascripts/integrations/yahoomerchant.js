var YahooMerchantWidget = Class.create();

YahooMerchantWidget.prototype = {

initialize:function(custom_options){
    
    custom_options.app_name = "YahooMerchant";
    custom_options.widget_name = "sample_highrise_widget";
    custom_options.domain = "https://yhst-139815752962527.order.store.yahooapis.com";   
    order_req = this.getorderresponse();
    custom_options.init_requests = [order_req];
	this.freshdeskWidget = new Freshdesk.Widget(custom_options, this);
  },


getorderresponse:function(){
	var postData='<?xml version="1.0" encoding="utf-8"?><ystorewsRequest><StoreID>yhst-139815752962527</StoreID><SecurityHeader><PartnerStoreContractToken>1.0_v3uBOels_wHT_At5uaYaA5sSX_DHBAC0R65twX6PnFsrTCErIhLsYiyEUC518iLBYUHuPUWXcH74ZyNklclfYSws_x2GAvqxOPNHy6tn5isKd4g2QZOAdCNHlxv7c5qjR_Lo4tt1aw--</PartnerStoreContractToken></SecurityHeader><Version> 1.0 </Version><Verb> get </Verb><ResourceList><OrderListQuery><Filter><Include> all </Include></Filter><QueryParams><OrderID> 485 </OrderID></QueryParams></OrderListQuery></ResourceList></ystorewsRequest>';
	req_obj = { 
		body: postData,
		rest_url:"/V1/order",
		content_type: "application/xml",
		method: "post", 
		on_success: this.loadOrdersList.bind(this),
		on_failure: function(evt){}
	};
    return req_obj;

},


loadOrdersList: function(resData) {
	console.log("loadOrdersList");
	resXml = resData.responseXML;
	order_list = XmlUtil.extractEntities(resXml, "OrderList");
	console.log ("orderlist "+ order_list);
	this.orderData = this.parseOrders(order_list);
	this.renderOrderWidget(this.orderData[0]);
	},

parseOrders: function(order_list)
{
	console.log("parseOrders");
	orderData = [];
	if(order_list.length > 0)
	{
		for (var i = 0; i < order_list.length; i++) 
		{
			var order_id = XmlUtil.getNodeValueStr(order_list[i], "OrderID");
			var status_id = XmlUtil.getNodeValueStr(order_list[i], "StatusID");
			var item_id = XmlUtil.getNodeValueStr(order_list[i], "ItemID");
			var tracking_id=XmlUtil.getNodeValueStr(order_list[i],"TrackingNumber");
			var item_url=XmlUtil.getNodeValueStr(order_list[i],"URL");
			var shipper_name = XmlUtil.getNodeValueStr(order_list[i],"Shipper");
			var shipper_state = XmlUtil.getNodeValueStr(order_list[i],"ShipState");
			var shipper_method=XmlUtil.getNodeValueStr(order_list[i],"ShipMethod");
			var shipment_details = XmlUtil.getNodeValueStr(order_list[i],"GeneralInfo");

			console.log("order no " + order_id);
			console.log("status_id " + status_id);
			console.log("Item id" + item_id);
			console.log("shipper state " + shipper_state);
			console.log("shipper_method " + shipper_method);
			console.log("shipper_method " + shipment_details);

			this.order_id = order_id;
			orderData.push({
				"OrderId":order_id,"StatusId":status_id,"ItemId":item_id,"TrackingId":tracking_id,"Item_url":item_url,"Shipper_name":shipper_name,"Shipper_state":shipper_state,"Shipper_method":shipper_method
			});
			
		}
	}
	return orderData;
},

loadOrderDetails:function()
{
	console.log("loadOrderDetails");
	
},

renderOrderWidget:function(orderData){
  	console.log("renderOrderWidget");
 	cw = this;   
    this.freshdeskWidget.options.application_html = function(){return _.template(cw.VIEW_ORDERS,orderData); } 
    this.freshdeskWidget.display();
     jQuery("#"+this.freshdeskWidget.options.widget_name+" .contact-type").show();

    
  },


  

	VIEW_ORDERS:
	'<div class="title"> <div id="widgetname"> <b> FreshProducts </b></div>' + 
    '<div> <div id="orderid"><a href="#" class="ticket_order_id" rel="freshdialog" data-target="#<%=OrderId%>" data-width="400px" data-height="600" data-template-footer="false">Order ID : <%=OrderId%></a></div>'+
    '<div class="ticket_info_yahoo" id="<%=OrderId%>">' + 
	    '<div class="title"> <div id="widgetname"> <b> FreshProducts </b></div>' + 
	    '<div class="title"> <div id="itemid">Order ID : <%=OrderId%></div>'+
	    '<div class="title"> <div id="itemid"><a href="<%=Item_url%>" target="_blank">Item Name : <%=ItemId%></a></div>'+
	    '<div class="title"> <div id="statusid">Status : <%=StatusId%></a></div>'+
	    '<div class="title"> <div id="trackingid">Tracking ID: 1001</a></div>'+
	    //'<div class="title"> <div id="trackingid">Shipment Name : <%=Shipper_name%></div>'+
	    //'<div class="title"> <div id="trackingid">Shipment State : <%=Shipper_state%></div>'+
	    '<div class="title"> <div id="trackingid">Name : Roshini Philip</div>'+
	    '<div class="title"> <div id="trackingid">Email : roshiniphilip@gmail.com</div>'+
	    '<div class="title"> <div id="trackingid">Shipment Method : <%=Shipper_method%></div>'+
	    '<div class="title"> <div id="trackingid">Shipment Address : 129, OakLand Avenue, NY United States 10989</div>'+
	    
	'</div>',


}

yahooMerchantWidget = new YahooMerchantWidget({});