var FD = FD || {};
FD.Util = {
    Ajax : function(){

    },
    getJSON : function(options){

    },
	reBrand: function(data){
		Ext.Viewport.getAt(1).setBranding(data);
	},
	initCustomer : function(){
		//initializing customer login settings..
		Ext.ComponentQuery.query('#ticketCustomerInfo')[0].hide();
        Ext.ComponentQuery.query('#noteFormCannedResponse')[0].hide();
        Ext.ComponentQuery.query('#noteFormPrivateField')[0].hide();
	},
	showAll : function(id){
		//To show full content in conversation section..
		document.getElementById(id).removeAttribute('class');
        document.getElementById('loadmore_'+id).setAttribute('class','hide');
	},
	check_user : function(){
		//Redirect to home 
		if(!FD.current_user){
			location.href="/mobile/"
		}
	},
	changeFavicon : function (src) {
		document.head || (document.head = document.getElementsByTagName('head')[0]);
		var link = document.createElement('link'),
		 oldLink = document.getElementById('favicon');
		link.id = 'favicon';
		link.rel = 'shortcut icon';
		link.href = src;
		if (oldLink) {
			document.head.removeChild(oldLink);
		}
		document.head.appendChild(link);
	},
	construct_ticket_form : function(ticket_fields,isEdit,listeners){
		var formData = isEdit ? [{xtype:'hiddenfield',name:'_method',value:'put'}] : [],
		key,ticket_field,form_field,_field,
        me=this;
        ticket_fields.forEach(function(ticket_field){
            _field = ticket_field['ticket_field'];
            form_field = me.construct_ticket_field(_field);
            form_field.listeners = listeners;
            form_field.nested_choices = me.get_nested_field_choices(_field.nested_choices);
            form_field.nested_levels = _field.nested_levels;
            formData.push(form_field);
            if (_field.nested_levels) {
                me.construct_nested_fields(formData,_field,listeners);
            }
        });
        return formData;
	},
    get_nested_field_choices : function(nested_choices,level){
        var return_obj = {};
        nested_choices.forEach(function(choice){
            return_obj[choice[1]]= choice[2];
        })
        return return_obj;
    },
    construct_nested_fields : function(formData,field,listeners){
        var mainfield_nested_choices = field.nested_choices,
            me=this,
            nested_levels = field.nested_levels,
            index=1,
            catVal = field.field_value && field.field_value.category_val;
            subcatVal = field.field_value && field.field_value.subcategory_val,
            itemVal = field.field_value && field.field_value.item_val,
            parent_nested_choices = this.get_nested_field_choices(mainfield_nested_choices);

        nested_levels.forEach(function(subfield){
            var nested_field = {domtype : 'dropdown_blank',is_default_field:false};
            nested_field.label = subfield.label;
            nested_field.field_name = subfield.name;
            nested_field.field_value = index == 1 ? subcatVal : itemVal;
            form_field = me.construct_ticket_field(nested_field);
            form_field.listeners = listeners;
            form_field.nested_levels = index ==1 ? [nested_levels[index]] : undefined;
            form_field.id = "nested_"+subfield.name;
            form_field.cls = "nestedField";
            if(!nested_field.field_value){
                form_field.hidden=true;
            }
            else{
                var childObj = me.getChildOptionsObj(parent_nested_choices,catVal);
                form_field.options = childObj.options;
                form_field.nested_choices = childObj.nested_choices;
                catVal = subcatVal;
                parent_nested_choices = childObj.nested_choices;
            }
            form_field.level = ++index;
            formData.push(form_field);
        })
    },
	construct_ticket_field : function(field){
		var item = {options:[]},choices,opt,key,
        field_name = field.field_name;
        item.label = field.label;
        item.name = field.is_default_field ? 'helpdesk_ticket['+field_name+']' : 'helpdesk_ticket[custom_field]['+field_name+']';
        item.required = field.required;
        item.value = field.nested_levels ? field.field_value.category_val : field.field_value;

        switch(field.domtype){
            case 'dropdown_blank':
                item.options=[{text:'...',value:''}];
            case 'dropdown' :
                item.xtype = 'selectfield';
                choices=field.choices;
                for(key in choices){
                    opt = choices[key];
                    item.options.push({text:opt[0],value:opt[1]});
                }
                break;
            case 'text' :
                item.xtype = 'textfield';
                break;
            case 'hidden' : 
                item.xtype = 'hiddenfield';
                break;
            case 'html_paragraph':
            case 'text':
            case 'paragraph':
                item.xtype = 'textareafield';
                break;
            case 'checkbox':
                item.xtype = 'checkboxfield';
                break;
            case 'number':
                item.xtype = 'numberfield';
                break;
            default :
                item.xtype = 'textfield';
                break;
        };
        return item;
	},
    validate_form : function(form){
        var items = form.getItems().items[0].items.items,valid=true;
        items.forEach(function(item){
            if(item.getRequired() && !item.getValue()){
                item.setCls('required');
                valid =false;
            }
        });
        return valid;
    },
    getChildOptionsObj : function(nested_choices,selected_value){
        if(!nested_choices)
            return
        var choices = nested_choices[selected_value],
            options=[{text:'...',value:''}],
            child_options = {};
        if(choices){
           choices.forEach(function(opt){
                options.push({text:opt[0],value:opt[1]});
                child_options[opt[1]] = opt[2];
            }); 
        }
        return {options:options,nested_choices:child_options};
    },
    enable_nested_field: function(select_field){
        var conf = select_field.config,
        nested_choices = conf.nested_choices,
        nested_levels = conf.nested_levels,
        current_level = conf.level,
        comp,
        select_field_value = select_field.getValue(),
        options = [];
        if(!nested_levels){
            return;
        }
        comp = Ext.getCmp('nested_'+nested_levels[0].name);
        if(!!select_field_value) {
            child_options_object = FD.Util.getChildOptionsObj(nested_choices,select_field_value)
            comp.setOptions(child_options_object["options"]).setHidden(false);
            comp.config.nested_choices = child_options_object["nested_choices"];
        }
        else {
            comp.setHidden(true).setValue('');
            /*nested_levels.forEach(function(_levelObj){
                Ext.getCmp('nested_'+_levelObj.name).setHidden(true).setValue('');
            });*/
        }
    }
}