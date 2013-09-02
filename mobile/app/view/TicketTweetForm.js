Ext.define('Freshdesk.view.TicketTweetForm', {
    extend: 'Ext.Container',
    requires:['Ext.TitleBar'],
    alias: 'widget.ticketTweetForm',
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
            text:'Tweet',
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

        var tweetForm = {
            xtype : 'tweetForm',
            padding:0,
            border:0,
            style:'font-size:1em',
            layout:'fit'
        };

        this.add([topToolbar,tweetForm]);
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
            values = formObj.getValues();
        if(values["helpdesk_note[body]"] != '') {
            Ext.Viewport.setMasked(true);
            formObj.submit({
                success:function(){
                    this.parent.hide();
                    Ext.Viewport.setMasked(false);
                    location.href="#tickets/show/"+id;
                },
                failure:function(){
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
        }
    },
    config: {
        layout:'fit',
        id: 'ticketTweetForm',
        showAnimation : {
            type:'slideIn',
            direction:'up',
            easing:'ease-out'
        },
        hideAnimation: {
                type:'slideOut',
                direction:'down',
                easing:'ease-out'
        },
        zIndex:9
    }
});