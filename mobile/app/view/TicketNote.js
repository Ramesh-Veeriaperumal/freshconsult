Ext.define('Freshdesk.view.TicketNote', {
    extend: 'Ext.Container',
    requires:['Ext.TitleBar'],
    alias: 'widget.ticketNote',
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
        }

        var topToolbar = {
            xtype: "titlebar",
            docked: "top",
            title:'Add Note',
            ui:'header',
            items: [
                backButton,
                submitButton
            ]
        };
        var emailForm = {
            xtype : 'noteForm',
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

        this.add([topToolbar,emailForm]);
    },
    backToDetails : function(){
        this.hide();
        Freshdesk.cancelBtn=true;
        Freshdesk.anim = {type:'cover',direction:'down'};
        location.href="#tickets/show/"+this.ticket_id;
    },
    send : function(){
        var id = this.ticket_id,
        formObj = this.items.items[1],
        values = formObj.getValues(),
        privateObj = Ext.ComponentQuery.query('#noteFormPrivateField')[0];
        if(values["helpdesk_note[body]"].trim() != '') {
            if(FD.current_user.is_agent){
                //Ext.ComponentQuery.query('#noteFormPrivateField')[0].setValue(!!!privateObj.getValue()[0]);
            }
            Ext.Viewport.setMasked(true);
            formObj.submit({
                success:function(){
                    this.parent.hide();
                    Ext.Viewport.setMasked(false);
                    Freshdesk.notification={
                        success : "The note has been added."
                    };
                    location.href="#tickets/show/"+id;
                },
                failure:function(form,response){
                    Ext.Viewport.setMasked(false);
                    var errorHtml='Please correct the bellow errors.<br/>';
                    for(var index in response.errors){
                        var error = response.errors[index],eNo= +index+1;
                        errorHtml = errorHtml+'<br/> '+eNo+'.'+error[0]+' '+error[1]
                    }
                    Ext.Msg.alert('Errors', errorHtml, Ext.emptyFn);
                },
                headers : { 'Accept': 'application/json' }
            });
        }
    },
    getMessageItem: function(){
        return this.items.items[1].items.items[0].items.items[4];
    },
    config: {
        layout:'fit',
        id: 'ticketNoteForm',
        showAnimation : {
            type:'slideIn',
            direction:'up',
            easing:'ease-in-out'
        },
        hideAnimation: {
                type:'slideOut',
                direction:'down',
                easing:'ease-in-out'
        },
        zIndex:9
    }
});