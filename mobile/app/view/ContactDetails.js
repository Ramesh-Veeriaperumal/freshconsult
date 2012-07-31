Ext.define('Freshdesk.view.ContactDetails', {
    extend: 'Ext.Container',
    alias: 'widget.contactDetails',
    initialize : function(){
        this.callParent(arguments);
        var me = this;
        var back = {
            xtype: 'button',
            text: 'Back',
            ui:'back lightBtn',
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
            xtype:'contactInfo',
            listeners : {
                element : 'element',
                delegate : 'a',
                tap : function(e, item) {
                    var hrefParent = Ext.get(item).findParent('a');
                    if(hrefParent && hrefParent.getAttribute('href')){
                        location.href=hrefParent.getAttribute('href');
                    }
                }
            }
        };     

        this.add([TopTitlebar,contactInfo]);
    },
    goBack: function(){
        Freshdesk.anim = {type:'slide',direction:'right'};
        Freshdesk.cancelBtn=true;
        history.back();
    },
    config: {
        id:'contactDetails',
        scrollable:{
            direction:'vertical',
            directionLock:true
        },
        layout: { type: 'vbox', align: 'justify', pack: 'justify'  }
    }
});
