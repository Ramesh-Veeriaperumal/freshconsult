Ext.define('Freshdesk.store.AutoTechnician', {
    extend: 'Ext.data.Store',
    getTotalCount: function(){
        return this.totalCount;
    },
    config: {
        model: 'Freshdesk.model.AutoSuggestion',
        proxy: {
            type: 'ajax',
            url : '/helpdesk/authorizations/agent_autocomplete',
            headers: {
                'Accept': 'application/json'
            },
            reader: {
                type: 'json',
                rootProperty:'results'
            }
        }
    }
});