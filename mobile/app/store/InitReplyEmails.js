Ext.define('Freshdesk.store.InitReplyEmails', {
    extend: 'Ext.data.Store',
    config: {
        model: 'Freshdesk.model.Portal',
        proxy: {
            type: 'ajax',
            url : '/mobile/tickets/load_reply_emails',
            headers: {
                'Accept': 'application/json'
            },
            reader: {
                type: 'json'
            }
        },
        autoLoad:false
    }
});