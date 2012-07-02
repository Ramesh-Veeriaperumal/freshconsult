Ext.define('Freshdesk.view.TicketDetailsContainer', {
    extend: 'Ext.Container',
    requires:['Ext.TitleBar','Ext.Carousel'],
    alias: 'widget.ticketDetailsContainer',
    initialize: function () {
        this.callParent(arguments);
        var me =this;

        var backButton = {
            xtype:'button',
            text:'List',
			ui:'headerBtn back',
			handler:function(){ this.backToConversation ? me.toggleProperties() : me.backToListView()},
			align:'left'
		};

		var trashButton = {
			iconMask:true,
			iconCls:'trash',
            ui:'plain',
			handler:this.onDeleteButton,
			align:'right'
		};


        var updateBtn = Ext.create('Ext.Button',{
            xtype:'button',
            text:'Update',
            handler:this.updateProperties,
            align:'right',
            scope:this,
            hidden:true,
            ui:'headerBtn',
            disabled:true
        });

        var toggleBtn = Ext.create('Ext.Button',{
            xtype:'button',
            iconMask:true,
            iconCls:'info',
            ui:'headerBtn',
            handler:this.toggleProperties,
            align:'right',
            scope:this
        });

		var topToolbar = {
			xtype: "titlebar",
			docked: "top",
            title: "Ticket :",
            ui:'header',
			items: [backButton,toggleBtn,updateBtn]
		};

        var ticketDetails = {
            xtype:'ticketdetails',
            itemId : 'ticketDetails'
        };

        var ticketProperties = {
            xtype:'ticketPropterties',
            itemId : 'ticketProperties'
        };

        var details = Ext.create('Ext.Carousel', {
            defaults: {
                styleHtmlContent: true,
                layout:'hbox',
                padding:0
            },
            flex:1,
            //hack for disabling drag
            direction:'horiz',
            directionLock:true,
            listeners : {
                activeitemchange: function(me,activeItem,prevActiveItem,opts){
                    switch (activeItem._itemId) {
                        case 'ticketDetails' :
                            me.parent.showCoversations(false);
                            break;
                        case 'ticketProperties' :
                            me.parent.showProperties(false);
                            break;
                    }
                }
            },
            items: [ticketDetails,ticketProperties]
        });
        this.add([topToolbar,details]);
    },
    showCoversations:function(setActive){
        var detailsPane = this.items.items[1],
        titleBarItems = this.getItems().items[0].getItems().items[0].getItems(),
        iconBtn = this.getItems().items[0].getItems().items[2].getItems().items[0],
        updateBtn = this.getItems().items[0].getItems().items[2].getItems().items[1];
        updateBtn.hide(true);
        iconBtn.show();
        titleBarItems.items[0].backToConversation=false;
        titleBarItems.items[0].setText('List');
        if(setActive)
            detailsPane.setActiveItem(0);
    },
    showProperties: function(setActive){
        var detailsPane = this.items.items[1],
        activeIndex = detailsPane.getActiveIndex(),
        toggledIndx = +!Boolean(activeIndex),id=this.ticket_id,me=this,
        titleBarItems = this.getItems().items[0].getItems().items[0].getItems(),
        iconBtn = this.getItems().items[0].getItems().items[2].getItems().items[0],
        updateBtn = this.getItems().items[0].getItems().items[2].getItems().items[1],
        me = this;
        formListeners = {
                change:function(select_field){
                    FD.Util.enable_nested_field(select_field);
                    me.enableUpdateBtn();
                },
                check:function(){me.enableUpdateBtn()},
                uncheck:function(){me.enableUpdateBtn()},
                focus:function(){me.enableUpdateBtn()}
        };

        iconBtn.hide(true);
        updateBtn.show();
        this.disableUpdateBtn();
        titleBarItems.items[0].setText('Back');
        titleBarItems.items[0].backToConversation=true;

        Ext.Ajax.request({
            url: '/mobile/tickets/ticket_properties/'+id,
            headers: {
                "Accept": "application/json"
            },
            success: function(response) {
                var resJson = JSON.parse(response.responseText),
                formData = FD.Util.construct_ticket_form(resJson,true,formListeners),
                formObj = me.items.items[1].items.items[2].items.items[1].items.items[1];
                formObj.items.items[0].setItems(formData);
                formObj.setUrl('/helpdesk/tickets/'+id);
                if(FD.current_user.is_customer) 
                    formObj.setUrl('/support/tickets/'+id)

                if(setActive)
                    detailsPane.setActiveItem(toggledIndx);
                me.items.items[1].items.items[2].items.items[1].setActiveItem(0);
                me.items.items[1].items.items[2].showProperties();
            },
            failure: function(response){
            }
        });
    },
    toggleProperties: function(){
        var detailsPane = this.items.items[1],
        activeIndex = detailsPane.getActiveIndex(),
        toggledIndx = +!Boolean(activeIndex),id=this.ticket_id;
        if(toggledIndx){
            this.showProperties(true);
        }
        else{
            this.showCoversations(true);
        }
    },
    serializeFormData: function(baseData){
        var formData = [{xtype:'hiddenfield',name:'_method',value:'put'}],key,ticket_field;
        for(key in baseData){
            ticket_field = baseData[key]['ticket_field'];
            formData.push(this.getFormItem(ticket_field));
        }
        return formData;
    },
    getFormItem : function(field){
        var item = {options:[]},choices,opt,key,
        field_name = field.field_name;
        item.label = field.label;
        item.name = field.is_default_field ? 'helpdesk_ticket['+field_name+']' : 'helpdesk_ticket[custom_field]['+field_name+']';
        item.required = field.required;
        item.value = field.field_value,me=this;

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
        item.listeners = {
            change:function(){me.enableUpdateBtn()},
            check:function(){me.enableUpdateBtn()},
            uncheck:function(){me.enableUpdateBtn()},
            focus:function(){me.enableUpdateBtn()}
        };
        return item;
    },
    enableUpdateBtn : function(){
        this.getItems().items[0].getItems().items[2].getItems().items[1].enable();
    },
    disableUpdateBtn : function(){
        this.getItems().items[0].getItems().items[2].getItems().items[1].disable();
    },
    backToListView: function(){
        Freshdesk.backBtn=true;
        var ticketListContainer = Ext.ComponentQuery.query('#ticketListContainer')[0],
        type = ticketListContainer.filter_type || 'filter',
        id = ticketListContainer.filter_id || 'all_tickets';
        location.href="#filters/"+type+"/"+id;
    },
    updateProperties : function(){
        var formObj = this.items.items[1].items.items[2].items.items[1].items.items[1],id=this.ticket_id,me=this;
        formObj.submit({
            success:function(form,response){
                me.toggleProperties();
            },
            failure:function(form,response){
                var errorHtml='Please correct the bellow errors.<br/>';
                for(var index in response.errors){
                    var error = response.errors[index],eNo= +index+1;
                    errorHtml = errorHtml+'<br/> '+eNo+'.'+error[0]+' '+error[1]
                }
                Ext.Msg.alert('Errors', errorHtml, Ext.emptyFn);
            }
        });
    },
    onDeleteButton: function(){
    	console.log('delete button');
    },
    config: {
        layout:'vbox',
        cls:'ticketDetails'
    }
});
