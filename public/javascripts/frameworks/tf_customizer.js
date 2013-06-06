  /**
 * @author venom
 */ 
 
(function($){
   ticket_fields_modified = false;  

   $(document).ready(init);

	function init(){
      var fieldFeed        = tf_settings,
          DialogFieldPref  = null,
          SourceField	     = null,
          sourceDomMap	   = null,
          dialogHidden	   = true,
          nestedTree       = new NestedField(""),
          sourceData       = null,
          dialogContainer  = "div#CustomFieldsDialog";

      $.validator.addMethod("nestedTree", function(value, element, param) {
        _condition = true;
        if(sourceData.field_type == "nested_field"){
          nestedTree.readData(value);
          _condition = nestedTree.second_level;
        }
        return _condition;
      }, "You need atleast one category & sub-category");    
      $.validator.addMethod("uniqueNames", function(value, element, param) {
        _condition = true;
        levels = [1, 2, 3];
        if(sourceData.field_type == "nested_field"){
          current_level = $(element).data("level");
          levels.each(function(i){
            if(current_level == i || !_condition) return;            
            _condition = ($("#agentlevel"+i+"label").val().strip().toLowerCase() != $(element).val().strip().toLowerCase())
          });
        }
        return _condition;
      }, "Agent label should not be same as other two levels");    

      // Mapping individual dom elements to its data counterparts
      var dialogDOMMap = {
         field_type:             jQuery(dialogContainer+' input[name|="customtype"]'),
         label:                  jQuery(dialogContainer+' input[name|="customlabel"], #agentlevel1label'),
         label_in_portal:        jQuery(dialogContainer+' input[name|="customlabel_in_portal"], #customerslabel'),
         description:            jQuery(dialogContainer+' input[name|="customdesc"]'),
         active:                 jQuery(dialogContainer+' input[name|="customactive"]'),
         required:               jQuery(dialogContainer+' input[name|="agentrequired"]'),
         required_for_closure:   jQuery(dialogContainer+' input[name|="agentclosure"]'),
         visible_in_portal:      jQuery(dialogContainer+' input[name|="customervisible"]'), 
         editable_in_portal:     jQuery(dialogContainer+' input[name|="customereditable"]'), 
         required_in_portal:     jQuery(dialogContainer+' input[name|="customerrequired"]'),
         choices:                jQuery(dialogContainer+' div[name|="customchoices"]'),
         portalcc:       jQuery(dialogContainer+' input[name|="portalcc"]'),
         portalcc_to:            jQuery(dialogContainer+' input[name|="portalcc_to"]'),
      };

      var fieldTemplate =
            $H({
                 type:                   "text",
                 dom_type:               "text",
                 field_type:             "",
                 label:                  tf_lang.untitled,
                 label_in_portal:        "", 
                 description:            "",
                 field_type:             "custom",
                 active:                 true,
                 required:               false,
                 required_for_closure:   false,
                 visible_in_portal:      true, 
                 editable_in_portal:     true, 
                 required_in_portal:     false,
                 id:                     null, 
                 choices:                [],
                 levels:                 [],     
                 portalcc:       false,
                 portalcc_to:            "all",
                 action:                 "create" // delete || edit || create

             });

      // Map any document related actions here
      $(document).keyup(function(e){
         if (e.keyCode == 27) { $("#cancel-button").trigger("click"); } // Capturing ESC keypress event to make dialog hide after it becomes open
      });

      $("input[rel=status-companion]")
        .live({ 
          "keyup": function(ev){            
            if($(this).data("companionEmpty")) $(this).parent().parent().find("input[name=customer_display_name]").val(this.value);
          }, 
          "focus": function(ev){
            _entity = $(this).parent().parent().find("input[name=customer_display_name]");
            $(this).data("companionEmpty", (_entity && _entity.val().strip() === ""));
          }
      });

      // Init for Dropdown textarea
      $("#nestedTextarea")
          .bind("focusin", function(ev){
            jQuery(this).prop("rows", 18);
          })
          .tabby();
      $("#nestedDoneEdit").click(function(ev){   
            ev.preventDefault();
            nestedTree.readData($('#nestedTextarea').val());
            $("#nestedTextarea").trigger("blur");
            $("#nest-category").html(nestedTree.getCategoryEscaped()).trigger("change");
            setTimeout(hideNestedTextarea, 200);
      });
      $("#nest-category").change(function(ev){    
          $("#nest-subcategory").html(nestedTree.getSubcategoryEscaped($(this).children('option:selected').text())).trigger("change");
      });
      $("#nest-subcategory").change(function(ev){
          $("#nest-item").html(nestedTree.getItemsEscaped($("#nest-category option:selected").text(), $(this).children("option:selected").text()));
      });               
      $("#nested-edit-button").click(function(ev){ 
          ev.preventDefault();          
          showNestedTextarea();    
      });

      function showNestedTextarea(){
        $('#nestedTextarea-error').hide();
        //$("#Commitfieldtype").prop("disabled", true);
        $("#nestedEdit").slideDown();
        $("#nested-selectboxs").slideUp();
      }

      function hideNestedTextarea(){
        //$("#Commitfieldtype").prop("disabled", false);
        if(!$("#nestedTextarea").hasClass("error")){              
          $("#nestedEdit").slideUp();
          $("#nested-selectboxs").slideDown(); 
        }
      }

      //For cc option to show

       $("#portalcc_id").click(function(ev){ 
            $("#cc_to_option").toggle();
          });

      function constFieldDOM(dataItem, container){
         var fieldContainer = container || jQuery("<li />");
         fieldContainer.empty();

         var label = jQuery("<label />").append(dataItem.label);
         var field = jQuery("<div />");

         var fieldAttr = '';  
         
         switch(dataItem.dom_type) {
            case 'requester':
               dataItem.type = "text";
            break;
            case 'dropdown_blank':
               dataItem.type = "dropdown";
            break;
            case 'html_paragraph':
               dataItem.type = "paragraph";
            break;
            default:
               dataItem.type = dataItem.dom_type;
         }
         
         switch(dataItem.dom_type) {           
            case 'text':
            case 'number':
               field.append('<input type="text" '+fieldAttr+' disabled="true" />');
               fieldContainer.append(label);
            break;
            case 'requester':
               field.append('<input type="text" '+fieldAttr+' disabled="true" />');
               field.append('<span>&nbsp;<a href="#" class="underline">Add cc</a></span>');
               fieldContainer.append(label);
            break;

            case 'checkbox':               
               field.append('<input type="checkbox" disabled="true" '+ fieldAttr +' />' + dataItem.label );
            break;
         
            case 'dropdown':
            case 'dropdown_blank':              
              if(dataItem.field_type == "nested_field"){
               nestedTree = new NestedField(dataItem.choices);
               category = $("<select disabled='disabled' />").append(nestedTree.getCategory());
               fieldContainer.append(label).append(category);

               // _nested = $("<div class='tabbed' />").appendTo(fieldContainer);
               // dataItem.levels.each(function(item){
               //    if(item.label){
               //      _nested
               //        .append("<label>"+item.label+"</label>")  
               //        .append("<select disabled='disabled'><option>...</option></select>");
               //    }
               // });  

              }else{
                if(dataItem.field_type == "default_status"){
                  dataItem.choices.each(function(item){
                    field.append("<option value=" + item.status_id + ">" + escapeHtml(item.name) + "</option>");
                  });
                }else{
                  $(dataItem.choices).each(function(ci, choice){
                    field.append("<option " + choice[1] + ">" + choice[0] + "</option>");
                  });
                }
               field.wrapInner("<select "+fieldAttr+" disabled='true' />");
               fieldContainer.append(label);
             }
               
            break;

            case 'paragraph':
            case 'html_paragraph':
               field.append('<textarea disabled="true"'+fieldAttr+'></textarea>');
               fieldContainer.append(label);
            break;
         }

         fieldContainer.addClass((dataItem.field_type == "nested_field")?"nestedfield":dataItem.dom_type).append(field);
         $(field).prepend("<span class='overlay-field' />");         
         if (dataItem.action) ticket_fields_modified = true;  
         fieldContainer.data("raw", dataItem);

         return fieldContainer;
      }

      function getFreshField(type, field_type){
         var freshField             = fieldTemplate.toObject();
             freshField.field_type  = field_type;
             freshField.dom_type    = type;

         if (field_type == 'nested_field'){
            text = "category 1 \n"+
                   "\tsubcategory 1\n"+
                   "\t\titem 1\n"+
                   "\t\titem 2\n"+
                   "\tsubcategory 2\n"+
                   "\t\titem 1\n"+
                   "\t\titem 2\n"+
                   "\tsubcategory 3\n"+
                   "category 2 \n"+
                   "\tsubcategory 1\n"+
                   "\t\titem 1\n"+
                   "\t\titem 2\n";
            freshField.choices = text;      
            freshField.levels = [{level: 2},{level: 3}];
         }else if (field_type == 'custom_dropdown'){
            freshField.choices = [[tf_lang.first_choice, 0], [tf_lang.second_choice, 0]];
         }
         return freshField;
      }

      function getCustomFieldJson(){
         var allfields = $A();
         jQuery("#custom_form li").each(function(index, domLi){
            var data = $(domLi).data("raw");
            delete data.portalcc;
            delete data.portalcc_to;
            delete data.dom_type;
            delete data.level_three_present;
            allfields.push(data);
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
                     if(ui.item.data("fresh")){
                       field_label = ui.item.text();
                       type = ui.item.data('type');
                       field_type = ui.item.data('fieldType');
                       if(type)
                          showFieldDialog(constFieldDOM(getFreshField(type, field_type), ui.item));

                       ticket_fields_modified = true;
                     }
                  }
               })
         .droppable();

      $(".customchoices")
         .sortable({
            items: 'fieldset',
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

      $("#close_button, #cancel-button").click(function(e){
        if($(SourceField).data("fresh"))
           $(SourceField).remove(); 
        hideDialog();
      });

      function innerLevelExpand(checkbox){ 
        var next_ele=$("#"+checkbox.getAttribute("toggle_ele"));
        if(checkbox.checked){
          next_ele
            .children("label")
            .removeClass("disabled")
            .children("input:checkbox")
            .attr("disabled", false);
            if(sourceData.field_type == 'default_ticket_type' || sourceData.field_type ==  'default_status'){
              if(next_ele.selector=="#nestedlvl3")
              {
                next_ele.find("input:checkbox").attr("checked",true).attr("disabled",true);
              }
            }
        }else{
          next_ele
            .find("label")
            .addClass("disabled")
            .children("input:checkbox")
            .prop("checked", false)
            .prop("disabled", true);
        }
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
                              .val(unescapeHtml(data[0]))
                              .attr("data_id", data[1])
                              .change(function(){$("#ChoiceListValidation").next("label").hide();});
         var dropSpan  = $("<span class='dropchoice' />").append(inputData);

         $("<fieldset />")
            .append("<span class='sort_handle' />")
            .append('<img class="deleteChoice" src="/images/delete.png" />')
            .append(dropSpan)            
            .appendTo(dom);  
      }

      function addStatusinDialog(_data){
        _template = $("#statusTemplate").template();
        _data = _data || [{ status_id : 0, name : "", customer_display_name : "", stop_sla_timer : false }]
        _data.each(function(item){
          $.tmpl( _template, item ).appendTo( (item.deleted) ? "#statuschoicesdeleted" : "#statuschoices" );  
        });
        
      }

      function getAllStatusChoices(){
        var allstatus = [];
        $.each($("#statuschoices fieldset"), function(i, item){
          var _status = $H();
          $.each($(item).find("input"), function(_i, _item){
            _value = escapeHtml(_item.value);
            if(_item.type == "checkbox")
              _value = ($(_item).prop("checked"));
            
            if(_item.name == "status_id")
              _value = parseInt(_item.value);

            if(_item.name == "customer_display_name")
              _value = escapeHtml(_item.value || $(_item).parent().parent().find("input[name=name]").val());

            _status.set(_item.name, _value);
          });
          allstatus.push(_status.toObject());          
        });
        return allstatus;
      }


      
      function getAllChoices(dom){      
         var choices = $A();         
         dom.find('fieldset').each(function(choiceset){
            var temp        = [ '', 0 ],
                input_box   = $(this).find("span.dropchoice input");
                
                temp[0]     = escapeHtml(input_box.val());
                temp[1]     = input_box.attr("data_id");
                
            if($.trim(temp[0]) !== '') choices.push(temp);
         });
         return choices;
      }

      jQuery("#DropFieldChoices .deleteChoice")
         .live('click', function(){
                          if(jQuery(this).parent().siblings().size() !== 0) {
                            jQuery(this).parent().remove();
                            saveAllChoices();
                          }
                        });

      jQuery("#statuschoices .deleteChoice")
         .live('click', function(){
                          if(jQuery(this).hasClass('disabled')) return;
                            jQuery(this)
                              .parent()
                              .hide()
                              .find("input[name=deleted]")
                              .prop("checked", true);
                        });

      jQuery("#addchoice")
         .live('click', function(){
                           addChoiceinDialog();
                        }); 

      jQuery("#addstatus")
        .live("click", function(){
          addStatusinDialog();
        });

      function saveAllChoices(){
         var sourceData = $H($(SourceField).data("raw"));
             sourceData.set("choices", getAllChoices(dialogDOMMap.choices));
             setAction(sourceData, "edit");
         constFieldDOM(sourceData.toObject(), $(SourceField));
      }

      function hideDialog(){ 
         jQuery("#CustomFieldsDialog").css({"visibility":"hidden"});
         jQuery("#nestedTextarea").prop("rows", 6);
         $("#SaveForm").prop("disabled", false);
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
            $("#TicketProperties").find(':input').each(function() {
                switch(this.type) {
                    case 'text':
                    case 'textarea':
                        $(this).val('');
                        break;
                }
            });
            $("#ChoiceListValidation").next("label").hide();
            $(SourceField).removeClass("active");
            SourceField = sourceField;
            sourceDomMap = { "label": $(sourceField).find("label") };

            $(sourceField).addClass("active");

            sourceData = $(sourceField).data("raw");

            dialogDOMMap.field_type.val(sourceData.type);
            dialogDOMMap.label.val(unescapeHtml(sourceData.label));
            dialogDOMMap.label_in_portal.val(unescapeHtml(sourceData.label_in_portal));
            dialogDOMMap.description.val(sourceData.description);

            $("div#CustomFieldsDialog label.overlabel").overlabel();

            dialogDOMMap.choices.empty();  
            $("#nestedContainer").hide();
            $("#nested-selectboxs").hide();
            $("#nestedEdit").hide();
            $("#StatusFieldChoices").hide();
            $("#statuschoices").empty();

            if(sourceData.field_type == 'default_requester'){
                manageFieldOptions(sourceField);
             }
   
            
            if(sourceData.field_type == "nested_field"){ 
              $("#nestedContainer").show();         
              $("#NestedFieldLabels").show();
              //if(typeof sourceData.choices == "string"){                    
              //    showNestedTextarea();
              //}else{   
              $("#nested-selectboxs").show();  
              //}                        
              nestedTree.readData(sourceData.choices);
              $("#nestedTextarea").val(nestedTree.toString());   
              $("#nest-category").html(nestedTree.getCategory()).trigger("change");
              sourceData.levels.each(function(item){
                item.label ? $("#agentlevel"+item.level+"label").val(unescapeHtml(item.label)):$("#agentlevel"+item.level+"label").val(item.label);
                item.label_in_portal ? $("#customerslevel"+item.level+"label").val(unescapeHtml(item.label_in_portal)):$("#customerslevel"+item.level+"label").val(item.label_in_portal);
              });
            }else if(sourceData.field_type == "default_status"){
              $("#StatusFieldChoices").show();
              addStatusinDialog(sourceData.choices);
            }else{
              sourceData.choices.each(function(item){
                 addChoiceinDialog(item, dialogDOMMap.choices);
              });
            }

            $("#NestedFieldLabels").toggle(sourceData.field_type == 'nested_field');
            $("#FieldLabels").toggle(sourceData.field_type != 'nested_field');

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
            $("#req_field_options").show();
            $("#agent_cc_field").show();
            
            if(sourceData.field_type != "default_requester"){
               $("#AgentMandatory").show();
               $("#CustomerConditions").show();
               $("#req_field_options").hide();
               $("#agent_cc_field").hide();
            }

            if (/^default/.test(sourceData.field_type)){
               dialogDOMMap.label.attr("disabled", true);
               dialogDOMMap.label.addClass("disabled");
               $('#DeleteField').hide();
            } else {
               $('#DeleteField').show();
               dialogDOMMap.label.attr("disabled", false);
               dialogDOMMap.label.removeClass("disabled");               
            }  

            switch(sourceData.field_type){
              case 'custom_dropdown':
              case 'default_ticket_type':
                $("#DropFieldChoices").show();
              break;
            }      
            if(sourceData.field_type == 'default_ticket_type' || sourceData.field_type ==  'default_status'){
               $('[name="agentrequired"]').attr("disabled",true );
             }
             else
             {
                $('[name="agentrequired"]').removeAttr("disabled");
             }             
               
        }catch(e){}
      }

      function manageFieldOptions(sourceField){
        sourceData = $(sourceField).data("raw");
        $.each(sourceData.field_options ,(function(item ,value){

               switch(item) 
               {
                  
                  case 'portalcc':
                      dialogDOMMap.portalcc.attr("checked", value);
                      if (value){$("#cc_to_option").show();}
                  break;
                  case 'portalcc_to':
                      dialogDOMMap.portalcc_to.filter('[value='+value+']').attr('checked', true);
                  break;
                }

              }));
      }

      function saveDataObj(){
         if(SourceField !== null){            
            var sourceData = $H($(SourceField).data("raw")),
                _field_type = sourceData.get("field_type");
         // sourceData.set("name"                  , dialogDOMMap.label.val());
            sourceData.set("label"                 , escapeHtml(dialogDOMMap.label.val()));
            sourceData.set("label_in_portal"       , escapeHtml(dialogDOMMap.label_in_portal.val()));
            sourceData.set("description"           , dialogDOMMap.description.val());

            sourceData.set("required"              , dialogDOMMap.required.prop("checked"));
            sourceData.set("required_for_closure"  , dialogDOMMap.required_for_closure.prop("checked"));

            sourceData.set("visible_in_portal"     , dialogDOMMap.visible_in_portal.prop("checked"));
            sourceData.set("editable_in_portal"    , dialogDOMMap.editable_in_portal.prop("checked"));
            sourceData.set("required_in_portal"    , dialogDOMMap.required_in_portal.prop("checked"));

             if(_field_type == 'default_requester'){
                
                var field_options =  { 
                                       portalcc:   dialogDOMMap.portalcc.prop("checked"),
                                       portalcc_to:       dialogDOMMap.portalcc_to.filter(':checked').val(),
                                      };

                sourceData.set("field_options" , field_options);
                // Hard setting for requester field
                sourceData.set("required"              , true);
                sourceData.set("required_for_closure"  , false);
                sourceData.set("visible_in_portal"     , true);
                sourceData.set("editable_in_portal"    , true);
                sourceData.set("required_in_portal"    , true);
             }
   
            if(_field_type == 'nested_field'){
              setNestedFields(sourceData);              
              sourceData.set("label", escapeHtml($("#agentlevel1label").val()));
              sourceData.set("label_in_portal", escapeHtml($("#customerslabel").val()));
              sourceData.set("choices", nestedTree.toArray());  
            }else if(_field_type == "default_status"){
              sourceData.set("choices", getAllStatusChoices());
              //console.log(getAllStatusChoices());
            }else{
              sourceData.set("choices", getAllChoices(dialogDOMMap.choices));  
            }

            setAction(sourceData, "edit"); 

            constFieldDOM(sourceData.toObject(), $(SourceField));
            //console.info(sourceData.toJSON());
            $(SourceField).data("fresh", false);
         }
      }     

      
      function setNestedFields(sourceData){                  
          levels = sourceData.get("levels");
          action = (sourceData.get("level_three_present")) ? ((nestedTree.third_level) ? "edit" : "delete") : "create";

          if(levels.size() < 2) levels.push({level:3});

          if(!sourceData.get("level_three_present") && !nestedTree.third_level)
            levels.pop();

          sourceData.set("levels", levels.map(function(item){
            return { 
                label           : escapeHtml($("#agentlevel"+item.level+"label").val()),
                label_in_portal : escapeHtml($("#customerslevel"+item.level+"label").val()), 
                description     : '',
                level           : item.level,
                id              : (item.id || null),
                position        : 1,
                type            : 'dropdown',
                action          : (item.level == 3) ? action : "edit" 
              }
            }));
      }

      $("#TicketProperties")
         .submit(function(){ return false; })
         .validate({
            submitHandler: function(){
              saveDataObj();
              hideDialog();
            },
            rules: {
               choicelist: {
                  "required":{
                     depends: function(element) {
                                $("#ChoiceListValidation").val("");
                                if($("#DropFieldChoices").css("display") == "block"){
                                    choiceValues = "";
                                    $.each($("#DropFieldChoices").find("input"), function(index, item){
                                       choiceValues += item.value;
                                    });
                                    return ($.trim(choiceValues) == "");
                                }else{
                                   return false;
                                }
                             }
                  }
              },
              customlabel: {
                "required":{
                  depends: function(element){ return ($("#FieldLabels").css("display") != "none") }
                }
              },
              customlabel_in_portal: {
                "required":{
                  depends: function(element){ return ($("#FieldLabels").css("display") != "none") }
                }
              },
              agentlabel: {
                "required":{
                  depends: function(element){ return ($("#NestedFieldLabels").css("display") != "none") }
                },
                "uniqueNames": true
              },
              customerslabel: {
                "required":{
                  depends: function(element){ return ($("#NestedFieldLabels").css("display") != "none") }
                }
              },                          
              agentlevel2label: {
                "required":{
                  depends: function(element){ return ($("#NestedFieldLabels").css("display") != "none") }
                },
                "uniqueNames": true
              },
              customerslevel2label: {
                "required":{
                  depends: function(element){ return ($("#NestedFieldLabels").css("display") != "none") }
                }
              },                          
              agentlevel3label: {
                "required":{
                  depends: function(element){
                    return (($("#NestedFieldLabels").css("display") != "none") && nestedTree.third_level); 
                  }
                },
                "uniqueNames": true
              },
              customerslevel3label: {
                "required":{
                  depends: function(element){ 
                    return (($("#NestedFieldLabels").css("display") != "none") && nestedTree.third_level); 
                  }
                }
              },
              nestedTextarea: {
                "required": {
                  depends: function(element){ return ($("#NestedFieldLabels").css("display") != "none") }
                },
                "nestedTree": true
              }
            },

            messages: {
               choicelist: tf_lang.no_choice_message,
               agentlevel3label: {
                required: "Label required for 3rd level items"
               },
               customerslevel3label: {
                required: "Label required for 3rd level items"
               }
            },
            onkeyup: false,
            onclick: false
         });

         
      $("#CustomFieldsDialog input").live("change", function(){
         var sourceData = $H($(SourceField).data("raw"));
         switch(this.name){
            case 'choice':
               sourceData.set("choices", getAllChoices(dialogDOMMap.choices));
            break;

            case 'customlabel':
               field_label = $.trim(this.value);
               if(field_label === '') field_label = tf_lang.untitled;
               sourceData.set("label", field_label);
               sourceData.set("label_in_portal", field_label);
               // dialogDOMMap.label_in_portal.attr("initial-value", field_label);
               this.value = field_label;
            break;
            
            case 'customlabel_in_portal':
               sourceData.set("label_in_portal", this.value);
               // dialogDOMMap.label_in_portal.attr("initial-value", this.value);
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
            //For CC fields

          
         }
         setAction(sourceData, "edit");
         //constFieldDOM(sourceData.toObject(), $(SourceField));
      });

      var deleteField = function(sourcefield){
         if (confirm(tf_lang.confirm_delete)) {
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

      $("#CustomFieldsDialog").draggable();

      showFieldDialog = function(element){
         DialogOnLoad(element);
         offset       =  $(element).offset();
         offset.left += ($(element).width() - 50) ; 
         offset.top  -= 50;

         // $("#CustomFieldsDialog")
         //    .position({
         //       my:"left center",
         //       at:"center center",
         //       of: element,
         //       collision: "fit fit",
         //       offset: "-50 -100"
         //    });
        $("#SaveForm").prop("disabled", true);
        $("#CustomFieldsDialog").css("top", jQuery(document).scrollTop()+"px");

         if (dialogHidden) {
            $("#CustomFieldsDialog")
              .show()
              .css("visibility", "visible");            

            dialogHidden = false;
         }
      };

      $("#custom_form li").live("click", function(e){           
         showFieldDialog(this); 
      });

      $("#SaveForm").click(function(ev){
         ev.preventDefault();
         var jsonData = getCustomFieldJson();
         $("#field_values").val(jsonData.toJSON());
         this.value = $(this).data("commit")
         $(this).prop("disabled", true);
         $("#Updateform").trigger("submit");
         //console.log(this);
         //console.log(jsonData.toJSON());
         //return false;
      });
    }
})(jQuery);
