Ext.define('Freshdesk.view.TicketReply', {
    extend: 'Ext.Container',
    requires:['Ext.TitleBar'],
    alias: 'widget.ticketReply',
    initialize: function () {
        this.callParent(arguments);
        var me = this;
        var backButton = {
            text:'Cancel',
            xtype:'button',
            align:'left',
            ui:'headerBtn',
            handler:this.backToDetails,
            scope:this
        };

        var submitButton = {
            xtype:'button',
            align:'right',
            text:'Send',
            ui:'headerBtn',
            handler:this.send,
            scope:this
        }

        var topToolbar = {
            xtype: "titlebar",
            docked: "top",
            title:'Reply',
            ui:'header',
            items: [
                backButton,
                submitButton
            ]
        };
        var emailForm = {
            xtype : 'emailForm',
            padding:0,
            border:0,
            style:'font-size:1em',
            layout:'fit'
        };

        this.add([topToolbar,emailForm]);
    },
    backToDetails : function(){
        Freshdesk.cancelBtn=true;
        Freshdesk.anim = {type:'cover',direction:'down'};
        location.href="#tickets/show/"+this.ticket_id;
    },
    send : function(){
        var id = this.ticket_id,
            formObj = this.items.items[1],
            values = formObj.getValues();
        if(values["helpdesk_note[body_html]"].trim() != '') {
            Ext.Viewport.setMasked(true);
            formObj.submit({
                success:function(){
                    Ext.Viewport.setMasked(false);
                    location.href="#tickets/show/"+id;
                },
                failure:function(){
                    Ext.Viewport.setMasked(false);
                    var errorHtml='Please correct the bellow errors.<br/>';
                    for(var index in response.errors){
                        var error = response.errors[index],eNo= +index+1;
                        errorHtml = errorHtml+'<br/> '+eNo+'.'+error[0]+' '+error[1]
                    }
                    Ext.Msg.alert('Errors', errorHtml, Ext.emptyFn);
                }
            });
        }
    },
    getMessageItem: function(){
        return this.items.items[1].items.items[0].items.items[8];
    },
    config: {
        layout:'fit',
        id: 'ticketReplyForm'
    }
});