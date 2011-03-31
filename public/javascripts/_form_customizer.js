/**
 * @author venom
 */ 
 
(function($){
	jQuery(document).ready(function(){
		init();
		makePageNonSelectable($('custom_form'));
	});
			
	function init(){		
		var fieldFeed = JSON.parse(document.getElementById('field_values').value, 
							function (key, value) {
							    var type;
								if(key == 'action'){
									value = "";														
								} 	
								return value;
							});
		
		var DialogFieldPref = null;
		var SourceField 	= null;
		var sourceDomMap	= null;
		var dialogContainer = "div#CustomFieldsDialog";
		
		// Mapping individual dom elements to its data counterparts
		var dialogDOMMap = {
			type: 			jQuery(dialogContainer+' input[name|="customtype"]'),
			label: 			jQuery(dialogContainer+' input[name|="customlabel"]'), 
            description: 	jQuery(dialogContainer+' input[name|="customdesc"]'),	
			choices: 		jQuery(dialogContainer+' div[name|="customchoices"]'),
            setDefault: 	1,	    
		    agent: 	  {required: jQuery(dialogContainer+' input[name|="agentrequired"]')},
			customer: {visible : jQuery(dialogContainer+' input[name|="customervisible"]'),
					   editable: jQuery(dialogContainer+' input[name|="customereditable"]'),
					   required: jQuery(dialogContainer+' input[name|="customerrequired"]')}
		};
		
        var fieldTemplate = $H({
					            type: "",
					            label: "Untitled",
								display_name:"Untitled",
						    	description: "",
						   		fieldType :"custom",
					            choices: [],
					            setDefault: 0,
					            agent: {required: false},
						    	customer: {visible: false, editable: false, required: false},
						    	columnId: "",
								styleClass:	"",
								action: "create" // delete || edit || create
					        });

		function getAjaxField(type){
			jQuery.ajax({
	      					type: 'POST',
							url: '/ticket_fields/get_column',
							contentType: 'application/json',
							data:JSON.stringify({type: type}),
							datatype:'json',
	      					success: function(data){											
											getFreshField(type, data)
									}
				});
		}
	
		function getFreshField(type){
	        var freshField = fieldTemplate.toObject();
		    freshField.type = type;	
	            	switch (type) {
	                	case 'dropdown': 
	                	    freshField.choices = [{value: "First Choice", tag: []}, {value: "Second Choice",tag: []}];
	                	break;
	            	}
			return freshField;
        }
		
		function getCustomFieldJson(){
			var allfields = $A();
			jQuery("#custom_form li").each(function(index, domLi){				
				allfields.push(jQuery(domLi).data("raw"));
			})
			return allfields;
		}
		
        
        function constFieldDOM(dataItem, container){
			var fieldContainer = container || jQuery("<li />");
			fieldContainer.empty();
			
			var label = jQuery("<label />").append(dataItem.display_name);
			var field = jQuery("<div />");
			var panel = jQuery("<div class='action_panel' />");	
			/*var edit  = jQuery("<a href='javascript:void(0)' class='button'>Edit</a>");
			var del   = jQuery("<a href='javascript:void(0)' class='button'>Delete</a>")
								.bind("click", function(){
									deleteField(fieldContainer);
								});
		
			//panel.append(edit);
			//if (dataItem.fieldType != 'default'){
				//panel.append(del);
			//}*/
			
			fieldContainer.append(panel);
			
			var fieldAttr = '';
            switch (dataItem.type) {
                case 'number':
                case 'text':
		    		fieldContainer.addClass(dataItem.type);
                    field.append('<input type="text" '+fieldAttr+' disabled="true" size="80" />');
					fieldContainer.append(label)
						  .append(field);
                    break;
                    
                case 'checkbox':				
					fieldContainer.addClass(dataItem.type);	
					var selected = (dataItem.setDefault)?'checked':'';
                    field.append('<input type="checkbox" '+ selected +' disabled="true" '+fieldAttr+' />'+dataItem.display_name);
					fieldContainer
						  .append(field);
                    break;
                    
                case 'dropdown':
					fieldContainer.addClass(dataItem.type);
                    jQuery(dataItem.choices).each(function(ci, choice){
                        var defChoice = (ci == dataItem.setDefault) ? 'selected="selected"' : '';
                        field.append("<option " + defChoice + ">" + choice.value + "</option>");
                    });
                    field.wrapInner("<select "+fieldAttr+" disabled='true' />");
					fieldContainer.append(label)
						  .append(field);
                    break;
                    
                case 'paragraph':
					fieldContainer.addClass(dataItem.type);
                    field.append('<textarea disabled="true"'+fieldAttr+'></textarea>');
					fieldContainer.append(label)
						  .append(field);
                    break;
            }            
            
			fieldContainer.data("raw", dataItem); 
			return fieldContainer;
        }
		 
        
        function feedJsonForm(formInput){
            jQuery(formInput).each(function(index, dataItem){				
				var dom = constFieldDOM(dataItem);				
				jQuery("#custom_form").append(dom);				
            });
        }
        
        feedJsonForm(fieldFeed);
        
        jQuery("#custom_fields li").draggable({
            connectToSortable: "#custom_form",
            helper: "clone",
			stack:  "#custom_fields li",
            revert: "invalid"
        });
        
        jQuery("#custom_form")
			.sortable({
		            revert: true,
					stop: function(ev, ui) { 
						type = ui.item.get(0).getAttribute('type');
		                if (type) {
							constFieldDOM(getFreshField(type), ui.item);
							ui.item.trigger("click");
		                }					
		            }
			    })
			.droppable();
			
		if ($.browser.msie) {
			jQuery(".ui-custom-form li").hover(function(){
				jQuery(this).addClass("hover");
			}, function(){
				jQuery(this).removeClass("hover");
			});
		}
        	
    jQuery("#close_button").click(function(e){
         	jQuery("#CustomFieldsDialog").hide();
    });
		
	jQuery("#SaveForm").click(function(e){			
			var jsonData = getCustomFieldJson();
			jQuery("#field_values").val(jsonData.toJSON()); 
			//alert(jQuery("#field_values").val());
			//return false;
			 
			/*jQuery.ajax({
      					type: 'POST',
						url: '/ticket_fields/update',
						contentType: 'application/json',
						data:JSON.stringify({jsonData: jsonData}),
						datatype:'json',
						success: function(data){						
							jQuery("#field_values").val(data.data);
							jQuery("#custom_form").empty();
							init();
							jQuery('div#resultmsg').html(data.message);
							jQuery('div#resultmsg').show("fade", 500);
						}
    	  	});  */ 
			
		});
		
        
		function innerLevelExpand(checkbox){ 
            jQuery("#"+checkbox.getAttribute("toggle_ele")).toggle(checkbox.checked);
		}
        
        jQuery("#nestedConfig")
			.find("input:checkbox")
			.bind("change", function(e){
							            innerLevelExpand(this);
							      }); 
		
		
		function addChoiceinDialog(data, dom){
			dom 	= dom || dialogDOMMap.choices;
			data 	= data || {value:'', tags:''};
			dom.append('<fieldset><span class="dropchoice"><input type="text" value="'+data.value+'" /></span><span class="tags"><input type="text" value="'+data.tags+'" /></span><img class="deleteChoice" src="/images/delete.png" /></fieldset>')
		}
		
		jQuery(".deleteChoice").live('click', function(){
											jQuery(this).parent().remove();
									  }); 
									  
		jQuery(".addchoice").live('click', function(){
											addChoiceinDialog();
									  }); 
		
		function getAllChoices(dom){
			var choices = $A();
			dom.find('fieldset').each(function(choiceset){
				var temp = {value:'', tags:''};
				temp.value  = jQuery(this).find("span.dropchoice input").val();
				temp.tags   = jQuery(this).find("span.tags input").val();	
				choices.push(temp);	 	
			});			
			return choices;
		}
		
		function DialogOnLoad(sourceField){ 
			// Dialog Population Method
			jQuery(SourceField).removeClass("active");
			SourceField  = sourceField;
			sourceDomMap = { "label" : jQuery(sourceField).find("label") }; 
			jQuery(sourceField).addClass("active");
			
			var sourceData = jQuery(sourceField).data("raw");
			 
				
			dialogDOMMap.type.val(sourceData.type);							
			dialogDOMMap.label.val(sourceData.display_name);
			dialogDOMMap.description.val(sourceData.description);
				
			jQuery("div#CustomFieldsDialog label.overlabel").overlabel();
				
			dialogDOMMap.choices.empty();
			sourceData.choices.each(function(item){
				addChoiceinDialog(item, dialogDOMMap.choices);						
			});
				
			dialogDOMMap.agent.required.attr("checked", sourceData.agent.required);								
			dialogDOMMap.customer.visible.attr("checked", sourceData.customer.visible);
				innerLevelExpand(dialogDOMMap.customer.visible.get(0));
			
			dialogDOMMap.customer.editable.attr("checked", sourceData.customer.editable);
				innerLevelExpand(dialogDOMMap.customer.editable.get(0)); 
			
			dialogDOMMap.customer.required.attr("checked", sourceData.customer.required);  
				
			jQuery("#DropFieldChoices").hide();
			
			if(sourceData.fieldType == 'default'){
				dialogDOMMap.label.attr("disabled", true);
				dialogDOMMap.label.addClass("disabled");
				jQuery('#DeleteField').hide();								
			}else{
				jQuery('#DeleteField').show();
				dialogDOMMap.label.attr("disabled", false);
				dialogDOMMap.label.removeClass("disabled");
						
				 if (sourceData.type == 'dropdown') {	                
	               	jQuery("#DropFieldChoices").show();	                
	             }		 
			}
			
           
		}      
        
		jQuery("#SaveField").click(function()
		{
			var sourceData   	         	= $H(jQuery(SourceField).data("raw"));	
			
			sourceData.set("label" 		 		 , dialogDOMMap.label.val());
			sourceData.set("display_name" 		 , dialogDOMMap.label.val());
			sourceData.set("description" 		 , dialogDOMMap.description.val());
			
			sourceData.get("agent").required	= dialogDOMMap.agent.required.attr("checked");
				
			sourceData.get("customer").visible	= dialogDOMMap.customer.visible.attr("checked");										
			sourceData.get("customer").editable = dialogDOMMap.customer.editable.attr("checked");
			sourceData.get("customer").required = dialogDOMMap.customer.required.attr("checked");  											
				
			sourceData.set("choices", getAllChoices(dialogDOMMap.choices));									
			
			sourceData.set('action', "edit");			
			
			constFieldDOM(sourceData.toObject(), jQuery(SourceField));
		});
		
		jQuery("#close_button").click(function(){
			DialogFieldPref.dialog("close");	
		});
		
		var deleteField = function(sourcefield){
			var sourceData    = jQuery(sourcefield).data("raw").action = "delete";
			jQuery(sourcefield).hide();			
		};
		
		jQuery("#DeleteField").live("click", function(e){
			deleteField(SourceField);
		});
		
		jQuery(dialogDOMMap.label).live("keyup", function(ev){
			sourceDomMap.label.text(this.value);
		});
		
        jQuery("#custom_form li").live("click", function(e){           
			DialogOnLoad(this);
			
            jQuery("#CustomFieldsDialog")
							             /*.position({
							             of: jQuery( this ),
							             my: 'left' + " " + 'center',
							             at: 'left' + " " + 'top',
							             offset: '250px -30px',
							             collision: "fit fit"
							             })*/										 								 
										 .show("highlight", 5000, function(){
										 	jQuery(this).clearQueue();											
										 })
            /*DialogFieldPref = jQuery("#CustomFieldsDialog").dialog({
					                closeOnEscape: true,
					                width: "550px",
					                position: ['center', 50],
									resizable:false,				
					                //modal: true,
					                dialogClass: '.dialog_ticket_field',
					                show: 'clip' 
					            });*/
        });
		
        
		  
    };
})(jQuery);

	