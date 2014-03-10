//<debug>
Ext.Loader.setConfig({enabled:true});
Ext.Loader.setPath({
    'Ext'       : 'sdk/src',
    'Freshdesk' : 'app',
    'plugin'    : 'plugin'
});
//</debug>

Ext.application({
    name: 'Freshdesk',

    viewport : {
        autoMaximize : true
    },

    requires: [
        'Ext.MessageBox','plugin.ux.SwipeOptions','plugin.ux.ListPaging2', 'plugin.ux.PullRefresh2',
        'plugin.ux.Iscroll', 'plugin.ux.TitleDoubleTap'
    ],

    controllers : ['Dashboard', 'Filters', 'Tickets', 'Contacts','Timers'],
    views       : ['Home','DashboardContainer', 'FiltersListContainer', 'FiltersList', 'TicketsListContainer',
                    'TicketsList', 'ContactsListContainer', 'ContactsList','ContactInfo', 'TicketDetailsContainer',
                    'TicketDetails', 'TicketReply', 'TicketForm', 'ContactDetails', 'ContactsFormContainer',
                    'ContactForm', 'TicketProperties', 'EmailForm','CannedResponses','Solutions','NoteForm',
                    'TicketNote','Scenarioies','NewTicketContainer','FlashMessageBox','TicketTweetForm','TweetForm',
                    'FacebookForm','TicketFacebookForm','MultiSelect','Timer','TicketTimer','TimerContainer','TimerForm'],
    stores      :['Init','InitReplyEmails','Filters','Tickets','Contacts','AutoTechnician','Timers'],
    models      :['Portal','Filter','Ticket','Contact','AutoSuggestion','Timer'],

    icon: {
        57: 'resources/icons/Icon.png',
        72: 'resources/icons/Icon~ipad.png',
        114: 'resources/icons/Icon@2x.png',
        144: 'resources/icons/Icon~ipad@2x.png'
    },
    
    phoneStartupScreen: 'resources/loading/Homescreen.jpg',
    tabletStartupScreen: 'resources/loading/Homescreen~ipad.jpg',

    launch: function() {
        
        

        var dashboardContainer = {
            xtype: "dashboardContainer"
        },filtersListContainer = {
            xtype: "filtersListContainer"
        },ticketsListContainer = {
            xtype: "ticketsListContainer",
            plugins : [
                {
                    xclass: 'plugin.ux.TitleDoubleTap'
                }
            ]
        },contactsListContainer = {
            xtype: "contactsListContainer"
        },ticketDetailsContainer = {
            xtype: "ticketDetailsContainer"
        },ticketReply = {
            xtype:"ticketReply"
        },contactDetails = {
            xtype:"contactDetails"
        },contactsFormContainer = {
            xtype:"contactsFormContainer"
        },cannedResponses ={
            xtype:'cannedResponses'
        },solutions ={
            xtype:'solutions'
        },ticketNote = {
            xtype:"ticketNote"
        },scenarioies = {
            xtype : "scenarioies"
        },home = {
            xtype : "home"
        },newTicketContainer = {
            xtype:'newTicketContainer'
        },flashMessageBox = {
            xtype:'flashMessageBox'
        },ticketTweetForm = {
            xtype:'ticketTweetForm'
        },ticketFacebookForm = {
            xtype:'ticketFacebookForm'
        },timer = {
            xtype:'timer'
        },ticketTimer={
            xtype:'ticketTimer'
        },timerContainer={
            xtype:'timerContainer'
        },timerForm={
            xtype:'timerForm'
        };

        Ext.Viewport.add([
                        filtersListContainer,home,ticketsListContainer,contactsListContainer,
                        ticketDetailsContainer,ticketReply,contactDetails,contactsFormContainer,cannedResponses,
                        solutions,ticketNote,scenarioies,newTicketContainer,flashMessageBox,ticketTweetForm,ticketFacebookForm,timer,ticketTimer,
                        timerContainer
        ]);

        Ext.getStore('Init').load({callback:function(data, operation, success){
            FD.current_portal = data[0].raw.portal;
            FD.current_account = data[0].raw.account;
            FD.current_user = data[0].raw.user;
            if(FD.current_user && FD.current_user.is_customer) {
                FD.Util.initCustomer();
            }
            document.title = FD.current_portal && FD.current_portal.name+' : Helpdesk';
            Ext.fly('appLoadingIndicator').destroy();
        }});


        Ext.getStore('InitReplyEmails').load({callback:function(data, operation, success){
            FD.reply_emails = data;
        }});

        //adding listners to ajax for showing the loading mask .. global.
        Ext.Ajax.addListener('beforerequest',function(){
            //Ext.Viewport.setMasked({xtype:'loadmask',cls:'loading'})
        })
        Ext.Ajax.addListener('requestcomplete',function(){
            //Ext.Viewport.setMasked(false)
        })
        Ext.Ajax.addListener('requestexception',function(me,response){
            if(response.status == 302){
                window.location = JSON.parse(response.responseText).Location;
            }
            Ext.Viewport.setMasked(false)
        })

    },

    onUpdated: function() {
        Ext.Msg.confirm(
            "Application Update",
            "This application has just successfully been updated to the latest version. Reload now?",
            function() {
                window.location.reload();
            }
        );
    }
});
