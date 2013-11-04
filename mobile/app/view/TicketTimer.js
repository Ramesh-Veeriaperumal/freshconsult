Ext.define('Freshdesk.view.TicketTimer', {
    extend: 'Ext.Container',
    requires:['Ext.TitleBar'],
    alias: 'widget.ticketTimer',
    initialize: function () {
        this.callParent(arguments);
        var me = this;
        var backButton = {
            text:'Cancel',
            xtype:'button',
            ui:'lightBtn',
            align:'left',
            handler:this.backToDetails,
            scope:this
        };

        var submitButton = {
            xtype:'button',
            align:'right',
            text:'Save',
            ui:'headerBtn',
            handler:this.send,
            scope:this
        };

        var updateButton = {
            xtype:'button',
            align:'right',
            text:'Update',
            ui:'headerBtn',
            handler:this.update,
            //hidden:true,
            scope:this
        };

        var topToolbar = {
            xtype: "titlebar",
            docked: "top",
            title:'Add TicketTimer',
            ui:'header',
            items: [
                backButton,
                updateButton,
                submitButton
            ]
        };
        var timerForm = {
            xtype : 'timerForm',
            padding:0,
            border:0,
            style:'font-size:1em',
            listeners : {
                painted : function(self){
                    //For setting scroll..
                    Ext.Function.defer(function(container){
                        container.getScrollable().getScroller().scrollToTop(true)
                    },100,this,[self],true)
                }
            },
        };

        this.add([topToolbar,timerForm]);
    },
    backToDetails : function(){
        this.hide();
        window.already_loaded = true;
        location.href="#tickets/timer/"+this.ticket_id;
    },
    send : function(){
        var id = this.ticket_id,
        formObj = this.items.items[1],
        values = formObj.getValues();
        var time_entry_time = formObj.items.items[0].items.items[1].getValue();
        time_entry_time_validity = FD.Util.validate_time_entry(time_entry_time);
        if(!time_entry_time_validity){
            var errorHtml='Please enter the time entry in correct format.<br/>';
            Ext.Msg.alert('Errors', errorHtml, Ext.emptyFn);
            return false;
        }
            Ext.Viewport.setMasked(true);
            formObj.submit({
                success:function(form,resp){
                    this.parent.hide();
                    Ext.Viewport.setMasked(false);
                    location.href="#tickets/timer/"+id;
                },
                failure:function(form,response){
                    Ext.Viewport.setMasked(false);
                    var errorHtml='Please correct the below errors.<br/>';
                    for(var index in response.errors){
                        var error = response.errors[index],eNo= +index+1;
                        errorHtml = errorHtml+'<br/> '+eNo+'.'+error[0]+' '+error[1]
                    }
                    Ext.Msg.alert('Errors', errorHtml, Ext.emptyFn);
                },
                headers : { 'Accept': 'application/json' }
            });
    },
    update : function(){
        var id = this.ticket_id;
        formObj = this.items.items[1],
        values = formObj.getValues();
        var time_entry_time = formObj.items.items[0].items.items[1].getValue();
        time_entry_time_validity = FD.Util.validate_time_entry(time_entry_time);
        if(!time_entry_time_validity){
            var errorHtml='Please enter the time entry in correct format.<br/>';
            Ext.Msg.alert('Errors', errorHtml, Ext.emptyFn);
            return false;
        }
            Ext.Viewport.setMasked(true);
            formObj.submit({
                success:function(){
                    this.parent.hide();
                    Ext.Viewport.setMasked(false);
                    location.href="#tickets/timer/"+id;
                },
                failure:function(form,response){
                    Ext.Viewport.setMasked(false);
                    var errorHtml='Please correct the below errors.<br/>';
                    for(var index in response.errors){
                        var error = response.errors[index],eNo= +index+1;
                        errorHtml = errorHtml+'<br/> '+eNo+'.'+error[0]+' '+error[1]
                    }
                    Ext.Msg.alert('Errors', errorHtml, Ext.emptyFn);
                },
                headers : { 'Accept': 'application/json' }
            });
    },
    getMessageItem: function(){
        return this.items.items[1].items.items[0].items.items[4];
    },
    config: {
        layout:'fit',
        id: 'ticketTimerForm',
        showAnimation : {
            type:'slide',
            direction:'left',
            easing:'ease-in-out'
        },
        hideAnimation: {
                type:'slide',
                direction:'right',
                easing:'ease-in-out'
        },
        zIndex:9
    }
});