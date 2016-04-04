var xerOWidget = Class.create();

xerOWidget.prototype = {
XERO_FORM_INVOICES:new Template(

'<div id="xero_invoice" title="xero_invoice">'+
    '<div class="row-fluid" id="xero_invoice_link">' +
	'</div>' +
	'<div id ="xero_dialog_create" class="xero_modal" > </div>'+
'</div>'   	  
),	
XERO_FORM_NO_INVOICE:new Template(
	'<div id="no_invoice">'+
		'<div class="row-fluid">' +
			'<label class="control-label">Contact not available or No invoices generated for this contact in Xero </label>'+
		'</div>'+
	'</div>'
),

XERO_FORM_NO_LINE_ITEMS:new Template(

	'<div id="inv_status">'+
	'<div class="row-fluid">' +
		'<label class="control-label">This Invoice cannot be viewed because Line item Description, Quantity or Unit price may not  be available' + 		
		'</label>'+
	'</div>'+
	'</div>'

),		

XERO_CREATE_INVOICE: new Template (
	
		'<div class="alert-text" id="error_display"></div>'+
			'<div class="form-horizontal " >'+
	  		'<div rel="construct_rules" id="construct_rules" class="rules_wrapper" data-render-template=".construct_company_rule"></div>' + 
			'<fieldset class="xero_footer">' +			
				'<div class="last inl thirty-percent">'+	
					'<span class="xero-hash-mandatory-footer">†</span>'+								
					'<select  name="account_id"  width ="200px"  class="account_id">'+
					'</select> <div class="loading-fb" id="workflow-max-tasks-spinner" ></div>'+
				'</div>'+
				'<div class="inl mar-s thirty-percent">'+
					'<span class="required_star">*</span>'+				
					'<select name="currency_id"  width ="200px" placeholder="Select currency" class="currency_id">'+
					'</select> <div class="loading-fb" id="workflow-max-tasks-spinner" ></div>'+
				'</div>' +
			'</fieldset>'+
		'</div>' 
	
),
initialize : function(xeroBundle){
	xerOWidget= this;
	widgetInst = this;
	this.btn = true;
	var rule_temp = this.constructRuleTemplate();
	jQuery('#xero').append(rule_temp);

	this.freshdeskWidget = new Freshdesk.Widget({
		app_name: "xero",
		integratable_type:"issue-tracking",
		application_id: xeroBundle.application_id,
		local_integratable_id: xeroBundle.ticket_id
	});	
	widgetInst.fetch_records(xeroBundle);
	jQuery('.add_new_list').hide();
}, 
constructRuleTemplate: function(){
	return 	'<script class="construct_company_rule" type="text/html" data-default-value=""> '+
			'<input type="text" rel="input_text" data-refer-key="Desc" data-header-label="Description" />' + 
			'<input type="text" rel="input_text" data-refer-key="Quant" data-header-label="Quantity (HH:MM)" readonly="readonly"/>' + 
			'<input type="hidden" rel="hidden_text" data-refer-key="Amount" data-header-label="" />' + 
			'</script>' ;			
},
createInvoices:function(divId)
{	
	var current_date = new Date().toString("yyyy-MM-ddThh:mm:ss")
	jQuery('#add_invoice').addClass('disabled');
	jQuery('.xero_li_hover').addClass('disabled');
	var xero_line_items_html = "<LineItems>"
	var account_id = jQuery("#"+ divId +" .account_id option:selected").val();
	var currency_id = jQuery("#"+ divId +" .currency_id").val();
	var contact_name = "";
	var postData = "";
	var description = "";
	var account_code ="";
	var unit_amount = 1;
	
	if (divId == 'xero_dialog_create') 
	{
		account_id = jQuery("#"+ divId +" #account_id").val();
		currency_id = jQuery("#"+ divId +" #currency_id").val();
	}
	new Ajax.Request("/integrations/xero/fetch_create_contacts",{
		asynchronous: true,
		method: "get",
		dataType: "json",
		parameters: xeroBundle,
		onSuccess: function(resData){
			contact_id = resData.responseText;
			var line_items = {};			
			var i=0;
			jQuery('#' + divId +' .rules_list_wrapper').children().not('.overlay').each(function(){ 
				description = jQuery(this).find('.input_text_1').val();
				time_spent = jQuery(this).find('.input_text_2').val();
				unit_amount = jQuery(this).find('.hidden_text_1').val();				
				time = time_spent.split(':');
				times = parseInt( time[0]) + ( Math.round( time[1] *(5/3)) * .01 )
				if(unit_amount == "0"){
				  unit_amount = "1.0";
				}
				line_items[i] ={"description":description, "unit_amount":unit_amount, "account_code":account_id , "time_spent": times} 
				if(xeroBundle.items_code){
					item_code = jQuery(this).find('.items_dropdown option:selected').val();	
					line_items[i]["item_code"] = item_code;
				}
				i++;
			});
			if (divId == 'xero_dialog_create')
			{
				postData ={"contact_email": xeroBundle.reqEmail, "contact_id": contact_id, "current_date": current_date, "currency_id": currency_id, "unit_amount":unit_amount, "line_items": JSON.stringify(line_items)};	
			}
			else
			{
				invoiceId = divId.replace('dialog_','');
				postData ={"invoice_id":invoiceId, "current_date": current_date, "currency_id": currency_id, "line_items": JSON.stringify(line_items) }; 
			}
			new Ajax.Request("/integrations/xero/create_invoices",{
				asynchronous: true,
				method: "post",				
				dataType: "application/xml",
				parameters: postData,
				onSuccess: function(evt){				
				if(evt.responseText != "A validation exception has occured")
				{		
					var response =JSON.parse(evt.responseText);
					var invoiceID = response.invoice_details["invoice_id"];
					xeroBundle.invoice_name = response.invoice_details["invoice_number"];
					jQuery("#"+ divId).modal('hide');		
					jQuery('#' + divId  + '-submit').removeClass('disabled');							
					widgetInst.createIntegratedResource(invoiceID);									
				}
				else
				{						
					jQuery('#' + divId  + '-submit').removeClass('disabled');		
					jQuery('#add_invoice').removeClass('disabled');	
					jQuery('.xero_li_hover').removeClass('disabled')								
					jQuery("#" + divId + " #error_display").html("<p>Error in creating/editing Invoice. Verify all the details and try again.</p>");
				}				
			}
			});			
		},
		onFailure: function(evt){
			jQuery('#' + divId  + '-submit').removeClass('disabled');		
			jQuery('#add_invoice').removeClass('disabled');	
			jQuery('.xero_li_hover').removeClass('disabled');	
			jQuery("#" + divId + " #error_display").html("<p>Error in creating/editing Invoice. Verify all the details and try again.</p>");				
		}
});
},
createIntegratedResource: function(invoice_id){
	this.freshdeskWidget.remote_integratable_id = invoice_id;
	this.freshdeskWidget.local_integratable_id = xeroBundle.ticket_id;
	this.freshdeskWidget.create_integrated_resource( widgetInst.callbackForCreate);
},
callbackForCreate: function(evt){
	if( evt.status == 200 ){
		jQuery("#xero_loading").remove();				
		jQuery('#noticeajax').html( "Linked Xero Invoice #" + xeroBundle.invoice_name).show();
		closeableFlash('#noticeajax')
		window.scrollTo(0,0);
		jQuery('#xero_invoice_link').html(" ");
		jQuery('#xero  .content').html('<div id="xero_loading" class="sloading loading-block loading-small"></div>')
		jQuery('#add_invoice').removeClass('disabled');	
		jQuery('.xero_li_hover').removeClass('disabled');
		widgetInst.fetch_records(xeroBundle);	
    }
},
fetch_records: function(xeroBundle){
	if ( !xeroBundle.reqEmail ) {
		var a_tag = "<p class='disc xero_ul_sidebar' id='xero_no_contact'> Email address not available for this requester. A valid Email is required to fetch the invoices from xero. </p>"
		jQuery('#xero .content').html(xerOWidget.XERO_FORM_INVOICES.evaluate({}));
		jQuery('#xero_invoice_link').html(a_tag);
	}
	else{
	new Ajax.Request("/integrations/xero/fetch", {
			asynchronous: true,
			method: "get",
			dataType: "json",
			parameters: xeroBundle,
			onSuccess: widgetInst.load_invoices,
			onFailure: function(arr){				
				var a_tag = "<p class='disc xero_ul_sidebar' id ='er_val'> A problem has occured. Try again. If the problem persist contact support.</p>"
				jQuery('#xero .content').html(xerOWidget.XERO_FORM_INVOICES.evaluate({}));
				jQuery('#xero_invoice_link').html(a_tag);
			}
  });
}	
},
load_invoices: function(arr){
		jQuery("#xero_loading").remove();
		var response = JSON.parse(arr.responseText);
		xeroBundle.remote_integratable_id = response.remote_id["remote_integratable_id"];
		xeroBundle.integrated_resource_id = response.remote_id["integrated_resource_id"];
		xeroBundle.ticket_description = response.ticket_description;		
		obj = response.inv_items;
			if(obj.length > 0){				
				invoiceData =[];
				for(var i=obj.length-1; i>=0; i--){	
					inv = JSON.parse(obj[i]);	
					invoice_number = inv.invoice_number.escapeHTML();
					invoice_id = inv.invoice_id;
					invoice_status = inv.status;
					currency_code = inv.currency_code;
					date = inv.date;
					due_date = inv.due_date;
					if( xeroBundle.remote_integratable_id == invoice_number ){
						invoiceData.unshift({"ID":invoice_id,"InvoiceNumber":invoice_number,"InvoiceStatus":invoice_status,"CurrencyCode": currency_code, "DueDate": due_date, "Date" : date})
					}
					else{
					invoiceData.push({"ID":invoice_id,"InvoiceNumber":invoice_number,"InvoiceStatus":invoice_status,"CurrencyCode": currency_code, "DueDate": due_date, "Date" : date})
					}
				}
				jQuery('#xero .content').html(xerOWidget.XERO_FORM_INVOICES.evaluate({}));
				var a_tag="";
				var delete_tag =""
				a_tag="<label>Associated Invoices</label><ul class='disc xero_ul_sidebar xero_scroll'>";	
				jQuery.each(invoiceData,function(i,val) {
					var invText =val["InvoiceNumber"];
					var DueDate = "";
					if(val["InvoiceNumber"].length > 10){
						invText = val["InvoiceNumber"].slice(0, 10) + "..";
					}
					if(val["DueDate"] != null){
						DueDate = "<span class='invoice_status date-item clear'> Due Date: " +val["DueDate"]+"</span><div class='xero_modal' id='dialog_"+val["ID"]+"'></div> </li>";
					}
					if(xeroBundle.remote_integratable_id == val["ID"] ){
						a_tag="<label>Associated Invoices</label><ul class='disc xero_ul_sidebar xero_scroll'>";							
						// logic changed to check for deleted invoice only in xero and provide unlink button to them. If Invoice is draft or some other status we are not providing delete link.
						if(val["InvoiceStatus"] == "DELETED"){
							a_tag = a_tag + "<li class='each_invoice clearfix cur_ticket_deleted clear'><a id='"+val["ID"] +"' href='https://go.xero.com/AccountsReceivable/Edit.aspx?InvoiceID="+val["ID"]+"' class='pull-left' title='Invoice deleted in xero.' target='_blank'"+"><i class='ficon-ticket'></i>"+invText+"</a><span class='label label-light invoice_status pull-right'>" + val["InvoiceStatus"]+"</span>";
							a_tag += "<a id='delete_invoice' class='remove_requester_button_xero xero_li_hover_delete inl' data-width='700' title='" + val["InvoiceNumber"] +"'  data-target='"+ jQuery('.cur_ticket a').first().attr('id') + "' data-submit-label='Delete' data-close-label='Cancel' data-submit-loading='Deleting Invoice...' data-loading-text='unlinking..'>unlink</a> "
						}
						else{
							a_tag = a_tag + "<li class='each_invoice clearfix cur_ticket clear'><a id='"+val["ID"] +"' href='https://go.xero.com/AccountsReceivable/Edit.aspx?InvoiceID="+val["ID"]+"' class='pull-left' title='"+ val["InvoiceNumber"]+" Current Ticket Invoice' target='_blank'"+"><i class='ficon-ticket'></i>"+invText+"</a><span class='label label-light invoice_status pull-right'>" + val["InvoiceStatus"]+"</span>";
							a_tag += "<a class='xero_li_hover pull-right' data-target='#dialog_"+ val["ID"] +"' data-width='700' title='Edit Invoice'  data-submit-label='Update' data-close-label='Cancel' data-submit-loading='Updating Invoice...' id='xero_invoice_update' rel='freshdialog'  > View </a>";
						}						
						a_tag +=DueDate;						
						return false;
					}
					else{
					if(val["InvoiceStatus"] == "DRAFT"){	
						a_tag += "<li class='each_invoice clearfix clear'><a id='"+val["ID"] +"' href='https://go.xero.com/AccountsReceivable/Edit.aspx?InvoiceID="+val["ID"]+"' target='_blank'"+"  class='pull-left' title='"+ val["InvoiceNumber"]+"'>"+invText+"</a><span class='label label-light invoice_status pull-right'>" + val["InvoiceStatus"]+"</span>";
						a_tag += "<a class='xero_li_hover pull-right' data-target='#dialog_"+ val["ID"] +"' data-width='700' title='Edit Invoice'  data-submit-label='Update' data-close-label='Cancel' data-submit-loading='Updating Invoice...' id='xero_invoice_update' rel='freshdialog'  > Edit </a>";
						a_tag +=DueDate;
						}
					}
				});
				if(a_tag == "<label>Associated Invoices</label><ul class='disc xero_ul_sidebar xero_scroll'>")
				{
				var a_tag = "<p class='disc xero_ul_sidebar' id ='no_draft'> No invoices for this Contact.</p>";							
				jQuery('#xero_invoice_link').html(a_tag);
				jQuery("#no_draft").css("padding-top", "10px");
				}
				else{
				a_tag=a_tag + "</ul>";
				jQuery('#xero_invoice_link').html(a_tag);
				}
			}
			else{
				jQuery('#xero .content').html(xerOWidget.XERO_FORM_NO_INVOICE.evaluate({}));
			}
			var timeError ="";
			if(xeroBundle.ticket_timesheet.length == 0){ 
				timeError = "no timesheets";
			}
			else{
				timesheets = xeroBundle.ticket_timesheet;
				for(var i=0; i < timesheets.length; i++){
					if(timesheets[i].time_entry.billable == false){
						timeError = "no billable";
					}
					else{
						timeError = "";
						break;
					}					
				}
				for(var i=0; i < timesheets.length; i++){
					if(timesheets[i].time_entry.timer_running == true){
						timeError = "timer_running";
						break;
					}
				}
			}
			if(timeError == "no timesheets"){ 
				jQuery('.xero_li_hover').remove();
				jQuery("<p class='inl errormsg' rel='freshdialog' data-width='700'>No time sheets for this ticket..</p>").insertBefore(jQuery('#xero .content > div:nth-child(1)'));
			}
			else if(timeError == "no billable"){
				jQuery('.xero_li_hover').remove();
				jQuery("<p class='inl errormsg' rel='freshdialog' data-width='700'>No Billable time sheets for this ticket..</p>").insertBefore(jQuery('#xero .content > div:nth-child(1)'));
			}
			else if(timeError == "timer_running"){
				jQuery('.xero_li_hover').remove();
				jQuery("<p class='inl errormsg' rel='freshdialog' data-width='700'>Stop the timer for all time sheets first..</p>").insertBefore(jQuery('#xero .content > div:nth-child(1)'));
			}	
			else{	
				if(!xeroBundle.remote_integratable_id)
				{
				jQuery("<a href='#' id='add_invoice' rel='freshdialog' class='add_requester_button_xero inl btn btn-flat' data-target='#xero_dialog_create' data-width='700' title='Create Invoice'  data-submit-label='Create' data-close-label='Cancel' data-submit-loading='Creating Invoice...' data-loading-text='saving..'>Create Invoice </a> ").insertBefore(jQuery('#xero .content > div:nth-child(1)'));
				}	
				else{			
					if(delete_tag != ""){		
				 		jQuery(delete_tag).insertBefore(jQuery('#xero .content > div:nth-child(1)'));	
					}
				}			
			}
	jQuery("#xero_loading").remove();

	jQuery(document).on('click', '.add_requester_button_xero, .remove_requester_button_xero, .xero_ul_sidebar .xero_li_hover', function(e){	
		if(e.handled !== true) {
		if(this.id == 'add_invoice')
		{				
			jQuery("#xero_dialog_create").children('.modal-body').html(xerOWidget.XERO_CREATE_INVOICE.evaluate({}));
			jQuery("#xero_dialog_create .xero_footer .required_star").hide();
			jQuery("#xero_dialog_create .xero_footer .xero-hash-mandatory-footer").hide();
			jQuery("#xero_dialog_create").children(".modal-body").prepend("<p class ='sloading loading-block loading-small' style='width:100%; text-align:center;'></p>");
			jQuery("#xero_dialog_create .account_id").attr('id','account_id');
			jQuery("#xero_dialog_create .currency_id").attr('id','currency_id');
			widgetInst.render_lineitems(this.id, "xero_dialog_create");
			widgetInst.render_accounts(this.id, "xero_dialog_create");
			widgetInst.render_currency(this.id, "xero_dialog_create", "");
			jQuery('#xero_dialog_create').addClass('xeroFormBlock');			
		}
		else if(this.id == 'delete_invoice'){
			var delID = jQuery('.cur_ticket_deleted #delete_invoice').attr('title'); 		
			if (confirm("Clicking OK will unlink this Invoice: #" + delID) == true) {
				var delID = jQuery('.cur_ticket_deleted #delete_invoice').attr('title'); 
				jQuery("#delete_invoice").attr('data-target', delID).addClass('disabled');
				jQuery("#delete_invoice").attr('data-target', delID).text('unlinking....');
				xeroBundle.invoice_name = delID; 
 				widgetInst.deleteIntegratedResource( xeroBundle.integrated_resource_id );				
			}
		}
		else
		{			
			var divID = jQuery(this).attr('data-target');
			if(xeroBundle.remote_integratable_id){
				jQuery(divID + '-submit').remove();
				jQuery('.list').addClass('overlay');
			}
			var xeroID = divID.split('#dialog_').last()
			jQuery(divID).children('.modal-body').html(xerOWidget.XERO_CREATE_INVOICE.evaluate({}));
			jQuery(divID + ' .required_star').remove();
			jQuery(divID +" .xero_footer .xero-hash-mandatory-footer").hide();
			if(xeroBundle.remote_integratable_id){
				jQuery(divID + "-submit").hide();
			}
			jQuery(divID).children(".modal-body").prepend("<p class ='sloading loading-block loading-small' style='width:100%; text-align:center;'></p>");

			accountId = "acc_"+divID;
			currencyId = "curr_"+divID
			jQuery(divID + ' .account_id').attr('id',accountId);
			jQuery(divID + ' .currency_id').attr('id',currencyId);
			widgetInst.render_lineitems(xeroID,divID.split('#').last());
			jQuery(divID).addClass('xeroFormBlock');
		}
		e.handled = true;
	}
	});		

	jQuery(document).on('mouseenter','.each_invoice',function(event){
		var target =jQuery( event.target );
		if( jQuery( event.target ).is( "li" ) )
	    {
	        target.children('.xero_li_hover').show();
	        target.children('.xero_li_hover_delete').css("display","inline");
	    }else{
	    	target.siblings('.xero_li_hover').show();
	    	target.children('.xero_li_hover_delete').css("display","inline");
	    }
		
	});
	jQuery(document).on('mouseleave','.each_invoice',function(event){
		var target =jQuery( event.target );
		if( jQuery( event.target ).is( "li" ) )
	    {
	        target.children('.xero_li_hover').hide();
	        target.children('.xero_li_hover_delete').hide();
	    }else{
	    	target.siblings('.xero_li_hover').hide();
	    	target.children('.xero_li_hover_delete').hide();
	    }
	});

},
deleteIntegratedResource: function(integrated_resource_id){
	this.freshdeskWidget.remote_integratable_id = xeroBundle.remote_integratable_id;
	this.freshdeskWidget.local_integratable_id = xeroBundle.ticket_id;
	this.freshdeskWidget.delete_integrated_resource(integrated_resource_id, widgetInst.callbackForDelete);
},
callbackForDelete: function(){
	jQuery('#xero  .content').html('<div id="xero_loading" class="sloading loading-block loading-small"></div>')			
	widgetInst.fetch_records(xeroBundle);		
	jQuery('#noticeajax').html("<p>Unlinked Xero Invoice #"+ xeroBundle.invoice_name  +".</p>").show();
	closeableFlash('#noticeajax');
	window.scrollTo(0,0);
},
render_lineitems: function(id,divID)
{			
	if(id == 'add_invoice')
	{
	new Ajax.Request("/integrations/xero/check_item_exists",{
	asynchronous: true,
	method: "get",
	dataType: "json",
	parameters: { "ID": "xero_dialog_create"},
	onSuccess: function(reqData){
		var inventory_items = reqData.responseJSON;
		time_sheets = xeroBundle.ticket_timesheet;
		var array =[];
		if(time_sheets.length > 0)
		{	
			jQuery('.sloading.loading-block.loading-small').remove();
			for (var i =0; i<time_sheets.length; i++)
			{
				line_items = time_sheets[i]			
				if(line_items.time_entry.billable == true)
				{
					var items;
					Desc = xeroBundle.ticket_description;
					if(Desc == ""){
						Desc = "Freshdesk ticket " + xeroBundle.ticket_id;
					}
					var totalTime =line_items.time_entry.timespent * 60;
					var hours = parseInt(totalTime/60);
					var mins = "" + Math.round(totalTime % 60);
					if( mins.length ==1) {
						mins = "0" + mins;
					}
					Quant = hours + ":" + mins;
					Amount = 0.0;
					items = {"Desc": Desc.escapeHTML(), "Quant": Quant, "Amount": Amount};
					array.push(items);			
				}
			}
			jQuery('script.construct_company_rule').data('defaultValue', array);
			jQuery('#construct_rules').data('disableField','');
			jQuery('#'+ divID + ' #construct_rules').constructRules();
			jQuery('.add_new_list').hide();
			jQuery('.rules_list_wrapper .input_text_2').attr('readonly', true);
			if(jQuery("#xero_dialog_create .bind-remove-icon").length == 1){
			  jQuery("#xero_dialog_create .bind-remove-icon").addClass('disabled');
			}
			if(inventory_items.items_code.length != 0){
				widgetInst.create_dropdown_items(inventory_items, "xero_dialog_create");
			}					
		}
		 jQuery("#xero_dialog_create .bind-remove-icon").bind("click",function(e){
			if(jQuery("#xero_dialog_create .bind-remove-icon").length == 1){
				jQuery("#xero_dialog_create .bind-remove-icon").addClass('disabled');
			}
		});
	},
	onFailure: function(reqData){		
		jQuery("#" + divID + " #error_display").html("<p>A problem has occured. Try again. If the problem persist contact support.</p>");	

	}
});
	}
	else
	{
		widgetInst.edit_invoice(id,divID)

	}

},
edit_invoice :function(invoiceid,divID)
{
	liData=[]
	invoice_details="";
	var inValidLineItem = false;
	new Ajax.Request("/integrations/xero/get_invoice",{
		asynchronous: true,
		method: "get",
		dataType: "application/xml",
		parameters:{"invoiceID" :invoiceid},
		onSuccess: function(reqData){
			response = reqData.responseJSON;
			invoice_details  = JSON.parse(response.invoice);
			invoice_line_items = invoice_details.line_items;
			var item_description = response.item_description;			
			for(var i=0;i<invoice_line_items.length;i++) 
			{				
				li_desc =  invoice_line_items[i].description; 
				li_amt =  invoice_line_items[i].line_amount; 
				quant = invoice_line_items[i].quantity; 				
				var li_quant = "0:00";
				var amount_chk  = parseInt(li_amt);
				if (isNaN(amount_chk)) {
					amount_chk = 0;
				}
				if(quant != null && amount_chk != 0 && li_desc != null){					
						var totalTime =quant * 60;
						var hours = parseInt(totalTime/60);
						var mins = "" + Math.round( totalTime%60 );
						if( mins.length ==1) {
							mins = "0" + mins;
						}
						li_quant = hours + ":" + mins;					
					if(li_desc == null){
						li_desc = "";
					}
						liData.push({"Desc":li_desc.escapeHTML(),"Amount":li_amt, "Quant":li_quant});
					}
				else{
					jQuery("#" + divID).children('.modal-body').html("");
					jQuery("#" + divID).children('.modal-body').html(xerOWidget.XERO_FORM_NO_LINE_ITEMS.evaluate({}));
					inValidLineItem = true;
					jQuery('#' + divID + '-submit').hide();
					break;
				}
			}
				if(inValidLineItem == false){
				if(!xeroBundle.remote_integratable_id){
					jQuery('#' + divID + '-submit').show();
				}		
				liData = {"LiData": liData}			
				currency_code =  invoice_details.currency_code;
				invoice_number = invoice_details.invoice_number;				
			   if(xeroBundle.remote_integratable_id ){	
			   	jQuery('#'+divID  + ' .account_id').parent().children('.loading-fb').hide();			   
			   	jQuery('#'+ divID +' .account_id').remove();			   	
			   }
			   else{
			   	 widgetInst.render_accounts('',divID.split('#').last());
			   }
			   widgetInst.render_currency(this.id,divID.split('#').last(), currency_code);
			   widgetInst.render_lineitems_for_edit(liData["LiData"], divID, invoice_number, item_description);
			}
		},
		onFailure: function(reqData){
			jQuery("#" + divID + " #error_display").html("<p>A problem has occured while rendering the Invoice. Try again. If the problem persist contact support.</p>");
		}
	});

},
create_dropdown_items :function(inventory_items, divID){
				xeroBundle.items_code = inventory_items.items_code;
				var dropdown = '<div class="list-data">'+
							'<select class="items_dropdown">' +
							'<option value=""><option>';
				for(var i=0; i< inventory_items.description.length; i++){
					dropdown += '<option value="' + inventory_items.items_code[i] + '">' + inventory_items.description[i] + '</option>' ;
					}
				dropdown += '</select></div>';
				

				jQuery('#' + divID+ ' .rules_list_wrapper .list').not('.overlay').find('.list-data:nth-child(1)').each(function(){
					jQuery(dropdown).insertAfter(this);
					});
				if(jQuery("#" + divID + " .items_dropdown.select2-container").length == 0 ){
					jQuery("#"+ divID +" .items_dropdown").select2({
					  placeholder: "Items",
					  allowClear: true
					});
				}
				jQuery('#'+ divID + ' select.items_dropdown option:nth-child(2)').remove();
				var items_title= '<div class="list-data"><p class="header-txt">Inventory Items <span class="xero-hash-mandatory">†</span></p></div>';
				jQuery(items_title).insertAfter('#'+ divID +' .rules_wrapper .tabel-thead .list .list-data:nth-child(1)');
				jQuery("#" + divID + " .xero_footer .xero-hash-mandatory-footer").show();
				jQuery('<p class="xero-hash-mandatory" style="font-style: italic;">† Any of the two attributes is mandatory to create an invoice.</p>').insertAfter('#' + divID +' .xero_footer');
				jQuery('#' + divID+' .rules_wrapper .input_text_1').attr("style", "width: 220px !important");
				jQuery('#' + divID+' .rules_wrapper .input_text_2').attr("style", "width: 95px !important");
},
render_lineitems_for_edit: function(liData, divID, invNum, item_description)
{
	new Ajax.Request("/integrations/xero/check_item_exists",{
	asynchronous: true,
	method: "get",
	dataType: "json",
	parameters: { "ID": divID},
	onSuccess: function(reqData){
		var inventory_items = reqData.responseJSON;
		jQuery('#' + divID +" #xero_loading").remove();
		var array = [];
		var array2 =[];				
		var s = ''; 
		if(liData.length > 0){
			for (var i =0; i<liData.length; i++)
			{
				line_items = liData[i];
				s += line_items.Desc;
				if(i!= liData.length - 1){
					s += ',';
				}
				array.push(line_items);
			}
		}	
		jQuery('#'+ divID + ' #construct_rules').data('disableField', s ); 
		if(!xeroBundle.remote_integratable_id){	
			timeEntry = xeroBundle.ticket_timesheet;
			if(timeEntry.length > 0)
			{
				for (var i =0; i<timeEntry.length; i++)
				{
					line_items = timeEntry[i];			
					if(line_items.time_entry.billable == true)
					{
						var items;
						Desc = xeroBundle.ticket_description; 
						if(Desc == ""){
						Desc = "Freshdesk ticket " + xeroBundle.ticket_id;
						}
						var totalTime =line_items.time_entry.timespent * 60;
						var hours = parseInt(totalTime/60);
						var mins = "" + Math.round(totalTime % 60);
						if( mins.length ==1) {
							mins = "0" + mins;
						}
						Quant = hours + ":" + mins;
						Amount = 0.0;
						items = {"Desc": Desc.escapeHTML(), "Quant": Quant, "Amount": Amount};
						array2.push(items);
						
					}
				}													
			}
			}
			jQuery("#"+ divID +" .currency_id").attr('disabled', true);
			array = array.concat(array2);
		jQuery('script.construct_company_rule').data('defaultValue', array);
		jQuery('.sloading.loading-block.loading-small').remove();	
		jQuery('#'+ divID + ' #construct_rules').constructRules();
		jQuery('.add_new_list').hide();
		jQuery('.rules_list_wrapper .input_text_2').attr('readonly', true);
		jQuery('#' + divID +' .rules_list_wrapper').children().slice(0,liData.length).addClass('overlay');
		jQuery('#' + divID +' .rules_list_wrapper').children().slice(0,liData.length).find('.bind-remove-icon').addClass('disabled');
		jQuery('#' + divID +' .rules_list_wrapper').children().slice(0,liData.length).find('.input_text_1').attr('readonly', true);
		if(!xeroBundle.remote_integratable_id && invNum != xeroBundle.remote_integratable_id){
		jQuery('#' + divID +' .rules_list_wrapper').children().slice( -array2.length ).each(function(){ jQuery(this).removeClass('overlay')});
		jQuery('#' + divID +' .rules_list_wrapper').children().slice( -array2.length ).find(".remove_list").addClass("bind-remove-icon");
		jQuery('#' + divID +' .rules_list_wrapper').children().slice( -array2.length).find('.input_text_1').attr('disabled', false);
		if(jQuery("#"+ divID +" .bind-remove-icon").slice( -array2.length).length == 1){
			  jQuery("#"+ divID +" .bind-remove-icon").addClass('disabled');
			}
		jQuery(".bind-remove-icon").bind("click",function(){
		jQuery(this).parents(".list").remove();
		});			
		if(inventory_items.items_code.length != 0){
				widgetInst.create_dropdown_items(inventory_items, divID);				
				var loop = 0;
				jQuery("#" + divID+ " .rules_list_wrapper .list.overlay .list-data:nth-child(1)").each(
				function(){
					val = item_description[loop];			
					loop++;
					jQuery("<div class='list-data'><input type='text' class='input_text_items' value='"+ val + "' disabled></div>").insertAfter(this)
				});				
			}
		jQuery('#' + divID +' .input_text_1').slice( -array2.length ).removeAttr('disabled');
		jQuery("#"+ divID +" .bind-remove-icon").bind("click",function(e){
			if(jQuery("#"+ divID +" .bind-remove-icon").not('.disabled').length == 1){
				jQuery("#"+ divID +" .bind-remove-icon").addClass('disabled');
			}
		});
		}
		else{
			jQuery("#"+ divID +" .account_id").attr('disabled', true);
			if(inventory_items.items_code.length != 0){
			var i=0;
			jQuery('#' + divID + ' .rules_list_wrapper .overlay').find('.list-data:nth-child(1)').each(function(){
				val = item_description[i];
				jQuery("<div class='list-data'><input type='text' class='input_text_items' value='"+ val + "' disabled></div>").insertAfter(this);
				i++;
			});
			jQuery('#' + divID+' .rules_wrapper .input_text_1').attr("style", "width: 220px !important");
			jQuery('#' + divID+' .rules_wrapper .input_text_2').attr("style", "width: 95px !important");
			var items_title= '<div class="list-data"> <p class="header-txt">Inventory Items</p></div>';
			jQuery(items_title).insertAfter('#'+ divID +' .rules_wrapper .tabel-thead .list .list-data:nth-child(1)');
			}
		}
	},
	onFailure: function(reqData){
		jQuery("#" + divID + " #error_display").html("<p>A problem has occured while rendering the lineItems. Try again. If the problem persist contact support.</p>");
	}
	});
},
render_accounts: function(id,divID)
{
	accountData=[];
	new Ajax.Request("/integrations/xero/render_accounts",{
		asynchronous: true,
		method: "get",
		dataType: "json",		
		onSuccess: function(reqData){
			account_list = reqData.responseJSON;
			for(var i=0;i<account_list.code.length;i++) 
			{
			account_code = account_list.code[i];
			account_name = account_list.name[i];
			accountData.push({"ID":account_code,"Name":account_name});
			}
			accountData = {"Account": accountData}
			widgetInst.loadAccountsComboBox(accountData,divID,id);
		},
		onFailure: function(reqData){
			jQuery("#" + divID + " #error_display").html("<p>A problem has occured while rendering Accounts. Try again. If the problem persist contact support.</p>");	

		}
	}
		);
},
loadAccountsComboBox: function(accountData,divID,id)
{	
	a = accountData;
	var acc_id = 'acc_#'+divID
	
	if (id == 'add_invoice') {
	 	acc_id = "account_id" 
	 }
	UIUtil.constructDropDown(accountData, 'hash', acc_id, "Account", "ID",  ["Name"], null, null, false);	
	jQuery('#'+divID  + ' .account_id').parent().children('.loading-fb').hide();
	// jQuery("#" + divID + " .xero_footer .xero-hash-mandatory-footer").show();
	// jQuery('<p class="xero-hash-mandatory" style="font-style: italic;">† Any of the two attributes is mandatory to create an invoice.</p>').insertAfter('#' + divID +' .xero_footer');
	jQuery('#'+divID  + ' .account_id').show();
	jQuery('#'+divID + ' .account_id').prepend('<option selected></option>');
	jQuery('#'+divID + ' .account_id').select2({ placeholder : 'Select Account', allowClear: true });				
},
render_currency: function(id, divID, currency_code)
{
	currencyData=[];
	new Ajax.Request("/integrations/xero/render_currency",{
		asynchronous: true,
		method: "get",
		dataType: "json",
		parameters: { "code": currency_code},
		onSuccess: function(evt){
			currency_list =JSON.parse(evt.responseText);
			for(var i=0;i<currency_list.length;i++) 
			{	currency = JSON.parse(currency_list[i])
				currency_code = currency.code;
				currency_name = currency.description;
				currencyData.push({"ID":currency_code,"Name":currency_name});
			}
			currencyData = {"Currency": currencyData}
			widgetInst.loadCurrencyComboBox(currencyData,id,divID)
		},
		onFailure: function(evt){
			jQuery("#" + divID + " #error_display").html("<p>A problem has occured while rendering currency. Try again. If the problem persist contact support.</p>");			}
	});

},
loadCurrencyComboBox: function(currencyData,id,divID)
{	

	var curr_id = 'curr_#'+divID
	if (id == 'add_invoice') {
	 	curr_id = "currency_id"; 
	 }	
	UIUtil.constructDropDown(currencyData, 'hash', curr_id, "Currency", "ID",  ["Name"], null, null, false);
	jQuery('#' + divID + ' .currency_id').parent().children('.loading-fb').hide();
	jQuery('#' + divID + ' .currency_id').show();	
	if(id == 'add_invoice')
	{
		jQuery('#' + divID  + ' .currency_id').prepend('<option selected></option>');	
		jQuery('#' + divID  + ' .currency_id').select2({placeholder : 'Select Currency', allowClear: true });
		jQuery("#xero_dialog_create .xero_footer .required_star").show();
	}
	else
	{
		jQuery('#'+divID + ' .currency_id option[text=' + id +']').attr("selected","selected") ;
		var val = jQuery('#'+divID + ' .currency_id').text();
		jQuery('#'+divID + ' .currency_id').replaceWith('<input type="text" class="currency_id" value="'+ val +'" disabled>');
	}
	
},
}

xeroWidget = new xerOWidget(xeroBundle);

jQuery('#xero-createinvoice-form').livequery(function(){
})

jQuery('body').on('click', '.xeroFormBlock [data-submit="modal"]', function(e) { 
	e.preventDefault();
	if(e.handled !==  true){
	div_id = jQuery(this).attr('id')	
	jQuery('#' + div_id ).addClass('disabled');
	div_id = div_id.replace('-submit','');
	var errortext = "";
	jQuery("#" + div_id + " #error_display").empty();					
	var bool = false, items_desc = true;		
	if(div_id == "xero_dialog_create"){	
		if(jQuery('#xero_dialog_create .rules_list_wrapper').children().length == 0){
			errortext = "<p>Invoice should contain atleast one LineItem.</p>"
		}						
		
		jQuery('#xero_dialog_create .rules_list_wrapper').children().not('.overlay').each(function(){ 
			if(jQuery(this).find('.input_text_1').val() == ""){
				bool = true;
			}
			if(jQuery(this).find('.input_text_2').val() == ""){
				bool = true;
			}
			if(xeroBundle.items_code){
				if(!jQuery(this).find('.items_dropdown option:selected').val()){
					items_desc = false;
				}
			}
			else{
				items_desc = false;
			}
		});

		if(items_desc == false && jQuery("#"+ div_id + " #account_id option:selected").text() == ""){
			errortext = "<p>Select either an item or an account type to create an Invoice</p>";
		}
		if(jQuery("#currency_id option:selected").text() == ""){
			errortext = "<p>Select a Currency type for creating an Invoice</p>";
		}
		if(jQuery('#xero_dialog_create .rules_list_wrapper .list').length == 0){
			errortext = "<p> Invoice should contain atleast one LineItem"
		}
		
	}
	else{
		jQuery('#'+ div_id + ' .rules_list_wrapper').children().not('.overlay').each(function(){ 
			if(jQuery(this).find('.input_text_1').val() == ""){
				bool = true;
			}
			if(jQuery(this).find('.input_text_2').val() == ""){
				bool = true;
			}
			if(xeroBundle.items_code){
				if(!jQuery(this).find('.items_dropdown option:selected').val()){
					items_desc = false;
				}
			}
			else{
				items_desc = false;
			}
		});		
		if(items_desc == false && jQuery("#"+ div_id +" .account_id option:selected").text() == ""){
			errortext = "<p>Select either a Item or an Account type to Edit current Invoice</p>";
		}
		if(jQuery('#'+ div_id + ' .rules_list_wrapper').children().not('.overlay').length==0){
			errortext = "<p>Please Wait till all columns gets loaded!</p>";
		}
		if(jQuery('#' + div_id +' .rules_list_wrapper .list').not('.overlay').length == 0){
			errortext = "<p> Invoice should contain atleast one LineItem</p>"
		}
	}
	if(bool == true){
		errortext = "<p>Provide value for lineitem description</p>"
	}	
	if(errortext.length>0){
		jQuery("#" + div_id + " #error_display").html(errortext);	
		jQuery('#' + div_id  + '-submit').removeClass('disabled');
	}
	else
	{	
		jQuery("#" + div_id + " #error_display").empty();					
		widgetInst.createInvoices(div_id);
	}	
		e.handled = true;
	}
});

