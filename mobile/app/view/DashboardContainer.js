Ext.define('Freshdesk.view.DashboardContainer', {
    extend: 'Ext.Panel',
    alias: 'widget.dashboardContainer',
    initialize : function(){
        this.callParent(arguments);
        var me = this;
        var logoutButton = {
            xtype: 'button',
            text: 'Sign out',
            ui:'headerBtn',
            handler: this.onLogout,
            scope: this,
            align:'right'
        }; 
        //TODO : Need to get the Rebranding name and set in title...
        var TopTitlebar = {
            xtype: 'titlebar',
            title: 'Freshdesk',
            docked: 'top',
            ui:'header',
            items: [
                { xtype: 'spacer' },
                logoutButton
            ]
        };

        var dashboardCfg = {
            defaultCls: 'dashboardButton',
            cols: 2,
            rows: 1,
            title: 'Dashboard',
            cells: [
                { id: 'tickets', label: 'Tickets', icon: 'resources/images/spacer.gif',iconCls:'tickets' },
                { id: 'contacts', label: 'Contacts', icon: 'resources/images/spacer.gif' ,iconCls:'contacts' },
                { id: 'settings', label: 'Settings', icon: 'resources/images/spacer.gif' ,iconCls:'settings' }
            ],
            tpl: '<img src="{icon}" title="{label}" class="{iconCls}" /><div class="label">{label}</div>'
        };


        // This is a custom method for making a dashboard:
        var GridView = function(args)
        {   
            var totalItems = args.cells.length;
            var maxBtnsPerPane = args.cols * args.rows;
            var noPanes = Math.ceil(totalItems / maxBtnsPerPane);
            var panes = [];
            var cellIndex = 0;
            var showIndicator;


            // Create the panes:
            for(var i = 0; i < noPanes; i++)
            {
                panes[i] = new Ext.Panel({
                    title: 'Dashboard',
                    layout: { type: 'vbox',align: 'justify', pack: 'justify' },
                    pack: 'center',
                    padding:'0 0 100% 0',
                    defaults: { flex: 1 }
                });
                
                var thisCount = i + maxBtnsPerPane;
                
                // Loop through how many rows we need:
                for(var rowCount = 0; rowCount < args.rows; rowCount++)
                {
                    var thisRow = new Ext.Panel({ layout: { type: 'hbox', align: 'justify', pack: 'justify' }, id: 'row'+i+ (rowCount + 1), defaults: { flex: 1 } });
                    
                    // Now we need to add the cells:
                    for(var colCount = 0; colCount < args.cols; colCount++)
                    {
                        var cellLabel, handlerFunc;
                        
                        (cellIndex > (totalItems - 1)) ? cellLabel = '' : cellLabel = args.cells[cellIndex].label;


                        if(cellIndex < totalItems)
                        {
                            var thisCell = new Ext.Panel({
                                title: cellLabel,
                                cls: 'dashboardButton',
                                layout: { type: 'vbox', align: 'center', pack: 'center' },
                                id: args.cells[cellIndex].id,
                                items: [{ html: args.tpl.replace(/\{(\w+)\}/g, function(match, key) { return args.cells[cellIndex][key]; }) }],
                                listeners: { tap: { element: 'element', fn: function() { me.showDetails(this.id)} } }
                            });
                        }
                        else
                            var thisCell = new Ext.Panel({ title: '' })
                        
                        thisRow.add(thisCell);
                        cellIndex++;
                    }
                    panes[i].add(thisRow);
                }
            }
            
            (noPanes == 1) ? showIndicator = false : showIndicator = true;
                


            var gridview = new Ext.Container({
                title: args.title,
                items: panes,
                indicator: showIndicator,
                margin:'20%'
            });
            
            return gridview;
        };


        var dashboard = new GridView(dashboardCfg);
        this.add([TopTitlebar,dashboard]);
    },
    onLogout: function(){
        location='/logout';
    },
    showDetails: function(id){
        location.href="#dashboard/"+id
    },
    config: {
        fullscreen: true,
        layout: { type: 'vbox', align: 'justify', pack: 'justify'  }
    }
});
