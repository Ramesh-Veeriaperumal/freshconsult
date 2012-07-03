Ext.define("Freshdesk.view.Scenarioies", {
    extend: "Ext.Container",
    alias: "widget.scenarioies",
    execute_scenario : function(data){
        var me = this;
        Ext.Ajax.request({
            url: '/helpdesk/tickets/execute_scenario/'+this.ticket_id,
            method:'GET',
            params:{
                'scenario_id':data.id
            },
            headers: {
                "Accept": "application/json"
            },
            callback: function(req,success,response){
                console.log(response);
                if(success){
                    Freshdesk.anim = {type:'cover',direction:'down'};
                    var flashMessageBox = Ext.ComponentQuery.query('#flashMessageBox')[0],
                    resJson = JSON.parse(response.responseText),
                    flashData = {
                        title:'Executed scenario <b>'+resJson.rule_name+'</b>',
                        messages:resJson.actions_executed
                    };
                    flashMessageBox.ticket_id = response.id;
                    flashMessageBox.items.items[1].setData(flashData);
                    flashMessageBox.hideHandler = function() {
                        location.href="#tickets/show/"+me.ticket_id;
                    }
                    Ext.Viewport.animateActiveItem(flashMessageBox, Freshdesk.anim);
                    //location.href="#tickets/show/"+me.ticket_id;
                }
                else{
                    Ext.Msg.alert('Some thing went wrong!', "We are sorry . Some thing went wrong! Our technical team is looking into it.");   
                }
            }
        });
    },
    config: {
        itemId : 'scenarioies',
        cls:'scenarioies',
        layout:'fit',
        hidden:true,
        fullscreen:true,
        items :[
            {
                    xtype:'list',
                    emptyText: '<div class="empty-list-text">You don\'t have any Scenarioies!.</div>',
                    onItemDisclosure: false,
                    itemTpl: '<span class="bullet"></span>&nbsp;{name}'
            },
            {
                xtype:'titlebar',
                title:'Execute Scenario',
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
                        text:'Back',
                        ui:'headerBtn back',
                        align:'left',
                        handler:function(){
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