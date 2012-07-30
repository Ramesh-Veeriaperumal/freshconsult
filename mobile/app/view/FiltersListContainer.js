Ext.define('Freshdesk.view.FiltersListContainer', {
    extend: 'Ext.Container',
    alias: 'widget.filtersListContainer',
    initialize : function(){
        this.callParent(arguments);
        
        var backButton = {
            text:'Home',
            ui:'lightBtn back',
            xtype:'button',
            handler:this.showHome,
            align:'left'
        };

        var contacts = {
            ui:'headerBtn',
            iconCls:'user_list2',
            iconMask:true,
            xtype:'button',
            handler:this.showContacts,
            align:'right'
        };

        var newTicket = {
            ui:'headerBtn',
            iconCls:'add1',
            iconMask:true,
            xtype:'button',
            handler:this.newTicket,
            align:'right',
            scope:this
        };

        var topToolbar = {
            xtype: "titlebar",
            title: "Ticket Views",
            docked: "top",
            ui:'header',
            items: [
                { xtype: 'spacer' },
                backButton,
                newTicket
            ]
        };

        var filtersList = {
            xtype:'filterslist',
            store: Ext.getStore('Filters'),
            listeners:{
                itemtap:{
                    fn:this.onFiltersListDisclose,
                    scope:this
                }
            },
            plugins: [
                    {
                        xclass: 'plugin.ux.PullRefresh2',
                        pullRefreshText: 'Pull down to refresh...',
                        prettyUpdatedDate:true
                    }
            ]
        }
        this.add([topToolbar,filtersList]);
    },
    onFiltersListDisclose: function(list, index, target, record, evt, options){
        setTimeout(function(){list.deselect(index);},500);
        if(record.raw.count){
            this.filter_title = record.raw.name;
            Ext.getStore('Tickets').totalCount = record.raw.count;
            Ext.getStore('Tickets').setTotalCount(record.raw.count);
            if(record.data.company){
                location.href="#company_tickets/filters/"+record.data.type+'/'+record.data.id;
            }
            else{
                location.href="#filters/"+record.data.type+'/'+record.data.id;    
            }
            
        }
    },
    populateTicketProperties : function(res) {
        var resJson = JSON.parse(res.responseText),
            anim = {type:'cover',direction:'up'},
            formContainer = Ext.getCmp('newTicketForm'),
            formListeners = {
                change:function(select_field){
                    FD.Util.enable_nested_field(select_field);
                    formContainer.enableAddBtn();
                },
                check:function(){formContainer.enableAddBtn()},
                uncheck:function(){formContainer.enableAddBtn()},
                focus:function(){formContainer.enableAddBtn()}
            }
            formData = FD.Util.construct_ticket_form(resJson,false,formListeners),
            formObj = formContainer.items.items[1];
        formObj.items.items[0].setItems(formData);
        formObj.setUrl('/helpdesk/tickets');
        if(FD.current_user.is_customer)  {
            formObj.setUrl('/support/tickets')
        }

        try {
            FD.all_responders = Ext.getCmp('helpdesk_ticket_responder_id').getOptions(); 
            Ext.getCmp('helpdesk_ticket_group_id').addListener('change',FD.Util.populateAgents);    
        }
        catch(e){

        }
        
        Ext.Viewport.animateActiveItem(formContainer, anim);
    },
    newTicket : function(){
        var me=this,
            formContainer = Ext.getCmp('newTicketForm'),
            opts = {
                url: '/mobile/tickets/ticket_properties'
            };
        formContainer.disableAddBtn();
        FD.Util.getJSON(opts,this.populateTicketProperties,this);
    },
    showContacts : function(){
        location.href ='#dashboard/contacts';
    },
    showHome: function(){
        Ext.Viewport.animateActiveItem(Ext.ComponentQuery.query('#home')[0], {type:'slide',direction:'right'});
    },
    config: {
        layout:'fit',
        fullscreen:true,
        id:'filterList'
    }
});
