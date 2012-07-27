var FD = FD || {};
FD.Util = {
    DEFAULT_DATE_FORMAT : 'mmm d @ h:MM TT',
    onAjaxSucess : function(data,res,callBack,scope){
        callBack.call(scope,res);
    },
    onAjaxFailure: function(data,res,callBack){
        if(res.status == 302) {
                window.location = JSON.parse(res.responseText).Location;
        }
        else{
            Ext.Msg.alert('Some thing went wrong!', "We are sorry . Some thing went wrong! Our technical team is looking into it.");
        }
    },
    onAjaxCallback : function(data, operation, res, callBack, scope){
        Ext.Viewport.setMasked(false);
        operation ? this.onAjaxSucess(data,res,callBack,scope) : this.onAjaxFailure(data,res,callBack,scope)
    },
    ajax : function(options,callBack,scope,showMask){
        if(showMask !== false) {
            Ext.Viewport.setMasked(true);
        }
        var me = this;
        options.callback = function(data,operation,success){
            me.onAjaxCallback(data,operation,success,callBack,scope)
        }
        Ext.Ajax.request(options);
    },
    getJSON : function(options,callBack,scope){
        options.method = "GET";
        options.headers = {
            "Accept": "application/json"
        };
        this.ajax(options,callBack,scope);
    },
	reBrand: function(data){
		Ext.Viewport.getAt(1).setBranding(data);
	},
	initCustomer : function(){
		//initializing customer login settings..
		//Ext.ComponentQuery.query('#ticketCustomerInfo')[0].hide();
        Ext.ComponentQuery.query('#noteFormCannedResponse')[0].hide();
        Ext.ComponentQuery.query('#noteFormPrivateField')[0].hide();
        Ext.ComponentQuery.query('#noteFormNotifyField')[0].hide();
	},
	showAll : function(id){
		//To show full content in conversation section..
		document.getElementById(id).setAttribute('class','conv');
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
		var formData = isEdit ? [{xtype:'hiddenfield',name:'_method',value:'put'}] : [{xtype:'hiddenfield',name:'commit',value:'Save'}],
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
        item.value = field.nested_levels && field.field_value ? field.field_value.category_val : field.field_value;
        item.id = "helpdesk_ticket_"+field_name;
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
                item.checked=field.field_value;
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
    },
    formatedDate : function(timeStr){
        var date = this.convertoJSDate(timeStr);
        return dateFormat(date, this.DEFAULT_DATE_FORMAT);
    },
    humaneDate : function(timeStr){
        return this.convertoJSDate(timeStr).toRelativeTime();
    },
    convertoJSDate : function(timeStr){
        var limit;
        timeStr = ( timeStr || '' ).replace(/-/g,"/").replace(/[TZ]/g," ");
        limit = timeStr.lastIndexOf('+') > 0 ? timeStr.lastIndexOf('+') : timeStr.length;
        return new Date(timeStr.substr(0,limit));
    },
    switchToClassic : function(){
        this.cookie.setItem('classic_view',true,null,'/');
        document.location.href="/";
    },
    cookie : {
        getItem: function (sKey) {
            if (!sKey || !this.hasItem(sKey)) { return null; }
            return unescape(document.cookie.replace(new RegExp("(?:^|.*;\\s*)" + escape(sKey).replace(/[\-\.\+\*]/g, "\\$&") + "\\s*\\=\\s*((?:[^;](?!;))*[^;]?).*"), "$1"));
        },
        /**
        * docCookies.setItem(sKey, sValue, vEnd, sPath, sDomain, bSecure)
        *
        * @argument sKey (String): the name of the cookie;
        * @argument sValue (String): the value of the cookie;
        * @optional argument vEnd (Number, String, Date Object or null): the max-age in seconds (e.g., 31536e3 for a year) or the
        *  expires date in GMTString format or in Date Object format; if not specified it will expire at the end of session; 
        * @optional argument sPath (String or null): e.g., "/", "/mydir"; if not specified, defaults to the current path of the current document location;
        * @optional argument sDomain (String or null): e.g., "example.com", ".example.com" (includes all subdomains) or "subdomain.example.com"; if not
        * specified, defaults to the host portion of the current document location;
        * @optional argument bSecure (Boolean or null): cookie will be transmitted only over secure protocol as https;
        * @return undefined;
        **/
        setItem: function (sKey, sValue, vEnd, sPath, sDomain, bSecure) {
            if (!sKey || /^(?:expires|max\-age|path|domain|secure)$/.test(sKey)) { return; }
            var sExpires = "";
            if (vEnd) {
                switch (typeof vEnd) {
                    case "number": sExpires = "; max-age=" + vEnd; break;
                    case "string": sExpires = "; expires=" + vEnd; break;
                    case "object": if (vEnd.hasOwnProperty("toGMTString")) { sExpires = "; expires=" + vEnd.toGMTString(); } break;
                }
            }
            document.cookie = escape(sKey) + "=" + escape(sValue) + sExpires + (sDomain ? "; domain=" + sDomain : "") + (sPath ? "; path=" + sPath : "") + (bSecure ? "; secure" : "");
        },
        removeItem: function (sKey) {
        if (!sKey || !this.hasItem(sKey)) { return; }
            var oExpDate = new Date();
            oExpDate.setDate(oExpDate.getDate() - 1);
            document.cookie = escape(sKey) + "=; expires=" + oExpDate.toGMTString() + "; path=/";
        },
        hasItem: function (sKey) { 
            return (new RegExp("(?:^|;\\s*)" + escape(sKey).replace(/[\-\.\+\*]/g, "\\$&") + "\\s*\\=")).test(document.cookie); 
        }
    },
    setAgentOptions : function(options){
        var responderObj = Ext.getCmp('helpdesk_ticket_responder_id');
        responderObj.setOptions(options);
    },
    populateAgents : function(comp){
        var group_id = comp.getValue(),
            callBack = function(res){
            var data = JSON.parse(res.responseText),
            options = [{text:'...',value:''}];
            data.forEach(function(agent){
                options.push({text:agent.name,value:agent.id})
            });
            if(options.length === 1 ){
                options = [{text:'No agents in selected group',value:''}];
            }
            FD.Util.setAgentOptions(options)
        };
        if(group_id){
            FD.Util.getJSON({
                url:'/helpdesk/tickets/get_agents/'+group_id
            },callBack,this,false);
        }
        else {
            FD.Util.setAgentOptions(FD.all_responders)
        }
    }
}