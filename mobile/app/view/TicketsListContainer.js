Ext.define('Freshdesk.view.TicketsListContainer', {
    extend: 'Ext.Container',
    requires:['Ext.TitleBar'],
    alias: 'widget.ticketsListContainer',
    initialize: function () {
        this.callParent(arguments);

        var backButton = {
        	text:'Views',
			ui:'headerBtn back',
			xtype:'button',
			handler:this.backToFilters,
			align:'left'
		};
        

		var topToolbar = {
			xtype: "titlebar",
			docked: "top",
            title:'All Tickets',
            ui:'header',
			items: [
				backButton
			]
		};

		var ticketsList = {
            xtype:'ticketslist',
            store: Ext.getStore('Tickets'),
            listeners:{
                itemtap:{
                    fn:this.onTicketDisclose,
                    scope:this
                },
                //Quick actions related events
                beforeOptionsrender:{
                    fn:this.setSwipeOptions,
                    scope:this
                },
                beforelistoptionstap: function() {
                    return true;
                },
                menuoptiontap: {
                    fn:this.onMenuOptionTap,
                    scope:this
                },
                updatedata: {
                    fn:function(){
                        console.log(arguments)
                    }
                }
            },
            plugins: [
                    {
                        xclass: 'plugin.ux.PullRefresh2',
                        pullRefreshText: 'Pull down for more!',
                        prettyUpdatedDate:true
                    },
                    {
                        xclass: 'plugin.ux.ListPaging2',
                        autoPaging: false,
                        centered:true,
                        loadMoreText: 'Load more.',
                        noMoreRecordsText: 'No more tickets.'
                    }
            ]
        };
		this.add([topToolbar,ticketsList]);
    },
    showListLoading : function(){
        this.items.items[1].setMasked({xtype:'mask',html:'<div class="x-loading-spinner" style="font-size: 180%; margin: 10px auto;"><span class="x-loading-top"></span><span class="x-loading-right"></span><span class="x-loading-bottom"></span><span class="x-loading-left"></span></div>',style:'background:rgba(255,255,255,0.1)'});
    },
    refreshListView : function(){
        Ext.getStore("Tickets").setData(undefined);
        Ext.getStore("Tickets").load();
    },
    moveToTrash : function(data){
        var id = data.display_id;
        Ext.Msg.confirm('Move to trash ticket : '+id,'Do you want to move this ticket to Trash?',
            function(btnId){
                if(btnId == 'no' || btnId == 'cancel'){
                    //do nothing..
                }
                else{
                    var opts = {
                       url: '/helpdesk/tickets/'+id,
                        params:{
                            '_method':'delete',
                            'action':'destroy'
                        },
                        headers: {
                            "Accept": "application/json"
                        } 
                    },
                    callBack = function(){
                        this.refreshListView();
                    };
                    FD.Util.ajax(opts,callBack,this);
                }
            },
            this
        );
    },
    restore : function(data){
        var id = data.display_id;
        console.log('invoking restore for ticket #',id);
        Ext.Msg.confirm('Restore ticket : '+id,'Do you want to restore this ticket?',
            function(btnId){
                if(btnId == 'no' || btnId == 'cancel'){
                    //do nothing..
                }
                else{
                    var opts = {
                        url: '/helpdesk/tickets/'+id+'/restore',
                        params:{
                            '_method':'put'
                        },
                        headers: {
                            "Accept": "application/json"
                        },
                        method:'POST'
                    },
                    callBack = function(){
                        this.refreshListView();
                    };
                    FD.Util.ajax(opts,callBack,this);
                }
            },
            this
        );
    },
    falgAsSpam : function(data){
        var id = data.display_id;
        console.log('invoking falgAsSpam for ticket #',id);
        Ext.Msg.confirm('Mark as spam ticket : '+id,'Do you want to mark this ticket as spam?',
            function(btnId){
                if(btnId == 'no' || btnId == 'cancel'){
                    //do nothing..
                }
                else{
                    var opts = {
                        url: '/helpdesk/tickets/'+id+'/spam',
                        params:{
                            '_method':'put'
                        },
                        headers: {
                            "Accept": "application/json"
                        },
                        method:'POST'
                    },
                    callBack = function(){
                        this.refreshListView();
                    };
                    FD.Util.ajax(opts,callBack,this);
                }
            },
            this
        );
    },
    unflagAsSpam : function(data){
        var id = data.display_id;
        console.log('invoking unflagAsSpam for ticket #',id);
        Ext.Msg.confirm('ticket : '+id+' is not spam','Do you want to mark this ticket as unspam?',
            function(btnId){
                if(btnId == 'no' || btnId == 'cancel'){
                    //do nothing..
                }
                else{
                    var opts = {
                        url: '/helpdesk/tickets/'+id+'/unspam',
                        params:{
                            '_method':'put'
                        },
                        headers: {
                            "Accept": "application/json"
                        },
                        method:'POST'
                    },
                    callBack = function(){
                        this.refreshListView();
                    };
                    FD.Util.ajax(opts,callBack,this);
                }
            },
            this
        );
    },
    close : function(data){
        var id = data.display_id;
        console.log('invoking close for ticket #',id);
        Ext.Msg.confirm('Close ticket : '+id,'Do you want to close this ticket?',
            function(btnId){
                if(btnId == 'no' || btnId == 'cancel'){
                    //do nothing..
                }
                else{
                    var opts = {
                        url: '/helpdesk/tickets/'+id+'/close',
                        params:{
                            '_method':'put'
                        },
                        headers: {
                            "Accept": "application/json"
                        },
                        method:'POST'
                    },
                    callBack = function(){
                        this.refreshListView();
                    };
                    FD.Util.ajax(opts,callBack,this);
                }
            },
            this
        );
    },
    pickUp : function(data){
        var id = data.display_id;
        console.log('invoking pickup for ticket #',id);

        Ext.Msg.confirm('Pickup ticket : '+id,'Do you want to pickup this ticket?',
            function(btnId){
                if(btnId == 'no' || btnId == 'cancel'){
                    //do nothing..
                }
                else{
                    var opts = {
                        url: '/helpdesk/tickets/'+id+'/assign',
                        params:{
                            '_method':'put',
                        },
                        headers: {
                            "Accept": "application/json"
                        },
                        method:'POST'
                    },
                    callBack = function(){
                        this.refreshListView();
                    };
                    FD.Util.ajax(opts,callBack,this);
                }
            },
            this
        );
    },
    onMenuOptionTap : function(menuData){
        var action = menuData.cls;
        switch (action) {
            case 'pickup' :
                this.pickUp(menuData.data);break;
            case 'delete' :
                this.moveToTrash(menuData.data);break;
            case 'restore' :
                this.restore(menuData.data);break;
            case 'flagSpam' :
                this.falgAsSpam(menuData.data);break;
            case 'unflagspam':
                this.unflagAsSpam(menuData.data);break;
            case 'close' :
                this.close(menuData.data);break;
        }
    },
    setSwipeOptions : function(swipeOBj,itemRecord){

        var data = itemRecord.data,
            actions = [{cls:'delete',data:data}];
        if(data.status_name != 'Closed'){
            actions.push({cls:'close',data:data});
        }
        if(data.deleted){
            actions = [{cls:'restore',data:data}]
        }
        else if(data.spam){
            actions.unshift({cls:'unflagspam',data:data});     
        }
        else if(!data.responder_id){
            actions.unshift({cls:'pickup',data:data});
        }
        else if(!data.spam){
            actions.push({cls:'flagSpam',data:data})
        }
        swipeOBj.setMenuOptions(actions);
    },
    onTicketDisclose: function(list, index, target, record, evt, options){
    	setTimeout(function(){list.deselect(index);},500);
        location.href="#tickets/show/"+record.data.display_id;
    },
    backToFilters: function(){
        Freshdesk.backBtn=true;
        location.href="#dashboard/tickets";
    },
    setHeaderTitle : function(title){
        this.items.items[0].setTitle(title);
    },
    config: {
        layout:'fit',
        itemId:'ticketListContainer'
    }
});
