Ext.define("Freshdesk.view.Home", {
    extend: "Ext.Container",
    alias: "widget.home",
    config: {
        id : 'home',
        cls:'home',
        cls:'homepage',
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
                userData.avatar_url = userData.medium_avatar || 'resources/images/profile_blank_thumb.gif';
                Ext.getCmp('home-user-profile').setData(userData); 

                portalData.preferences.header_color && Ext.select('.branding').setStyle('background-color',portalData.preferences.header_color);
                portalData.preferences.tab_color && Ext.select('.branding').setStyle('border-bottom-color',portalData.preferences.tab_color);

            }
        },
        items :[
            {
                xtype:'container',
                centered:true,
                docked:'top',
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
                        },
                        height:'120px'
                    },
                    {
                        xtype:'titlebar',
                        ui:'plain',
                        centered:true,
                        minHeight:'10em',
                        style:{margin:'120px 0px 0px 0px'},
                        items : [
                            {
                                xtype:'button',
                                ui:'back headerBtn logout',
                                text:'Sign out',
                                minWidth:'80px',
                                maxWidth:'80px',
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
                                cls:'user_details',
                                minHeight:'10em',
                                tpl:'<div class="home_img"><img src="{avatar_url}"/></div><div class="user_name">{name}</div>',
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
                                ui:'forward headerBtn tickets',
                                text:'Tickets',
                                align:'left',
                                minWidth:'80px',
                                maxWidth:'80px',
                                handler:function(){
                                    var filterList = Ext.Viewport.getAt(0)
                                    Ext.Viewport.animateActiveItem(filterList,{type:'slide',direction:'left',durection:'500'});
                                }
                            }
                        ]
                    },
                    {

                        id:'home-footer',
                        cls:'footer',
                        docked:'bottom',
                        centered:true,
                        tpl:['<a class="switch_version">Switch to Desktop Version<span class="icon-right-arrow">&nbsp;</span></a>',
                             '<p>A <a href="http://www.freshdesk.com" target="_blank">Helpdesk Software</a> by Freshdesk</p>'].join(''),
                        data:{
                            
                        }
                    }
                ]
            }
        ]
    }
});