Ext.define("Freshdesk.view.Scenarioies", {
    extend: "Ext.Container",
    alias: "widget.scenarioies",
    showSuccessMessagePopup : function(res){
        Freshdesk.anim = {type:'cover',direction:'down'};
        var flashMessageBox = Ext.ComponentQuery.query('#flashMessageBox')[0],
        resJson = JSON.parse(res.responseText),
        flashData = {
            title:'<b>'+resJson.rule_name+'</b>',
            messages:resJson.actions_executed
        },
        me=this;
        flashMessageBox.ticket_id = res.display_id;
        flashMessageBox.items.items[1].setData(flashData);
        flashMessageBox.hideHandler = function() {
            me.hide();
            location.href="#tickets/show/"+me.ticket_id;
        }
        flashMessageBox.show();
        //Ext.Viewport.animateActiveItem(flashMessageBox, Freshdesk.anim);
    },
    execute_scenario : function(data){
        var me = this,
            opts = {
                url: '/helpdesk/tickets/execute_scenario/'+this.ticket_id,
                params:{
                    'scenario_id':data.id
                }
            };
        FD.Util.getJSON(opts,this.showSuccessMessagePopup,this);
    },
    config: {
        itemId : 'scenarioies',
        id:'scenarioies',
        cls:'scenarioies',
        layout:'fit',
        hidden:true,
        fullscreen:true,
        showAnimation : {
            type:'slideIn',
            direction:'up',
            easing:'ease-in-out'
        },
        hideAnimation: {
                type:'slideOut',
                direction:'down',
                easing:'ease-in-out'
        },
        zIndex:9,
        items :[
            {
                    xtype:'list',
                    emptyText: '<div class="empty-list-text">You don\'t have any Scenarioies!.</div>',
                    onItemDisclosure: false,
                    itemTpl: '<div class="bullet"></div>&nbsp;<div class="scenario_text">{name}</div>'
            },
            {
                xtype:'titlebar',
                title:'Scenario',
                ui:'header',
                docked:'top',
                items:[
                    {
                        xtype:'button',
                        text:'Execute',
                        ui:'headerBtn',
                        align:'right',
                        handler:function(){
                            var me = Ext.ComponentQuery.query('#scenarioies')[0],selection = me.items.items[0].getSelection();
                            if(selection.length) 
                                me.execute_scenario(selection[0].raw)
                        },
                        scope:this
                    },
                    {
                        xtype:'button',
                        text:'Cancel',
                        ui:'lightBtn',
                        align:'left',
                        handler: function(){
                                Ext.getCmp('scenarioies').hide();
                                Freshdesk.cancelBtn=true;
                                Freshdesk.anim = {type:'cover',direction:'down'};
                                location.href="#tickets/show/"+Ext.ComponentQuery.query('#scenarioies')[0].ticket_id;
                        },
                        scope:this
                    }
                ]
            }
        ]
    }
});