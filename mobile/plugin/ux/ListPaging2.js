Ext.define('plugin.ux.ListPaging2', {
    extend: 'Ext.plugin.ListPaging',
    alias: 'ListPaging2',
    config: {
        /*fullyloadedCls used to set when no more records are there to paginate*/
        fullyloadedCls : Ext.baseCSSPrefix + 'completed'
    },

    initialize: function() {
        this.callParent();
    },

    /**
    * Overridding onStoreLoad
    *
    */
    onStoreLoad : function(store){

        var loadCmp  = this.addLoadMoreCmp(),
            storeFullyLoaded = this.storeFullyLoaded(),
            fullyloadedCls = this.getFullyloadedCls();
        loadCmp.removeCls(fullyloadedCls);
        this.callParent(store);

        if(storeFullyLoaded){
            loadCmp.addCls(fullyloadedCls);
        }
    }
});
