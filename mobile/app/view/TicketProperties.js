Ext.define("Freshdesk.view.TicketProperties", {
    extend: "Ext.Panel",
    alias: "widget.ticketPropterties",
    initialize : function(){
        this.callParent(arguments);
        var tab1 = {
                iconMask:true,
                iconCls:'doc2',
                ui:'plain',
                cls:'propeties',
                handler:function(){
                    this.showProperties(false);
                },
                scope:this
        },tab2 = {
                iconMask:true,
                iconCls:'user3',
                ui:'plain',
                cls:'customer',
                itemId:'ticketCustomerInfo',
                handler:function(){
                    this.showCustomerDetails(false);
                },
                scope:this
        },tabs = {
                xtype: "toolbar",
                docked: "top",
                ui:'subheader',
                pack:'justify',
                align:'center',
                items:[{xtype:'spacer'},tab1,tab2,{xtype:'spacer'}]
        },propeties = {
                itemId:'ticketForm',
                xtype: 'ticketform',
                padding:0,
                border:0,
                style:'font-size:1em',
                layout:'fit',
                scrollable:true,
                id:'ticketProperties'
        },customerInfo = {
                xtype:'contactInfo',
        },
        details = Ext.create('Ext.Carousel', {
            defaults: {
                styleHtmlContent: true,
                layout:'hbox'
            },
            flex:1,
            //hack for disabling drag
            direction:'horiz',
            directionLock:true,
            listeners : {
                activeitemchange: function(me,activeItem,prevActiveItem,opts){
                    switch (activeItem._itemId) {
                        case 'ticketForm' :
                            me.parent.showProperties(true);
                            break;
                        case 'customerInfo':
                            me.parent.showCustomerDetails(true);
                            break;
                    }
                }
            },
            items: [propeties,customerInfo]
        });
        this.add([tabs,details]);
    },
    showCustomerDetails:function(preventActive){
        var me=this;
        id=this.parent.parent.ticket_id;
        Ext.Ajax.request({
            url: '/mobile/tickets/requester_info/'+id,
            headers: {
                "Accept": "application/json"
            },
            success: function(response) {
                var resJSON = JSON.parse(response.responseText);
                me.items.items[1].items.items[2].setData(resJSON);
            },
            failure: function(response){
            }
        });

        this.addCls('customer');
        if(!preventActive)
            this.items.items[1].setActiveItem(1);
    },
    showProperties : function(preventActive){
        this.removeCls('customer');
        if(!preventActive)
            this.items.items[1].setActiveItem(0);
    },
    config: {
        cls:'ticketProperties',
        padding:0
    }
});