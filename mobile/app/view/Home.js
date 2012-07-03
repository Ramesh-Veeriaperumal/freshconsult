Ext.define("Freshdesk.view.Home", {
    extend: "Ext.Container",
    alias: "widget.home",
    config: {
        id : 'home',
        cls:'home',
        zIndex:2,
        showAnimation: {
                type:'slide',
                direction:'right',
                easing:'ease-out'
        },
        layout:'fit',
        hidden:true,
        listeners: {
            show:function(){
                var portalData = FD.current_account.main_portal;
                portalData.logo_url =  portalData.logo_url || 'resources/images/admin-logo.png';
                Ext.getCmp('branding').setData(portalData);
                var userData = FD.current_user;
                userData.avatar_url = userData.avatar_url || 'resources/images/profile_blank_thumb.gif';
                Ext.getCmp('home-user-profile').setData(userData); 
            }
        },
        items :[
            {
                xtype:'container',
                centered:true,
                minHeight:'300px',
                ui:'plain',
                width:'100%',
                items : [
                    {
                        id:'branding',
                        tpl:['<div class="branding">',
                                '<div class="logo"><img src="{logo_url}"/></div>',
                                '<div class="title">{name}</div>',
                            '</div>'].join(''),
                        data:{
                            logo_url: 'resources/images/admin-logo.png',
                            name:'Freshdesk'
                        }
                    },
                    {
                        xtype:'titlebar',
                        ui:'plain',
                        minHeight:'10em',
                        centered:true,
                        items : [
                            {
                                xtype:'button',
                                ui:'back headerBtn logout',
                                text:'Sign out',
                                handler:function(){
                                    location.href="/logout";
                                }
                            },
                            {
                                xtype:'spacer'
                            },
                            {
                                cls:'profile_img',
                                id:'home-user-profile',
                                ui:'plain',
                                tpl:'<div><div><img src="{avatar_url}"/></div></div>{name}',
                                data:{
                                    avatar_url:'resources/images/profile_blank_thumb.gif',
                                    name:'Rachel'
                                }
                            },
                            {
                                xtype:'spacer'
                            },
                            {
                                xtype:'button',
                                ui:'forward headerBtn logout',
                                text:'Tickets',
                                align:'left',
                                handler:function(){
                                    var filterList = Ext.Viewport.getAt(0)
                                    Ext.Viewport.animateActiveItem(filterList,{type:'slide',direction:'left',durection:'500'});
                                }
                            }
                        ]
                    }
                ]
            }
        ]
    }
});