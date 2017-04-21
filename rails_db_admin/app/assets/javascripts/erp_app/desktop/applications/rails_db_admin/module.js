Ext.define("Compass.ErpApp.Desktop.Applications.RailsDbAdmin", {
    extend: "Ext.ux.desktop.Module",
    id: 'rails_db_admin-win',

    getWindow: function() {
        return this.app.getDesktop().getWindow('rails_db_admin');
    },

    queriesTreePanel: function() {
        return this.accordion.down('.railsdbadmin_queriestreemenu');
    },

    setWindowStatus: function(status) {
        this.getWindow().setStatus(status);
    },

    clearWindowStatus: function() {
        this.getWindow().clearStatus();
    },

    getTableData: function(table) {
        var self = this,
            id = 'ext-' + table + '-data';

        var grid = self.container.down('#' + id);

        if (Ext.isEmpty(grid)) {
            grid = Ext.create('Compass.ErpApp.Shared.DynamicEditableGridLoaderPanel', {
                id: id,
                title: table,
                setupUrl: '/rails_db_admin/erp_app/desktop/base/setup_table_grid/' + table,
                dataUrl: '/rails_db_admin/erp_app/desktop/base/table_data/' + table,
                editable: true,
                searchable: true,
                page: true,
                pageSize: 25,
                displayMsg: 'Displaying {0} - {1} of {2}',
                emptyMsg: 'Empty',
                loadErrorMessage: 'Tables Without Ids Can Not Be Edited',
                closable: true,
                params: {
                    database: self.getDatabase()
                },
                proxy: {
                    type: 'rest',
                    url: '/rails_db_admin/erp_app/desktop/base/table_data/' + table,
                    reader: {
                        type: 'json',
                        successProperty: 'success',
                        root: 'data',
                        messageProperty: 'message'
                    },
                    writer: {
                        type: 'json',
                        writeAllFields: true,
                        root: 'data'
                    },
                    listeners: {
                        exception: function(proxy, response, operation) {
                            var msg;
                            if (operation.getError() === undefined) {
                                var responseObject = Ext.JSON.decode(response.responseText);
                                msg = responseObject.exception;
                            } else {
                                msg = operation.getError();
                            }
                            Ext.MessageBox.show({
                                title: 'REMOTE EXCEPTION',
                                msg: msg,
                                icon: Ext.MessageBox.ERROR,
                                buttons: Ext.Msg.OK
                            });
                        }
                    }
                }
            });

            self.container.add(grid);
        }

        self.container.setActiveTab(grid);
    },

    selectTopFifty: function(table) {
        this.setWindowStatus('Selecting Top 50 from ' + table + '...');
        var self = this;

        Ext.Ajax.request({
            url: '/rails_db_admin/erp_app/desktop/queries/select_top_fifty/' + table,
            timeout: 60000,
            params: {
                database: self.getDatabase()
            },
            success: function(responseObject) {
                self.clearWindowStatus();
                var response = Ext.decode(responseObject.responseText);
                var sql = response.sql;
                var columns = response.columns;
                var fields = response.fields;
                var data = response.data;

                var readOnlyDataGrid = Ext.create('Compass.ErpApp.Desktop.Applications.RailsDbAdmin.ReadOnlyTableDataGrid', {
                    region: 'south',
                    split: true,
                    columns: columns,
                    fields: fields,
                    data: data,
                    collapseDirection: 'bottom',
                    height: '50%',
                    collapsible: true
                });

                var queryPanel = Ext.create('Compass.ErpApp.Desktop.Applications.RailsDbAdmin.QueryPanel', {
                    module: self,
                    closable: true,
                    sqlQuery: sql,
                    southRegion: readOnlyDataGrid
                });

                self.container.add(queryPanel);
                self.container.setActiveTab(queryPanel.id);

                //queryPanel.gridContainer.add(readOnlyDataGrid);
                //queryPanel.gridContainer.getLayout().setActiveItem(0);
            },
            failure: function() {
                self.clearWindowStatus();
                Ext.Msg.alert('Status', 'Error loading grid');
            }
        });
    },

    addConsolePanel: function() {
        this.container.add({
            xtype: 'compass_ae_console_panel',
            module: this
        });
        this.container.setActiveTab(this.container.items.length - 1);

    },

    addNewQueryTab: function() {
        this.container.add({
            xtype: 'railsdbadmin_querypanel',
            isNewQuery: true,
            module: this
        });
        this.container.setActiveTab(this.container.items.length - 1);
    },

    connectToDatabase: function() {
        var database = this.getDatabase();
        var tablestreePanelStore = this.accordion.down('.railsdbadmin_tablestreemenu').store;
        var queriesTreePanelStore = this.accordion.down('.railsdbadmin_queriestreemenu').store;

        tablestreePanelStore.setProxy({
            type: 'ajax',
            url: '/rails_db_admin/erp_app/desktop/base/tables',
            extraParams: {
                database: database
            }
        });
        tablestreePanelStore.load();

        queriesTreePanelStore.setProxy({
            type: 'ajax',
            url: '/rails_db_admin/erp_app/desktop/queries/saved_queries_tree',
            extraParams: {
                database: database
            }
        });
        queriesTreePanelStore.load();
    },

    getDatabase: function() {
        return Ext.getCmp('databaseCombo').getValue();
    },

    deleteQuery: function(queryName) {
        var self = this;
        Ext.MessageBox.confirm('Confirm', 'Are you sure you want to delete this query?', function(btn) {
            if (btn === 'no') {
                return false;
            } else if (btn === 'yes') {
                self.setWindowStatus('Deleting ' + queryName + '...');
                var database = self.getDatabase();
                Ext.Ajax.request({
                    url: '/rails_db_admin/erp_app/desktop/queries/delete_query/',
                    params: {
                        database: database,
                        query_name: queryName
                    },
                    success: function(responseObject) {
                        self.clearWindowStatus();
                        var centerRegion = Ext.getCmp('rails_db_admin').down('#centerRegion'),
                            itemId = Compass.ErpApp.Utility.Encryption.MD5(queryName),
                            item = centerRegion.down('#' + itemId);

                        if (!Compass.ErpApp.Utility.isBlank(item)) {
                            centerRegion.remove(item);
                        }

                        var response = Ext.decode(responseObject.responseText);
                        if (response.success) {
                            var queriesTreePanelStore = self.accordion.down('.railsdbadmin_queriestreemenu').store;
                            queriesTreePanelStore.setProxy({
                                type: 'ajax',
                                url: '/rails_db_admin/erp_app/desktop/queries/saved_queries_tree',
                                extraParams: {
                                    database: database
                                }
                            });
                            queriesTreePanelStore.load();
                        } else {
                            Ext.Msg.alert('Error', response.exception);
                        }

                    },
                    failure: function() {
                        self.clearWindowStatus();
                        Ext.Msg.alert('Status', 'Error deleting query');
                    }
                });
            }
        });
    },

    displayAndExecuteQuery: function(queryName) {
        this.setWindowStatus('Executing ' + queryName + '...');
        var self = this,
            database = this.getDatabase(),
            itemId = Compass.ErpApp.Utility.Encryption.MD5(queryName);

        Ext.Ajax.request({
            url: '/rails_db_admin/erp_app/desktop/queries/open_and_execute_query/',
            params: {
                database: database,
                query_name: queryName
            },
            success: function(responseObject) {
                var response = Ext.decode(responseObject.responseText),
                    query = response.query,
                    queryPanel = null;

                if (response.success) {
                    self.clearWindowStatus();
                    var columns = response.columns;
                    var fields = response.fields;
                    var data = response.data;
                    var centerRegion = Ext.getCmp('rails_db_admin').down('#centerRegion');
                    var item = centerRegion.down('#' + itemId);

                    if (Compass.ErpApp.Utility.isBlank(item)) {
                        var readOnlyDataGrid = Ext.create('Compass.ErpApp.Desktop.Applications.RailsDbAdmin.ReadOnlyTableDataGrid', {
                            region: 'south',
                            columns: columns,
                            fields: fields,
                            data: data,
                            collapseDirection: 'bottom',
                            height: '50%',
                            collapsible: true
                        });
                        item = Ext.create('Compass.ErpApp.Desktop.Applications.RailsDbAdmin.QueryPanel', {
                            module: self,
                            title: queryName,
                            itemId: itemId,
                            sqlQuery: query,
                            southRegion: readOnlyDataGrid,
                            closable: true
                        });
                        self.container.add(item);
                    } else {
                        if (!Ext.isEmpty(item.down('railsdbadmin_readonlytabledatagrid'))) {
                            var jsonStore = new Ext.data.JsonStore({
                                fields: fields,
                                data: data
                            });

                            item.down('railsdbadmin_readonlytabledatagrid').reconfigure(jsonStore, columns);
                        } else {
                            var readOnlyDataGrid = Ext.create('Compass.ErpApp.Desktop.Applications.RailsDbAdmin.ReadOnlyTableDataGrid', {
                                layout: 'fit',
                                columns: columns,
                                fields: fields,
                                data: data
                            });

                            var cardPanel = item.down('#resultCardPanel');
                            cardPanel.removeAll(true);
                            cardPanel.add(readOnlyDataGrid);
                            cardPanel.getLayout().setActiveItem(readOnlyDataGrid);
                        }
                    }
                    self.container.setActiveTab(item);
                } else {
                    Ext.Msg.alert('Error', response.exception);
                    queryPanel = Ext.create('Compass.ErpApp.Desktop.Applications.RailsDbAdmin.QueryPanel', {
                        module: self,
                        closable: true,
                        sqlQuery: query
                    });

                    self.container.add(queryPanel);
                    self.container.setActiveTab(self.container.items.length - 1);
                }

            },
            failure: function() {
                self.clearWindowStatus();
                Ext.Msg.alert('Status', 'Error loading query');
            }
        });
    },

    //************ Reporting ************************************************

    editQuery: function(report, query) {
        var self = this;
        var centerRegion = Ext.getCmp('rails_db_admin').down('#centerRegion');
        var itemId = report.get('internalIdentifier') + '-query';
        var item = centerRegion.getComponent(itemId);

        if (Compass.ErpApp.Utility.isBlank(item)) {
            item = Ext.create('Compass.ErpApp.Desktop.Applications.RailsDbAdmin.QueryPanel', {
                module: self,
                itemId: itemId,
                isReportQuery: true,
                hideSave: true,
                title: 'Query' + ' (' + report.get('text') + ')',
                sqlQuery: query,
                report: report,
                closable: true
            });
            centerRegion.add(item);
        }

        centerRegion.setActiveTab(item);
    },

    showImage: function(node, reportId) {
        var self = this;
        var centerRegion = self.container;
        var itemId = Compass.ErpApp.Utility.Encryption.MD5(node.data.id);
        var item = centerRegion.getComponent(itemId);
        var imgSrc = '/download/' + node.data.text + '?path=' + node.data.parentId + '&token=' +  Math.round(Math.random() * 10000000);
        var title = node.data.text + ' (' + node.parentNode.data.reportName + ')';
        if (Compass.ErpApp.Utility.isBlank(item)) {
            item = Ext.create('Ext.panel.Panel', {
                closable: true,
                itemId: itemId,
                title: title,
                layout: 'fit',
                html: '<img src="' + imgSrc + '" />'
            });
            self.container.add(item);
        }
        self.container.setActiveTab(item);
    },

    loadReport: function(report) {
        var me = this;

        me.eastRegion.show();
        me.eastRegion.down('railsdbadminreportssettings').setReportSettings(report);
        me.eastRegion.down('railsdbadminreportsparamsmanager').setReportData(report);
        me.eastRegion.down('railsdbadminreportsrolespanel').setReportRoles(report);
    },

    //***********************************************************************

    init: function() {
        this.launcher = {
            text: 'Database Tools',
            iconCls: 'icon-rails_db_admin',
            handler: this.createWindow,
            scope: this
        };
    },

    displayQuery: function(queryName) {
        this.setWindowStatus('Retrieving ' + queryName + '...');
        var self = this;
        var database = this.getDatabase();
        Ext.Ajax.request({
            url: '/rails_db_admin/erp_app/desktop/queries/open_query/',
            params: {
                database: database,
                query_name: queryName
            },
            success: function(responseObject) {
                var response = Ext.decode(responseObject.responseText);
                var query = response.query;
                var queryPanel = null;

                if (response.success) {
                    var centerRegion = Ext.getCmp('rails_db_admin').down('#centerRegion');
                    var itemId = Compass.ErpApp.Utility.Encryption.MD5(queryName);
                    var item = centerRegion.down('#' + itemId);

                    self.clearWindowStatus();
                    if (Compass.ErpApp.Utility.isBlank(item)) {
                        var item = Ext.create('Compass.ErpApp.Desktop.Applications.RailsDbAdmin.QueryPanel', {
                            module: self,
                            closable: true,
                            sqlQuery: query,
                            title: queryName,
                            itemId: itemId
                        });
                        centerRegion.add(item);
                    }
                    centerRegion.setActiveTab(item);
                } else {
                    Ext.Msg.alert('Error', response.exception);
                    queryPanel = Ext.create('Compass.ErpApp.Desktop.Applications.RailsDbAdmin.QueryPanel', {
                        module: self,
                        closable: true,
                        sqlQuery: query
                    });

                    self.container.add(queryPanel);
                    self.container.setActiveTab(self.container.items.length - 1);
                }

            },
            failure: function() {
                self.clearWindowStatus();
                Ext.Msg.alert('Status', 'Error loading query');
            }
        });
    },

    openIframeInTab: function(title, url) {
        var self = this;

        var item = Ext.create('Ext.panel.Panel', {
            iframeId: 'tutorials_iframe',
            itemId: 'preview_report',
            closable: true,
            layout: 'fit',
            title: title,
            html: '<iframe id="themes_iframe" height="100%" width="100%" frameBorder="0" src="' + url + '"></iframe>'
        });

        self.container.add(item);
        self.container.setActiveTab(item);
    },

    createWindow: function() {
        var me = this;
        var desktop = this.app.getDesktop();
        var win = desktop.getWindow('rails_db_admin');

        if (!win) {
            this.container = Ext.create('Ext.tab.Panel', {
                plugins: Ext.create('Ext.ux.TabCloseMenu', {
                    extraItemsTail: [
                        '-', {
                            text: 'Closable',
                            checked: true,
                            hideOnClick: true,
                            handler: function(item) {
                                currentItem.tab.setClosable(item.checked);
                            }
                        },
                        '-', {
                            text: 'Enabled',
                            checked: true,
                            hideOnClick: true,
                            handler: function(item) {
                                currentItem.tab.setDisabled(!item.checked);
                            }
                        }
                    ],
                    listeners: {
                        beforemenu: function(menu, item) {
                            var enabled = menu.child('[text="Enabled"]');
                            menu.child('[text="Closable"]').setChecked(item.closable);
                            if (item.tab.active) {
                                enabled.disable();
                            } else {
                                enabled.enable();
                                enabled.setChecked(!item.tab.isDisabled());
                            }

                            currentItem = item;
                        }
                    }
                }),
                itemId: 'centerRegion',
                region: 'center',
                margins: '0 0 0 0',
                border: false,
                minsize: 300,
                listeners: {
                    beforetabchange: function(tabPanel, newPanel, oldPanel, eOpts) {
                        var isActivatingReportPanel =
                            oldPanel &&
                            newPanel.isXType('railsdbadmin_querypanel') &&
                            newPanel.isReportQuery;

                        // the panel to be activated is the report panel show the query params panel in the east region else hide the east region
                        if (isActivatingReportPanel) {
                            me.loadReport(newPanel.report);
                        } else {
                            me.eastRegion.hide();
                        }
                    }
                }
            });

            this.accordion = Ext.create('Ext.panel.Panel', {
                dockedItems: [{
                    xtype: 'toolbar',
                    dock: 'top',
                    items: [{
                        text: 'Database:'
                    }, {
                        xtype: 'railsdbadmin_databasecombo',
                        module: this
                    }]
                }],
                ui: 'rounded-panel',
                region: 'west',
                margins: '0 0 0 0',
                cmargins: '0 0 0 0',
                width: 300,
                collapsible: true,
                header: false,
                split: true,
                layout: 'accordion',
                items: [{
                    xtype: 'railsdbadmin_tablestreemenu',
                    module: this
                }, {
                    xtype: 'railsdbadmin_queriestreemenu',
                    module: this
                }, {
                    xtype: 'railsdbadmin_reportstreepanel',
                    module: this
                }]
            });

            this.eastRegion = Ext.create('Ext.panel.Panel', {
                ui: 'rounded-panel',
                region: 'east',
                id: 'reports_accordian_panel',
                margins: '0 0 0 0',
                cmargins: '0 0 0 0',
                width: 300,
                collapsible: true,
                header: false,
                split: true,
                layout: 'accordion',
                hidden: true,
                items: [{
                    xtype: 'railsdbadminreportssettings'
                }, {
                    xtype: 'railsdbadminreportsparamsmanager'
                }, {
                    xtype: 'railsdbadminreportsrolespanel'
                }]
            });


            win = desktop.createWindow({
                id: 'rails_db_admin',
                title: 'RailsDBAdmin',
                width: 1200,
                height: 550,
                maximized: true,
                iconCls: 'icon-rails_db_admin-light',
                shim: false,
                animCollapse: false,
                constrainHeader: true,
                layout: 'border',
                items: [
                    this.accordion,
                    this.container,
                    this.eastRegion
                ]
            });

            win.addListener('render', function(win) {
                win.down('#centerRegion').add({
                    xtype: 'railsdbadmin_splash_screen',
                    module: self,
                    closable: true
                });

                win.down('#centerRegion').setActiveTab(win.down('#centerRegion').items.length - 1);
            });
        }
        win.show();
    }
});

Ext.define("Compass.ErpApp.Desktop.Applications.RailsDbAdmin.BooleanEditor", {
    extend: "Ext.form.ComboBox",
    alias: 'widget.booleancolumneditor',
    initComponent: function() {
        this.store = Ext.create('Ext.data.ArrayStore', {
            fields: ['display', 'value'],
            data: [
                ['False', 'f'],
                ['True', 't']
            ]
        });

        this.callParent(arguments);
    },
    constructor: function(config) {
        config = Ext.apply({
            valueField: 'value',
            displayField: 'display',
            triggerAction: 'all',
            forceSelection: true,
            queryMode: 'local'
        }, config);

        this.callParent([config]);
    }
});

Compass.ErpApp.Desktop.Applications.RailsDbAdmin.renderBooleanColumn = function(value) {
    if (value == "t") {
        return "True";
    } else if (value == "f") {
        return "False";
    } else {
        return null;
    }
};