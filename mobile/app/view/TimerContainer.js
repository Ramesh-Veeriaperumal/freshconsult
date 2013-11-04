Ext.define('Freshdesk.view.TimerContainer', {
    extend: 'Ext.Container',
    requires:['Ext.TitleBar'],
    alias: 'widget.timerContainer',
    initialize: function () {
        this.callParent(arguments);
        var me =this;

        var backButton = {
            xtype:'button',
            text:'back',
			ui:'lightBtn back',
			handler:function(){ me.backToTicket() },
			align:'left'
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

        var newTimer = {
            ui:'headerBtn',
            iconCls:'add1',
            iconMask:true,
            xtype:'button',
            handler:this.newTimer,
            align:'right',
            scope:this
        };

		var topToolbar = {
			xtype: "titlebar",
			docked: "top",
            title: "Time Sheet",
            ui:'header',
			items: [backButton,newTimer]
		};

        var timesheet_list = {
            xtype:'timer',
            itemId : 'timer',
            store: Ext.getStore('Timers'),
            listeners:{
                itemtap:{
                    fn:this.onTimerDisclose,
                    scope:this
                },
                updatedata: {
                    fn:function(){
                        console.log(arguments)
                    }
                },

            },
        };


        this.add([topToolbar,timesheet_list]);
    },

    newTimer:function(){
        id = this.ticket_id;
        location.href = "#tickets/addTimer/"+id;
    },


    backToTicket: function(){
        var id = this.ticket_id;
        this.hide();
        location.href="#tickets/show/"+id;
    },

    onTimerDisclose: function(list, index, target, record, evt, options){
        location.href = "#tickets/editTimer/"+record.data.time_entry.id;
    },
    onDeleteButton: function(){
    	console.log('delete button');
    },
    config: {
        layout:'fit',
        cls:'timerContainer',
        itemId:'timerContainer'
    }
});
