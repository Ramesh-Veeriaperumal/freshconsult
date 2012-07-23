Ext.define('Freshdesk.store.Init', {
    extend: 'Ext.data.Store',
    config: {
        model: 'Freshdesk.model.Portal',
        proxy: {
            type: 'ajax',
            url : '/mobile/tickets/get_portal',
            headers: {
                'Accept': 'application/json'
            },
            reader: {
                type: 'json'
            }
        },
        autoLoad:false,
        listeners : {
            beforeload : {
                fn: function(){
                    Ext.Viewport.setMasked({xtype:'mask',html:'<div class="x-loading-spinner" style="font-size: 180%; margin: 10px auto;"><span class="x-loading-top"></span><span class="x-loading-right"></span><span class="x-loading-bottom"></span><span class="x-loading-left"></span></div>',style:'background:rgba(255,255,255,0.1)'});
                },
                scope:this
            }
        }
    }
});