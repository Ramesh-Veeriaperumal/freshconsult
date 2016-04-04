var FreshbooksInvoiceWidget = Class.create();
FreshbooksInvoiceWidget.prototype = {

	INVOICE_LIST_REQ:new Template('<?xml version="1.0" encoding="utf-8"?><request method="invoice.list"> <client_id>#{client_id}</client_id><page>#{page}</page><per_page>#{per_page}</per_page> </request>'),

	INVOICE_SEARCH_RESULTS:
	'<div class="title <%=widget_name%>_bg">' +
	'<div id="number-returned"><b> <%=resLength%> results for <%=requester%> </b></div>'+
	'<div id="search-results"><ul id="contacts-search-results"><%=resultsData%></ul></div>'+
	'</div>',

	INVOICE_DETAILS:
	'<div class="title <%=widget_name%>_bg">' +
	'<div class="row-fluid">' +
	'<div id="client-name" class="span8 <%=(count>1 ? "": "hide")%>">'+
	'<a title="<%=name%>" target="_blank" href="<%=url%>" class="client-title"><%=name%></a></div>' +
	'</div></div>'+
	'<div class="invoice_list"><%= invoice_information%></div>'+
	'<div class="field bottom_div"></div>'+
	'<div class="external_link"><a id="search-back" href="#" class="search-back <%=(count>1 ? "": "hide")%>">&laquo; Back</a></div>',

	INVOICE_INFO:
	'<ul id="invoicelist" class="integ_invoices">'+
	'<%for(var i=0;i<invoices.length;i++){%>'+
	'<li id="invoice<%=invoices[i].number%>" class="integ_invoice_each">'+
	'<a href rel="freshdialog" class="invoice_item invoice_number" data-target="#invoice_details<%=invoices[i].number%>" data-template-footer="">Invoice&nbsp;<%=invoices[i].number%></a>'+
	'<%=invoices[i].invoice_details_template%><span class="invoice-status pull-right"><%=invoices[i].status%></span>'+
	'<div class="mt4"><span class="invoice_data_text">Created on:</span>&nbsp;<%=invoices[i].date%></div>'+
	'<div class="mt4"><span class="invoice_data_text">Amount:</span>'+
	'&nbsp;<%=invoices[i].total%>&nbsp;<%=invoices[i].curr_code%>&#44;&nbsp;'+
	'<span class="invoice_data_text">Amount Due:</span>&nbsp;<%=invoices[i].balance%>&nbsp;<%=invoices[i].curr_code%>'+
	'</div></li>'+
	'<%}%>'+
	'</ul>',

	INVOICE_INFO_NON_COM:
	'<ul id="invoicelist" class="integ_invoices">'+
	'<%for(var i=0;i<invoices.length;i++){%>'+
	'<li id="invoice<%=invoices[i].number%>" class="integ_invoice_each">'+
	'<a href rel="freshdialog" class="invoice_item invoice_number" data-target="#invoice_details<%=invoices[i].number%>" data-template-footer="">Invoice&nbsp;<%=invoices[i].number%></a>'+
	'<%=invoices[i].invoice_details_template%><span class="invoice-status pull-right"><%=invoices[i].status%></span>'+
	'<div class="mt4"><span class="invoice_data_text">Created on:</span>&nbsp;<%=invoices[i].date%></div>'+
	'</li>'+
	'<%}%>'+
	'</ul>',

	INVOICE_LINE_ITEM:
	'<tr>'+
	'<td><%=lineItem.name%></td>'+
	'<td class="break-all"><%=lineItem.description%></td>'+
	'<td><%=lineItem.rate%></td>'+
	'<td><%=lineItem.quantity%></td>'+
	'<td><%=lineItem.amount%></td>'+
	'</tr>',

	INVOICE_LINE_ITEM_NON_COM:
	'<tr>'+
	'<td><%=lineItem.name%></td>'+
	'<td class="break-all"><%=lineItem.description%></td>'+
	'<td><%=lineItem.quantity%></td>'+
	'</tr>',

	INVOICE_VIEW:
	'<div id="invoice_details<%=invoice.number%>" class="hide integ_invoices">'+
	'<div class="integ_invoice_modal"><span class="integ_invoice_header">Invoice&nbsp;<%=invoice.number%></span>'+
	'<span class="pull-right"><a target="_blank" href="<%=invoice.reference%>">View in Freshbooks</a></span>'+
	'<%if(invoice.po_number != ""){%>'+
	'<div class="mt4"><span class="invoice_data_text">PO Number:</span>&nbsp;<%=invoice.po_number%></div>'+
	'<%}%>'+
	'<div class="mt4"><span class="invoice_data_text">Created on:</span>&nbsp;<%=invoice.date%></div>'+
	'<div class="mt4"><span class="invoice_data_text">Amount:</span>'+
	'&nbsp;<%=invoice.total%>&nbsp;<%=invoice.curr_code%>&#44;&nbsp;'+
	'<span class="invoice_data_text">Amount Due:</span>&nbsp;<%=invoice.balance%>&nbsp;<%=invoice.curr_code%>'+
	'<span class="invoice-status pull-right"><%=invoice.status%></span>'+
	'</div></div>'+
	'<table class="table">'+
    '<%=invoiceWidgetInst.showInvoiceDetails(invoice.lineItems)%>'+
	'<tr class="integ_invoice_total_row"><td colspan="3"></td><td>Amount</td><td><%=invoice.total%></td></tr>'+
	'</table>'+
	'</div>',

	INVOICE_VIEW_NON_COM:
	'<div id="invoice_details<%=invoice.number%>" class="hide integ_invoices">'+
	'<div class="integ_invoice_modal"><span class="integ_invoice_header">Invoice&nbsp;<%=invoice.number%></span>'+
	'<span class="pull-right"><a target="_blank" href="<%=invoice.reference%>">View in Freshbooks</a></span>'+
	'<%if(invoice.po_number != ""){%>'+
	'<div class="mt4"><span class="invoice_data_text">PO Number:</span>&nbsp;<%=invoice.po_number%></div>'+
	'<%}%>'+
	'<div class="mt4"><span class="invoice_data_text">Created on:</span>&nbsp;<%=invoice.date%>'+
	'<span class="invoice-status pull-right"><%=invoice.status%></span>'+
	'</div>'+
	'</div>'+
	'<table class="table">'+
	'<%=invoiceWidgetInst.showInvoiceDetails(invoice.lineItems)%>'+
	'</table>'+
	'</div>',

	initialize:function(freshbooksBundle){
		var $this = this;
		var freshbooksUtility = Freshdesk.NativeIntegration.freshbooksUtility;
		freshbooksBundle.freshbooksNote = jQuery('#freshbooks-note').html();
		freshbooksBundle.widgetname="freshbooks_side_bar_widget";
		$this.invoices={};
		$this.invoice_type=parseInt(freshbooksBundle.invoice_type);
		
	    if(typeof(freshbooksUtility) != 'undefined'){
            freshbooksUtility.handleRequest(function(){$this.loadInvoiceDetails($this)},"freshbooks_side_bar_widget");
		}
		else{
			freshbooksBundle.call_back=function(){$this.loadInvoiceDetails($this)};
			Freshdesk.NativeIntegration.freshbooksUtility = new FreshbooksUtility(freshbooksBundle);
		}
	},

	loadInvoiceDetails:function($this){
		var $this = $this;
		var freshbooksUtility = Freshdesk.NativeIntegration.freshbooksUtility;
	    result=freshbooksUtility.results;
		$this.results=result;
		freshbooksUtility.freshdeskWidget.options.widget_name="freshbooks_side_bar_widget";
		if(result instanceof Array && freshbooksUtility.client_filter != ""){
			var counter=0;
			var clientObj={};
			clientObj.page=1;
			clientObj.per_page=5;
			var invoice_list;
			for(var i=0;i<result.length;i++){
				clientObj.client_id=XmlUtil.getNodeValue(result[i],"client_id");
				freshbooksUtility.freshdeskWidget.request({
					body: $this.INVOICE_LIST_REQ.evaluate(clientObj),
					content_type: "application/xml",
					method: "post",
					on_success: function(resData){
						counter++;
						invoice_list=jQuery.merge([],XmlUtil.extractEntities(resData.responseXML,"invoice"));
						if(invoice_list.length > 0){
							$this.invoices[XmlUtil.getNodeValue(invoice_list[0],"client_id")]=invoice_list;
						}
						if(counter==result.length){
							$this.renderMultipleClients(result);
						}
					}
				});
			}
		}
		else if(result == "" || result == undefined){
			$this.renderInvoiceNa();
		}
		else{
			var clientObj={};
			var invoice_list;
			clientObj.page=1;
			clientObj.per_page=5;
			clientObj.client_id=XmlUtil.getNodeValue(result,"client_id");
			freshbooksUtility.freshdeskWidget.request({
				body: $this.INVOICE_LIST_REQ.evaluate(clientObj),
				content_type: "application/xml",
				method: "post",
				on_success: function(resData){
					invoice_list=jQuery.merge([],XmlUtil.extractEntities(resData.responseXML,"invoice"));
					$this.displayInvoice(result,invoice_list);
				}
			});
		}
	},

	renderInvoices:function(result){
		var $this = this;
		var invoice_list=$this.invoices[XmlUtil.getNodeValue(result,"client_id")];
		$this.displayInvoice(result,invoice_list);
	},


	renderInvoiceNa:function(){
	jQuery("#freshbooks_loading").removeClass("sloading loading-block loading-small");
    jQuery("#freshbooks_side_bar_widget .content").html("<div class='integ_empty_invoices' align='center'>cannot find "+freshbooksBundle.reqName+" in freshbooks</div>");
	},


	displayInvoice:function(result,invoices){
		var $this = this;
		var invoice_items=[];
		var invoice_template;
		var reqParams={};
		reqParams.name=XmlUtil.getNodeValue(result,"organization");
		reqParams.url=XmlUtil.getNodeValue(result,"auth_url");
		reqParams.count=$this.results.length;
		reqParams.widget_name="freshbooks";
		if(invoices == undefined || invoices.length == 0){
			invoice_template= "<div class='details integ_empty_invoices' align='center'>No Invoices</div>";
		}
		else{
			for(var i=0;i<invoices.length;i++){
				var invoice={};
				invoice.number=XmlUtil.getNodeValue(invoices[i],"number");
				invoice.reference=XmlUtil.getNodeValue(invoices[i],"auth_url");
				invoice.status=XmlUtil.getNodeValue(invoices[i],"status");
				invoice.date=XmlUtil.getNodeValue(invoices[i],"date").split(" ")[0];
				invoice.balance=XmlUtil.getNodeValue(invoices[i],"amount_outstanding");
				invoice.total=XmlUtil.getNodeValue(invoices[i],"amount");
				invoice.po_number=XmlUtil.getNodeValue(invoices[i],"po_number");
				invoice.curr_code=XmlUtil.getNodeValue(invoices[i],"currency_code");
				invoice.discount=parseInt(XmlUtil.getNodeValue(invoices[i],"discount"));
				var lineItems=XmlUtil.extractEntities(invoices[i],"line");
				var lineItemsList=[];
				for(var k=0;k<lineItems.length;k++){
					if(parseInt(XmlUtil.getNodeValue(lineItems[k],"amount")) == 0){
						continue;
					}
					else{
						var lineItemObj={};
						lineItemObj.name=XmlUtil.getNodeValue(lineItems[k],"name");
						lineItemObj.description=XmlUtil.getNodeValue(lineItems[k],"description");
						lineItemObj.rate=XmlUtil.getNodeValue(lineItems[k],"unit_cost");
						lineItemObj.quantity=XmlUtil.getNodeValue(lineItems[k],"quantity");
						lineItemObj.amount=XmlUtil.getNodeValue(lineItems[k],"amount");
						lineItemObj.type=XmlUtil.getNodeValue(lineItems[k],"type");
						lineItemsList.push(lineItemObj);
					}
				}
				invoice.lineItems=lineItemsList;
				var invoice_details=($this.invoice_type == 1)?(_.template($this.INVOICE_VIEW,{invoice:invoice, invoiceWidgetInst: $this})):(_.template($this.INVOICE_VIEW_NON_COM,{invoice:invoice, invoiceWidgetInst: $this}));
				invoice.invoice_details_template=invoice_details;
				invoice_items.push(invoice);
			}

			invoice_list_element=($this.invoice_type == 1)?(_.template($this.INVOICE_INFO,{invoices:invoice_items})):(_.template($this.INVOICE_INFO_NON_COM,{invoices:invoice_items}));
			invoice_template=invoice_list_element;
		}
		reqParams.invoice_information=invoice_template;
		jQuery("#freshbooks_loading").removeClass("sloading loading-block loading-small");
		jQuery("#freshbooks_side_bar_widget .content").html(_.template($this.INVOICE_DETAILS,reqParams));
		jQuery("#freshbooks_side_bar_widget .content").on('click','#search-back', (function(ev){
			ev.preventDefault();
			$this.renderMultipleClients($this.results);
		}));
	},

	showInvoiceDetails:function(lineItems){
		var $this = this;
	    var taskEntries="";
	    var itemEntries="";
	    var taskFound=true;
	    var itemFound=true;
	    if($this.invoice_type == 1){
           taskHeader="<tr class='integ_invoice_details_header'><th>Task</th><th>Time Entry Notes</th><th>Rate</th><th>Hours</th><th>Line Total</th></tr>";
           itemHeader="<tr class='integ_invoice_details_header'><th>Item</th><th>Description</th><th>Unit cost</th><th>Quantity</th><th>Line Total</th></tr>";
           lineItemTemplate=$this.INVOICE_LINE_ITEM;
	    }
	    else{
	    	taskHeader="<tr class='integ_invoice_details_header'><th>Task</th><th>Time Entry Notes</th><th>Hours</th></tr>";
	    	itemHeader="<tr class='integ_invoice_details_header'><th>Item</th><th>Description</th><th>Quantity</th></tr>";
	    	lineItemTemplate=$this.INVOICE_LINE_ITEM_NON_COM;
	    }
	    for(var k=0;k<lineItems.length;k++){
	       if(lineItems[k].type == "Time"){
	           if(taskFound){
	              taskEntries+=taskHeader;
	              taskFound=false;
	            }
	          taskEntries+=_.template(lineItemTemplate,{lineItem:lineItems[k]});
	        }
	        else{
	            if(itemFound){
	               itemEntries+=itemHeader;
	               itemFound=false;
	            }
	          itemEntries+=_.template(lineItemTemplate,{lineItem:lineItems[k]});
	        }
	    }
	    return (taskEntries+itemEntries);
	},

	renderMultipleClients:function(clients){
		var $this = this;
		var freshbooksUtility = Freshdesk.NativeIntegration.freshbooksUtility;
		var searchResults="";
		var requester_info=(freshbooksUtility.client_filter=="email")?(freshbooksBundle.reqEmail):(freshbooksBundle.reqCompany);
		for(var i=0;i<clients.length;i++){
			var client_name=XmlUtil.getNodeValue(clients[i],"organization");
			searchResults += '<li><a class="multiple-contacts" href="#" data-client="' + i + '">'+client_name+'</a></li>';
		}
		var results_number = {resLength: clients.length, requester: requester_info, resultsData: searchResults,widget_name:"freshbooks"};
		jQuery("#freshbooks_loading").removeClass("sloading loading-block loading-small");
		jQuery('#freshbooks_side_bar_widget .content').html(_.template($this.INVOICE_SEARCH_RESULTS,results_number));
		jQuery('#freshbooks_side_bar_widget .content').off('click').on('click','.multiple-contacts', (function(ev){
			ev.preventDefault();
			$this.renderInvoices(clients[jQuery(this).data('client')]);
		}));
	}

}

