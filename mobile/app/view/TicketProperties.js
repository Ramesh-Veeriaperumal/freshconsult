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
            items: [propeties,customerInfo]
        });
        this.add([tabs,details]);
    },
    populateCustomerData : function(res){
        var resJSON = JSON.parse(res.responseText);
        this.items.items[1].items.items[2].setData(resJSON.user);
    },
    showCustomerDetails:function(preventActive){
        var me=this;
        id=this.parent.parent.requester_id,
        opts = {
            url: '/contacts/'+id,
        };
        FD.Util.getJSON(opts,this.populateCustomerData,this);
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