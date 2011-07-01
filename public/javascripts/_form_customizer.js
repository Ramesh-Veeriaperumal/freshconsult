/**
 * @author venom
 */ 
(function($){
   ticket_fields_modified = false;
   
   $(document).ready(init);

	function init(){
      var fieldFeed        = custom_field_values,
          DialogFieldPref  = null,
          SourceField	   = null,
          sourceDomMap	   = null,
          dialogHidden	   = true,
          dialogContainer  = "div#CustomFieldsDialog";

      // Mapping individual dom elements to its data counterparts
      var dialogDOMMap = {
         field_type:             jQuery(dialogContainer+' input[name|="customtype"]'),
//       name:                   "Untitled",
         label:                  jQuery(dialogContainer+' input[name|="customlabel"]'),
         label_in_portal:        jQuery(dialogContainer+' input[name|="customlabel_in_portal"]'),
         description:            jQuery(dialogContainer+' input[name|="customdesc"]'),
         active:                 jQuery(dialogContainer+' input[name|="customactive"]'),
         required:               jQuery(dialogContainer+' input[name|="agentrequired"]'),
         required_for_closure:   jQuery(dialogContainer+' input[name|="agentclosure"]'),
         visible_in_portal:      jQuery(dialogContainer+' input[name|="customervisible"]'), 
         editable_in_portal:     jQuery(dialogContainer+' input[name|="customereditable"]'), 
         required_in_portal:     jQuery(dialogContainer+' input[name|="customerrequired"]'),
         choices:                jQuery(dialogContainer+' div[name|="customchoices"]'),
      };

      var fieldTemplate = 
            $H({
                 type:                   "text",
                 field_type:             "",
                 //name:                 "Untitled",
                 label:                  "Untitled",
                 label_in_portal:        "Untitled", 
                 description:            "",
                 field_type:             "custom",
                 active:                 true,
                 required:               false,
                 required_for_closure:   false,
                 visible_in_portal:      true, 
                 editable_in_portal:     false, 
                 required_in_portal:     false,
                 id:                     null, 
                 choices:                [],
                 action:                 "create" // delete || edit || create
             });

      function constFieldDOM(dataItem, container){
         var fieldContainer  = container || jQuery("<li />");
         fieldContainer.empty();

         var label = jQuery("<label />").append(dataItem.label);
         var field = jQuery("<div />");

         var fieldAttr     = '';
         
         switch(dataItem.dom_type) {
            case 'requester':
               dataItem.type = "requester";
            break;
            case 'dropdown_blank':
               dataItem.type = "dropdown";
            break;
            default:
               dataItem.type = dataItem.dom_type;
         }
         
         switch(dataItem.dom_type) {
            case 'text':
            case 'requester':
            case 'number':
               field.append('<input type="text" '+fieldAttr+' disabled="true" />');
               fieldContainer.append(label);
            break;
         
            case 'checkbox':               
               field.append('<input type="checkbox" disabled="true" '+ fieldAttr +' />' + dataItem.label );
            break;
         
            case 'dropdown':
            case 'dropdown_blank':
               $(dataItem.choices).each(function(ci, choice){
                  field.append("<option " + choice[1] + ">" + choice[0] + "</option>");
               });

               field.wrapInner("<select "+fieldAttr+" disabled='true' />");
               fieldContainer.append(label);
            break;
         
            case 'paragraph':
               field.append('<textarea disabled="true"'+fieldAttr+'></textarea>');
               fieldContainer.append(label);
            break;
         }

         fieldContainer.addClass(dataItem.dom_type).append(field);
         $(field).prepend("<span class='overlay-field' />");
         if (dataItem.action) ticket_fields_modified = true;
         fieldContainer.data("raw", dataItem);

         return fieldContainer;
      }

      function getFreshField(type){
         var freshField = fieldTemplate.toObject();
             freshField.field_type = type;	
             
         if (type == 'custom_dropdown')
            freshField.choices = [["First Choice", 0], ["Second Choice", 0]];
            
         return freshField;
      }

      function getCustomFieldJson(){
         var allfields = $A();
         jQuery("#custom_form li").each(function(index, domLi){
            allfields.push($(domLi).data("raw"));
         });
         return allfields;
      } 

      function feedJsonForm(formInput){
         $(formInput).each(function(index, dataItem){
            var dom = constFieldDOM(dataItem);
            $("#custom_form").append(dom);	
         });
      }

      feedJsonForm(fieldFeed);

      $("#custom_fields li")
         .draggable({
            connectToSortable: "#custom_form",
            helper: "clone",
            stack:  "#custom_fields li",
            revert: "invalid"
        });
        
      $("#custom_form")
         .sortable({
            revert: true,
            start: function(ev, ui) {
                     saveDataObj();
                   },
            stop: function(ev, ui) { 
                     type = ui.item.get(0).getAttribute('type');
                     if (type)
                        showFieldDialog(constFieldDOM(getFreshField(type), ui.item));

                     ticket_fields_modified = true;
                  }
               })
         .droppable();

      $(".customchoices")
         .sortable({
            items: 'fieldset'	,
            handle: ".sort_handle",
            stop: function(ev){
               saveAllChoices();
            }
         });

      if($.browser.msie) {
         $(".ui-custom-form li").hover(function(){
            $(this).addClass("hover");
         }, function(){
            $(this).removeClass("hover");
         });
      }

      $("#close_button, #close_button_2").click(function(e){
         hideDialog();
      });

      $("#SaveForm").click(function(e){
         var jsonData = getCustomFieldJson(); 
         $("#field_values").val(jsonData.toJSON());
      }); 

      function innerLevelExpand(checkbox){ 
         $("#"+checkbox.getAttribute("toggle_ele")).toggle(checkbox.checked);
      }

      $("#nestedConfig")
         .find("input:checkbox")
         .bind("change", function(e){
                  innerLevelExpand(this);
             });

      function addChoiceinDialog(data, dom){
         dom	= dom  || dialogDOMMap.choices;
         data	= data || [ '', 0 ];
         var inputData = $("<input type='text' />")
                              .val(data[0])
                              .attr("data_id", data[1]);
         var dropSpan  = $("<span class='dropchoice' />").append(inputData);

         $("<fieldset />")
            .append("<span class='sort_handle' />")
            .append(dropSpan)
            .append('<img class="deleteChoice" src="/images/delete.png" />')
            .appendTo(dom);
      }
      
      function getAllChoices(dom){      
         var choices = $A();         
         dom.find('fieldset').each(function(choiceset){
            var temp        = [ '', 0 ],
                input_box   = $(this).find("span.dropchoice input");
                
                temp[0]     = input_box.val();
                temp[1]     = input_box.attr("data_id");
                
            if($.trim(temp[0]) !== '') choices.push(temp);
         });         
         return choices;
      }

      jQuery(".deleteChoice")
         .live('click', function(){
                           if (jQuery(this).parent().siblings().size() !== 0) {
                              jQuery(this).parent().remove();
                              saveAllChoices();
                           }
                        });

      jQuery(".addchoice")
         .live('click', function(){
                           addChoiceinDialog();
                        }); 

      function saveAllChoices(){
         var sourceData = $H($(SourceField).data("raw"));
             sourceData.set("choices", getAllChoices(dialogDOMMap.choices));
             setAction(sourceData, "edit");
         constFieldDOM(sourceData.toObject(), $(SourceField));
      }

      function hideDialog(){ 
         jQuery("#CustomFieldsDialog").css({"left":-999999});
         dialogHidden = true;
      }

      function setAction(obj, action){
         switch(action){
            case "edit":
               if(obj.get('action') != "create") obj.set('action', action);
            break;
         }
      }

      function DialogOnLoad(sourceField){ 
         // Dialog Population Method
         try {
            $(SourceField).removeClass("active");
            SourceField = sourceField;
            sourceDomMap = {
               "label": $(sourceField).find("label")
            };

            $(sourceField).addClass("active");

            var sourceData = $(sourceField).data("raw");

            dialogDOMMap.field_type.val(sourceData.type);
            dialogDOMMap.label.val(sourceData.label);
            dialogDOMMap.label_in_portal.val(sourceData.label_in_portal);
            dialogDOMMap.description.val(sourceData.description);

            $("div#CustomFieldsDialog label.overlabel").overlabel();

            dialogDOMMap.choices.empty();
            sourceData.choices.each(function(item){
               addChoiceinDialog(item, dialogDOMMap.choices);
            });

            dialogDOMMap.required.attr("checked", sourceData.required);
            dialogDOMMap.required_for_closure.attr("checked", sourceData.required_for_closure);

            dialogDOMMap.visible_in_portal.attr("checked", sourceData.visible_in_portal);
            innerLevelExpand(dialogDOMMap.visible_in_portal.get(0));

            dialogDOMMap.editable_in_portal.attr("checked", sourceData.editable_in_portal);
            innerLevelExpand(dialogDOMMap.editable_in_portal.get(0));
            
            dialogDOMMap.required_in_portal.attr("checked", sourceData.required_in_portal);

            $("#DropFieldChoices").hide();
            $("#AgentMandatory").hide();
            $("#CustomerConditions").hide();
            
            if(sourceData.field_type != "default_requester"){
               $("#AgentMandatory").show();
               $("#CustomerConditions").show();
            }

            if (/^default/.test(sourceData.field_type)){
               dialogDOMMap.label.attr("disabled", true);
               dialogDOMMap.label.addClass("disabled");
               $('#DeleteField').hide();
            } else {
               $('#DeleteField').show();
               dialogDOMMap.label.attr("disabled", false);
               dialogDOMMap.label.removeClass("disabled");
               if(sourceData.field_type == 'custom_dropdown') $("#DropFieldChoices").show();
            }
         }catch(e){}
      }

      function saveDataObj(){
         if(SourceField !== null){
            var sourceData = $H($(SourceField).data("raw"));	

           // sourceData.set("name"                  , dialogDOMMap.label.val());
            sourceData.set("label"                 , dialogDOMMap.label.val());
            sourceData.set("label_in_portal"       , dialogDOMMap.label_in_portal.val());
            sourceData.set("description"           , dialogDOMMap.description.val());

            sourceData.set("required"              , dialogDOMMap.required.attr("checked"));
            sourceData.set("required_for_closure"  , dialogDOMMap.required_for_closure.attr("checked"));

            sourceData.set("visible_in_portal"     , dialogDOMMap.visible_in_portal.attr("checked"));
            sourceData.set("editable_in_portal"    , dialogDOMMap.editable_in_portal.attr("checked"));
            sourceData.set("required_in_portal"    , dialogDOMMap.required_in_portal.attr("checked"));

            sourceData.set("choices", getAllChoices(dialogDOMMap.choices));

            setAction(sourceData, "edit");

            constFieldDOM(sourceData.toObject(), $(SourceField));
         }
      }

      $("#SaveField")
         .click(function(){
            saveDataObj();
            hideDialog();
         });

      $("#CustomFieldsDialog input").live("change", function(){
         var sourceData = $H($(SourceField).data("raw"));
         switch(this.name){
            case 'choice':
               sourceData.set("choices", getAllChoices(dialogDOMMap.choices));
            break;

            case 'customlabel':
               field_label = $.trim(this.value);
               if(field_label === '') field_label = "Untitled";
               sourceData.set("label", field_label);
               sourceData.set("label_in_portal", field_label);
               this.value = field_label;
            break;
            
            case 'customlabel_in_portal':
               sourceData.set("label_in_portal", this.value);
            break;
            case 'customdesc':
               sourceData.set("description", this.value);
            break;	

            case 'agentrequired':
               sourceData.set("required", $(this).attr("checked"));
            break;
            
            case 'agentclosure':
               sourceData.set("required_for_closure", $(this).attr("checked"));
            break;
            
            case 'customervisible':
               sourceData.set("visible_in_portal", $(this).attr("checked"));
               if (sourceData.get("visible_in_portal") === false){
                  sourceData.set("editable_in_portal", false);
                  sourceData.set("required_in_portal", false);
               }
            break;

            case 'customereditable':
               sourceData.set("editable_in_portal", $(this).attr("checked"));
               if (sourceData.get("editable_in_portal") === false)
                  sourceData.set("required_in_portal", false);
            break;

            case 'customerrequired':
               sourceData.set("required_in_portal", $(this).attr("checked"));
            break;
         }
         setAction(sourceData, "edit");
         constFieldDOM(sourceData.toObject(), $(SourceField));
      });

      var deleteField = function(sourcefield){
         if (confirm('Are you sure you want to delete this field?')) {
            var sourceData = $(sourcefield).data("raw");
            if( sourceData.id === '' || sourceData.id === null){
               $(sourcefield).remove();
            }else{
               sourceData.action = "delete";
               $(sourcefield).hide();
            }
            hideDialog();
         }
      };

      $("#DeleteField").live("click", function(e){
         deleteField(SourceField);
      });

      $(dialogDOMMap.label).live("keyup", function(ev){
         sourceDomMap.label.text(this.value);
      });

      $("#CustomFieldsDialog").draggable();

      showFieldDialog = function(element){
         DialogOnLoad(element);
         offset       =  $(element).offset();
         offset.left += ($(element).width() - 50) ; 
         offset.top  -= 50;

         $("#CustomFieldsDialog")
            .position({
               my:"left top",
               at:"right top",
               of: element,
               collision: "fit fit",
               offset: "-50 -50"
            });

         if (dialogHidden) {
            $("#CustomFieldsDialog").show("slide", { direction: "left" }, 500);
            dialogHidden = false;
         }
      };

      $("#custom_form li").live("click", function(e){           
         showFieldDialog(this); 
      });

    }
})(jQuery);

	