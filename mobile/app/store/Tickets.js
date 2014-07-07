Ext.define('Freshdesk.store.Tickets', {
    extend: 'Ext.data.Store',
    getTotalCount: function(){
        return this.totalCount;
    },
    setTotalCount: function(count){
        if(count){
            this.totalCount = count;
        }
    },
    config: {
        model: 'Freshdesk.model.Ticket',
        proxy: {
            type: 'ajax',
            url : '/helpdesk/tickets/',
            headers: {
                'Accept': 'application/json'
            },
            reader: {
                type: 'json'
            }
        },
        pageSize:30
    }
});