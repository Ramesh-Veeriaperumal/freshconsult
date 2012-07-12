Ext.define('Freshdesk.view.ContactDetails', {
    extend: 'Ext.Container',
    alias: 'widget.contactDetails',
    initialize : function(){
        this.callParent(arguments);
        var me = this;
        var back = {
            xtype: 'button',
            text: 'Back',
            ui:'back headerBtn',
            handler: this.goBack,
            scope: this,
            align:'left'
        };      
        var TopTitlebar = {
            xtype: 'titlebar',
            title: 'Contact Info',
            docked: 'top',
            ui:'header',
            items: [
                back,
                { xtype: 'spacer' }
            ]
        };

        var contactForm = {
            xtype:'contactform',
        };
        var contactInfo = {
            xtype:'contactInfo'
        };     

        this.add([TopTitlebar,contactInfo]);
    },
    goBack: function(){
        Freshdesk.anim = {type:'slide',direction:'right'};
        Freshdesk.cancelBtn=true;
        history.back();
    },
    config: {
        scrollable:{
            direction:'vertical',
            directionLock:true
        },
        layout: { type: 'vbox', align: 'justify', pack: 'justify'  }
    }
});
