Ext.define('Freshdesk.view.ContactsListContainer', {
    extend: 'Ext.Container',
    requires:['Ext.TitleBar','Ext.field.Search','Ext.plugin.PullRefresh','Ext.plugin.ListPaging'],
    alias: 'widget.contactsListContainer',
    initialize: function () {
        this.callParent(arguments);

        var backButton = {
            text:'Home',
            ui:'lightBtn back',
            xtype:'button',
            handler:this.backToDashboard,
            align:'left',
            maxHeight:80
        };

		var newButton = {
			xtype:'button',
            ui:'headerBtn',
			iconMask:true,
			iconCls:'add1',
			handler:this.onNewButton,
			align:'right',
            maxHeight:'80%'
		};

        
		var topToolbar = {
			xtype: "titlebar",
            title: "All Contacts",
			docked: "top",
            ui:'header',
			items: [
				backButton,
				newButton 
			]
		};

		var contactsList = {
            xtype:'contactslist',
            store: Ext.getStore('Contacts'),
            listeners:{
                itemtap:{
                    fn:this.showDetails,
                    scope:this
                }
            },
            plugins: [
                    {
                        xclass: 'Ext.plugin.ListPaging',
                        autoPaging: true,
                        centered:true,
                        loadMoreText: '',
                        noMoreRecordsText: ''
                    }
            ]
        };
		this.add([topToolbar,contactsList]);
    },
    showDetails: function(list, index, target, record, evt, options){
        setTimeout(function(){list.deselect(index);},500);
        location.href="#contacts/show/"+record.raw.user.id;
    },
    backToDashboard: function(){
    	location.href='#dashboard';
    },
    onNewButton: function(){
        location.href="#contacts/new";
    },
    config: {
        layout:'fit'
    }
});
