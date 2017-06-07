Ext.define("Compass.ErpApp.Desktop.Applications.RailsDbAdmin.QueryPanel", {
    extend: "Ext.panel.Panel",
    alias: 'widget.railsdbadmin_querypanel',
    isReportQuery: false,
    isNewQuery: false,
    report: null,

    getSql: function() {
        return this.down('codemirror').getValue();
    },

    initComponent: function() {
        var me = this;
        var messageBox = null;

        var savedQueriesJsonStore = Ext.create('Ext.data.Store', {
            proxy: {
                type: 'ajax',
                url: '/rails_db_admin/erp_app/desktop/queries/saved_queries',
                reader: {
                    type: 'json',
                    root: 'data'
                }
            },
            fields: [{
                name: 'value'
            }, {
                name: 'display'
            }]
        });

        var tbarItems = [{
            text: 'Execute',
            iconCls: 'icon-playpause',
            handler: function(button) {
                if (me.paramPanelIsValid()) {
                    var textarea = me.query('.codemirror')[0];
                    var sql = textarea.getValue();
                    var selected_sql = textarea.getSelection();
                    var cursor_pos = textarea.getCursor().line;
                    var database = me.module.getDatabase();

                    var reportParams = null;
                    if (me.isReportQuery) {
                        reportParams = me.down('reportparamspanel').getReportParams();
                    }

                    messageBox = Ext.Msg.wait('Status', 'Executing..');

                    Ext.Ajax.request({
                        method: 'POST',
                        url: '/rails_db_admin/erp_app/desktop/queries/execute_query',
                        timeout: 120000,
                        params: {
                            database: database,
                            cursor_pos: cursor_pos
                        },
                        jsonData: {
                            sql: sql,
                            selected_sql: selected_sql,
                            report_params: reportParams
                        },
                        success: function(responseObject) {
                            messageBox.hide();
                            var response = Ext.decode(responseObject.responseText);

                            if (response.success) {
                                var columns = response.columns;
                                var fields = response.fields;
                                var data = response.data;

                                if (!Ext.isEmpty(me.down('railsdbadmin_readonlytabledatagrid'))) {
                                    var jsonStore = new Ext.data.JsonStore({
                                        fields: fields,
                                        data: data
                                    });

                                    me.down('railsdbadmin_readonlytabledatagrid').reconfigure(jsonStore, columns);
                                } else {
                                    var readOnlyDataGrid = Ext.create('Compass.ErpApp.Desktop.Applications.RailsDbAdmin.ReadOnlyTableDataGrid', {
                                        layout: 'fit',
                                        columns: columns,
                                        fields: fields,
                                        data: data
                                    });

                                    var cardPanel = me.down('#resultCardPanel');
                                    cardPanel.removeAll(true);
                                    cardPanel.add(readOnlyDataGrid);
                                    cardPanel.getLayout().setActiveItem(readOnlyDataGrid);
                                }
                            } else {
                                Ext.Msg.error("Error", response.message);
                            }

                        },
                        failure: function() {
                            messageBox.hide();
                            Ext.Msg.error('Status', 'Error loading grid');
                        }
                    });
                }
            }
        }, {
            text: 'Save Query',
            iconCls: 'icon-save',
            itemId: 'saveQueryBtn',
            hidden: this.isNewQuery,
            handler: function(btn) {
                var textarea = me.query('.codemirror')[0];
                var sql = textarea.getValue();
                var waitMsg;

                if (me.report && me.report.get('reportId')) {
                    waitMsg = Ext.Msg.wait("Saving Report...", "Status");
                    Ext.Ajax.request({
                        url: '/rails_db_admin/erp_app/desktop/reports/save_query',
                        params: {
                            id: me.report.get('reportId'),
                            query: sql
                        },
                        success: function(responseObject) {
                            waitMsg.close();
                            var obj = Ext.decode(responseObject.responseText);
                            if (!obj.success) {
                                Ext.Msg.alert('Status', 'Error saving report');
                            }
                        },
                        failure: function() {
                            waitMsg.close();
                            Ext.Msg.alert('Status', 'Error saving report');
                        }
                    });
                } else {
                    waitMsg = Ext.Msg.wait("Saving Query...", "Status");
                    Ext.Ajax.request({
                        url: '/rails_db_admin/erp_app/desktop/queries/save_query',
                        params: {
                            query: sql,
                            query_name: me.initialConfig.title
                        },
                        success: function(responseObject) {
                            waitMsg.close();
                            var obj = Ext.decode(responseObject.responseText);
                            if (!obj.success) {
                                Ext.Msg.alert('Status', 'Error saving report');
                            }
                        },
                        failure: function() {
                            waitMsg.close();
                            Ext.Msg.alert('Status', 'Error saving report');
                        }
                    });
                }
            }
        }];

        if (this.initialConfig['isReportQuery']) {
            tbarItems.push({
                text: 'Preview Report',
                iconCls: 'icon-document',
                handler: function() {
                    if (me.paramPanelIsValid()) {
                        var reportParamsPanel = me.down('reportparamspanel'),
                            reportParamsWithValues = encodeURIComponent(JSON.stringify(reportParamsPanel.getReportParams())),

                            reportTitle = "Preview" + " (" + me.report.get('reportName') + ")";
                        me.openIframeInTab(reportTitle, '/compass_ae_reports/display/' + me.report.get('internalIdentifier') + '?report_params=' + reportParamsWithValues);
                    }
                }
            });

            tbarItems.push({
                text: 'Download CSV',
                iconCls: 'icon-website-export',
                handler: function() {
                    if (me.paramPanelIsValid()) {
                        var reportParamsPanel = me.down('reportparamspanel'),
                            reportParamsWithValues = encodeURIComponent(JSON.stringify(reportParamsPanel.getReportParams())),
                            url = '/compass_ae_reports/display/' + me.report.get('internalIdentifier') + '.csv?report_params=' + reportParamsWithValues;

                        window.open(url, '_blank');
                    }
                }
            });

            tbarItems.push({
                text: 'Download PDF',
                iconCls: 'icon-website-export',
                handler: function() {
                    if (me.paramPanelIsValid()) {
                        var reportParamsPanel = me.down('reportparamspanel'),
                            reportParamsWithValues = encodeURIComponent(JSON.stringify(reportParamsPanel.getReportParams())),
                            url = '/compass_ae_reports/display/' + me.report.get('internalIdentifier') + '.pdf?report_params=' + reportParamsWithValues;

                        window.open(url, '_blank');
                    }
                }
            });
        } else {
            tbarItems.push({
                text: 'Download CSV',
                iconCls: 'icon-website-export',
                handler: function() {
                    var textarea = me.query('.codemirror')[0];
                    var sql = textarea.getValue();
                    var selected_sql = textarea.getSelection();
                    var cursor_pos = textarea.getCursor().line;
                    var database = me.module.getDatabase();

                    var params = {
                        database: database,
                        cursor_pos: cursor_pos,
                        sql: sql,
                        selected_sql: selected_sql,
                        authenticity_token: Compass.ErpApp.AuthentictyToken
                    };

                    Compass.ErpApp.Utility.openWindow('POST', '/rails_db_admin/erp_app/desktop/queries/download_csv', params, '_blank');
                }
            });
        }

        if (!this.initialConfig['hideSave'] && this.isNewQuery) {
            tbarItems.push({
                text: 'Save',
                iconCls: 'icon-save',
                itemId: 'saveBtn',
                handler: function() {
                    var textarea = me.down('.codemirror');

                    Ext.widget('window', {
                        layout: 'fit',
                        width: 375,
                        title: 'Save Query',
                        height: 125,
                        buttonAlign: 'center',
                        closeAction: 'hide',
                        plain: true,
                        items: {
                            xtype: 'form',
                            frame: false,
                            bodyStyle: 'padding:5px 5px 0',
                            width: 500,
                            items: [{
                                xtype: 'combo',
                                fieldLabel: 'Query Name',
                                name: 'query_name',
                                allowBlank: false,
                                store: savedQueriesJsonStore,
                                valueField: 'value',
                                displayField: 'display',
                                triggerAction: 'all',
                                forceSelection: false,
                                mode: 'remote'
                            }, {
                                xtype: 'hidden',
                                value: textarea.getValue(),
                                name: 'query'
                            }, {
                                xtype: 'hidden',
                                value: me.module.getDatabase(),
                                name: 'database'
                            }]
                        },
                        buttons: [{
                            text: 'Save',
                            handler: function(btn) {
                                var fp = this.up('window').down('.form');
                                if (fp.getForm().isValid()) {
                                    var queryName = fp.getForm().findField('query_name').getValue();
                                    fp.getForm().submit({
                                        url: '/rails_db_admin/erp_app/desktop/queries/save_query',
                                        waitMsg: 'Saving Query...',
                                        success: function(fp, o) {
                                            Ext.Msg.alert('Success', 'Saved Query');
                                            var database = me.module.getDatabase();
                                            me.module.queriesTreePanel().store.setProxy({
                                                type: 'ajax',
                                                url: '/rails_db_admin/erp_app/desktop/queries/saved_queries_tree',
                                                extraParams: {
                                                    database: database
                                                }
                                            });
                                            me.isNewQuery = false;
                                            me.down('#saveBtn').hide();
                                            me.down('#saveQueryBtn').show();
                                            me.setTitle(queryName);
                                            me.module.queriesTreePanel().store.load();
                                            btn.up('window').hide();
                                        }
                                    });
                                }
                            }
                        }, {
                            text: 'Cancel',
                            handler: function(btn) {
                                btn.up('window').hide();
                            }
                        }]

                    }).show();
                }
            });
        }

        var codeMirrorPanel = {
            region: 'center',
            xtype: 'codemirror',
            mode: 'sql',
            split: true,
            tbarItems: tbarItems,
            sourceCode: this.initialConfig['sqlQuery'],
            disableSave: true
        };

        me.items = [];
        // if this a report query show the report params
        if (me.isReportQuery) {
            me.items.push({
                xtype: 'reportparamspanel',
                region: 'north',
                params: me.report.get('reportMetaData').params
            });
        }
        me.items.push(codeMirrorPanel);


        if (!Ext.isEmpty(me.initialConfig['southRegion'])) {
            me.items.push(me.initialConfig['southRegion']);
        } else {
            me.items.push({
                layout: 'card',
                region: 'south',
                margins: '0 0 0 0',
                autoScroll: true,
                split: true,
                collapsible: true,
                collapseDirection: 'bottom',
                height: '50%',
                itemId: 'resultCardPanel',
                items: []
            });
        }

        this.callParent(arguments);
    },

    constructor: function(config) {
        config = Ext.applyIf({
            layout: 'border',
            border: false,
            closable: true
        }, config);
        if (config.title == null) {
            config = Ext.applyIf({
                title: 'New Query'
            }, config);
        }
        this.callParent([config]);
    },

    openIframeInTab: function(title, url) {
        var centerRegion = Ext.getCmp('rails_db_admin').down('#centerRegion');
        var itemId = Compass.ErpApp.Utility.Encryption.MD5(url);
        var item = centerRegion.getComponent(itemId);

        if (Compass.ErpApp.Utility.isBlank(item)) {
            item = Ext.create('Ext.panel.Panel', {
                iframeId: 'tutorials_iframe',
                itemId: itemId,
                closable: true,
                bodyPadding: '5px',
                layout: 'fit',
                title: title,
                html: '<iframe id="reports_iframe" height="100%" width="100%" frameBorder="0" src="' + url + '"></iframe>',
                dockedItems: [{
                    xtype: 'toolbar',
                    items: [{
                        xtype: 'button',
                        iconCls: 'icon-refresh',
                        text: 'Refresh',
                        handler: function(btn) {
                            btn.up('panel').el.query('iframe').first().contentWindow.location.reload();
                        }
                    }]
                }]
            });
            centerRegion.add(item);
        } else {
            Ext.Msg.wait('Updating preview..', 'Status');
            window.setTimeout(function() {
                item.update('<iframe id="reports_iframe" height="100%" width="100%" frameBorder="0" src="' + url + '"></iframe>');
                Ext.Msg.hide();
            }, 300);
        }
        centerRegion.setActiveTab(item);
    },

    paramPanelIsValid: function() {
        if (this.down('reportparamspanel')) {
            return this.down('reportparamspanel').isValid();
        } else {
            return true;
        }
    }
});