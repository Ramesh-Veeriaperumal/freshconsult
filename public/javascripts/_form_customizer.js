/**
 * @author venom
 */ 

 
(function($){
	ticket_fields_modified = false;
	
	jQuery(document).ready(function(){
		init();
		//makePageNonSelectable($('custom_form'));
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
		var dialogHidden	= true;
		var dialogContainer = "div#CustomFieldsDialog";
		
		// Mapping individual dom elements to its data counterparts
		var dialogDOMMap = {
			type: 			jQuery(dialogContainer+' input[name|="customtype"]'),
			label: 			jQuery(dialogContainer+' input[name|="customlabel"]'), 
            description: 	jQuery(dialogContainer+' input[name|="customdesc"]'),	
			choices: 		jQuery(dialogContainer+' div[name|="customchoices"]'),
            setDefault: 	1,	    
		    agent: 	  {required: jQuery(dialogContainer+' input[name|="agentrequired"]'),
					   closure:  jQuery(dialogContainer+' input[name|="agentclosure"]') },
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
					fieldContainer.addClass("checkbox");	
					var selected = (dataItem.setDefault)?'checked':'';
                    field.append('<input type="checkbox" '+ selected +' disabled="true" '+ fieldAttr +' />' + dataItem.display_name );
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
			
			$(field).prepend("<span class='overlay-field' />");
			 
			if (dataItem.action) { 
				ticket_fields_modified = true;
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
							showFieldDialog(constFieldDOM(getFreshField(type), ui.item)); 
		                }					
						ticket_fields_modified = true;
		            }
			    })
			.droppable();
			
		jQuery(".customchoices").sortable({
			items: 'fieldset'	,
			handle: ".sort_handle",
			stop: function(ev){
				saveAllChoices();
			}
		});
			
		if ($.browser.msie) {
			jQuery(".ui-custom-form li").hover(function(){
				jQuery(this).addClass("hover");
			}, function(){
				jQuery(this).removeClass("hover");
			});
		}
        	
    jQuery("#close_button, #close_button_2").click(function(e){
         	hideDialog();
    });
		
	jQuery("#SaveForm").click(function(e){			
			var jsonData = getCustomFieldJson();
			jQuery("#field_values").val(jsonData.toJSON()); 
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
			dom.append('<fieldset><span class="sort_handle"></span><span class="dropchoice"><input type="text" value="'+data.value+'" name="choice" /></span><span class="tags"><input type="text" value="'+data.tags+'" /></span><img class="deleteChoice" src="/images/delete.png" /></fieldset>')
		}
		
		jQuery(".deleteChoice").live('click', 
									  function(){
									  		if (jQuery(this).parent().siblings().size() != 0) {
												jQuery(this).parent().remove();
												saveAllChoices();
											}
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
				if(jQuery.trim(temp.value) != '')
					choices.push(temp);	 	
			});			 
			return choices;
		}
		
		function saveAllChoices(){
			var sourceData = $H(jQuery(SourceField).data("raw"));
				sourceData.set("choices", getAllChoices(dialogDOMMap.choices));
				sourceData.set('action', "edit");
				constFieldDOM(sourceData.toObject(), jQuery(SourceField));
		}
		
		function hideDialog(){ 
			jQuery("#CustomFieldsDialog").css({"left":-999999});
			dialogHidden = true;
		}
		
		function DialogOnLoad(sourceField){ 
			// Dialog Population Method
			try {
				jQuery(SourceField).removeClass("active");
				SourceField = sourceField;
				sourceDomMap = {
					"label": jQuery(sourceField).find("label")
				};
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
				dialogDOMMap.agent.closure.attr("checked", sourceData.agent.closure);
				dialogDOMMap.customer.visible.attr("checked", sourceData.customer.visible);
				innerLevelExpand(dialogDOMMap.customer.visible.get(0));
				
				dialogDOMMap.customer.editable.attr("checked", sourceData.customer.editable);
				innerLevelExpand(dialogDOMMap.customer.editable.get(0));
				
				dialogDOMMap.customer.required.attr("checked", sourceData.customer.required);
				
				jQuery("#DropFieldChoices").hide();
				
				if (sourceData.fieldType == 'default') {
					dialogDOMMap.label.attr("disabled", true);
					dialogDOMMap.label.addClass("disabled");
					jQuery('#DeleteField').hide();
				}
				else {
					jQuery('#DeleteField').show();
					dialogDOMMap.label.attr("disabled", false);
					dialogDOMMap.label.removeClass("disabled");
					
					if (sourceData.type == 'dropdown') {
						jQuery("#DropFieldChoices").show();
					}
				}
				/*
				$('#AgentMandatory').show();
				
				switch (sourceData.type){
					case 'checkbox': 
						$('#AgentMandatory').hide();
					break;
				}
				*/
				
			}catch(e){
				 
			}
		}      
        
		jQuery("#SaveField").click(function()
		{
			var sourceData   	         	= $H(jQuery(SourceField).data("raw"));	
			
			sourceData.set("label" 		 		 , dialogDOMMap.label.val());
			sourceData.set("display_name" 		 , dialogDOMMap.label.val());
			sourceData.set("description" 		 , dialogDOMMap.description.val());
			
			sourceData.get("agent").required	= dialogDOMMap.agent.required.attr("checked");
			sourceData.get("agent").closure		= dialogDOMMap.agent.closure.attr("checked");
					
			sourceData.get("customer").visible	= dialogDOMMap.customer.visible.attr("checked");										
			sourceData.get("customer").editable = dialogDOMMap.customer.editable.attr("checked");
			sourceData.get("customer").required = dialogDOMMap.customer.required.attr("checked");  											
				
			sourceData.set("choices", getAllChoices(dialogDOMMap.choices));									
			
			sourceData.set('action', "edit");			
			
			constFieldDOM(sourceData.toObject(), jQuery(SourceField));
		});
		
		$("#CustomFieldsDialog input").live("change", function(){
			var sourceData = $H(jQuery(SourceField).data("raw"));
			switch(this.name){
				case 'choice':
					sourceData.set("choices", getAllChoices(dialogDOMMap.choices));			
				break;
				
				case 'customlabel':
					field_label = jQuery.trim(this.value);
					if(field_label == '')
						field_label = "Untitled";
					
					sourceData.set("label", 	   field_label);
					sourceData.set("display_name", field_label);
					
					this.value = field_label;
				break;
				
				case 'customdesc':
					sourceData.set("description",  this.value);
				break;	
				
				case 'agentrequired':
					sourceData.get("agent").required = $(this).attr("checked");
				break;
				
				case 'agentclosure':
					sourceData.get("agent").closure = $(this).attr("checked");
				break;
				
				case 'customervisible':
					sourceData.get("customer").visible = $(this).attr("checked");
					if (sourceData.get("customer").visible == false) {
						sourceData.get("customer").editable = false
						sourceData.get("customer").required = false;
					}
				break;
				
				case 'customereditable':
					sourceData.get("customer").editable = $(this).attr("checked");
					if (sourceData.get("customer").editable == false) 
						sourceData.get("customer").required = false;
 				break;
				
				case 'customerrequired':
					sourceData.get("customer").required = $(this).attr("checked");
				break;
			} 
			sourceData.set('action', "edit");
			constFieldDOM(sourceData.toObject(), jQuery(SourceField));
		});
		
		
		var deleteField = function(sourcefield){
			if (confirm('Are you sure you want to delete this field?')) {
				var sourceData = jQuery(sourcefield).data("raw");
				if( sourceData.columnId == '' || sourceData.columnId == null){
					jQuery(sourcefield).remove();
				}else{
					sourceData.action = "delete";
					jQuery(sourcefield).hide();
				}
				hideDialog();
			}
		};
		
		jQuery("#DeleteField").live("click", function(e){
			deleteField(SourceField);
		});
		
		jQuery(dialogDOMMap.label).live("keyup", function(ev){
			sourceDomMap.label.text(this.value);
		});
		 
		jQuery("#CustomFieldsDialog").draggable();
		
		showFieldDialog = function(element){
			DialogOnLoad(element); 
			/*jQuery("#CustomFieldsDialog")
				.show("highlight", 5000, function(){
						jQuery(element).clearQueue();											
				 });*/
			
			offset 		=  $(element).offset();
			offset.left += ($(element).width() - 50) ; 
			offset.top  -= 50;
			
			jQuery("#CustomFieldsDialog")
				.position({
					my:"left top",
					at:"right top",
					of: element,
					collision: "fit fit",
					offset: "-50 -50"
				})
			
			if (dialogHidden) {
				jQuery("#CustomFieldsDialog").show("slide", { direction: "left" }, 500);
				dialogHidden = false;
			}
		} 
		
        jQuery("#custom_form li").live("click", function(e){           
			showFieldDialog(this); 
        });
		  
    };
})(jQuery);

	