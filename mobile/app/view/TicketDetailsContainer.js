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
			ui:'lightBtn back',
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
            iconCls:'info icon-list-3',
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
    populateProperties : function(res,setActive){
        var resJson = JSON.parse(res.responseText),
        me = this,
        id = this.ticket_id,
        detailsPane = this.items.items[1],
        activeIndex = detailsPane.getActiveIndex(),
        toggledIndx = +!Boolean(activeIndex),
        formListeners = {
                change:function(select_field){
                    FD.Util.enable_nested_field(select_field);
                    me.enableUpdateBtn();
                },
                check:function(){me.enableUpdateBtn()},
                uncheck:function(){me.enableUpdateBtn()},
                focus:function(){me.enableUpdateBtn()}
        },
        formData = FD.Util.construct_ticket_form(resJson,true,formListeners),
        formObj = this.items.items[1].items.items[2].items.items[1].items.items[1];
        formObj.items.items[0].setItems(formData);
        formObj.setUrl('/helpdesk/tickets/'+id);
        if(FD.current_user.is_customer) 
            formObj.setUrl('/support/tickets/'+id)

        if(setActive){
            detailsPane.setActiveItem(toggledIndx);
            this.items.items[1].items.items[2].items.items[1].setActiveItem(0);
            this.items.items[1].items.items[2].showProperties();
        }
        
        try {
            FD.all_responders = Ext.getCmp('helpdesk_ticket_responder_id').getOptions(); 
            Ext.getCmp('helpdesk_ticket_group_id').addListener('change',FD.Util.populateAgents);
        }
        catch(e){

        }
        
 
    },
    showProperties: function(setActive){
        var detailsPane = this.items.items[1],
        activeIndex = detailsPane.getActiveIndex(),
        toggledIndx = +!Boolean(activeIndex),id=this.ticket_id,me=this,
        titleBarItems = this.getItems().items[0].getItems().items[0].getItems(),
        iconBtn = this.getItems().items[0].getItems().items[2].getItems().items[0],
        updateBtn = this.getItems().items[0].getItems().items[2].getItems().items[1],
        me = this,
        opts = {
            url: '/mobile/tickets/ticket_properties/'+id,
        },
        callBack = function(res){
            this.populateProperties(res,setActive);
        };

        iconBtn.hide(true);
        updateBtn.show();
        this.disableUpdateBtn();
        titleBarItems.items[0].setText('Back');
        titleBarItems.items[0].backToConversation=true;

        FD.Util.getJSON(opts,callBack,this);
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
    enableUpdateBtn : function(){
        this.getItems().items[0].getItems().items[2].getItems().items[1].enable();
    },
    disableUpdateBtn : function(){
        this.getItems().items[0].getItems().items[2].getItems().items[1].disable();
    },
    backToListView: function(){
        var ticketListContainer = Ext.ComponentQuery.query('#ticketListContainer')[0],
        type = ticketListContainer.filter_type || 'filter',
        id = ticketListContainer.filter_id || 'all_tickets';
        if(ticketListContainer.filter_type){
            Freshdesk.backBtn=true;
        }
        location.href="#filters/"+type+"/"+id;
    },
    updateProperties : function(){
        var formObj = this.items.items[1].items.items[2].items.items[1].items.items[1],id=this.ticket_id,me=this,
        id = this.ticket_id;
        Ext.Viewport.setMasked(true);
        formObj.submit({
            success:function(form,response){
                me.toggleProperties();
                Ext.Viewport.setMasked(false);
                Freshdesk.notification={
                    success : "The ticket has been updated."
                };
                location.href="#tickets/reload/"+id;
            },
            failure:function(form,response){
                Ext.Viewport.setMasked(false);
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
