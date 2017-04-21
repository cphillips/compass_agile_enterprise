Ext.define("Compass.ErpApp.Desktop.Applications.RailsDbAdmin.Reports.TreePanel", {
    extend: "Compass.ErpApp.Shared.FileManagerTree",
    alias: 'widget.railsdbadmin_reportstreepanel',

    newReport: function() {
        var me = this;

        Ext.create("Ext.window.Window", {
            title: 'New Report',
            plain: true,
            buttonAlign: 'center',
            defaultFocus: 'title',
            items: Ext.create('Ext.FormPanel', {
                labelWidth: 110,
                frame: false,
                bodyStyle: 'padding:5px 5px 0',
                url: '/rails_db_admin/erp_app/desktop/reports/create',
                defaults: {
                    width: 225
                },
                items: [{
                    xtype: 'textfield',
                    fieldLabel: 'Title',
                    allowBlank: false,
                    name: 'name',
                    itemId: 'title'
                }, {
                    xtype: 'textfield',
                    fieldLabel: 'Unique Name',
                    allowBlank: false,
                    name: 'internal_identifier'
                }]
            }),
            buttons: [{
                text: 'Submit',
                listeners: {
                    'click': function(button) {
                        var window = button.up('window');
                        var formPanel = window.down('form');
                        formPanel.getForm().submit({
                            waitMsg: 'Creating Report...',
                            success: function(form, action) {
                                var obj = Ext.decode(action.response.responseText);
                                if (obj.success) {
                                    button.up('window').close();
                                    me.getStore().load();
                                } else {
                                    Ext.Msg.alert("Error", obj.msg);
                                }
                            },
                            failure: function(form, action) {
                                var obj = Ext.decode(action.response.responseText);
                                if (obj.msg) {
                                    Ext.Msg.alert("Error", obj.msg);
                                } else {
                                    Ext.Msg.alert("Error", "Error creating report.");
                                }
                            }
                        });
                    }
                }
            }, {
                text: 'Close',
                handler: function(btn) {
                    btn.up('window').close();
                }
            }]
        }).show();
    },

    uploadReport: function() {
        var me = this;
        Ext.create("Ext.window.Window", {
            modal: true,
            title: 'New Report',
            buttonAlign: 'center',
            items: {
                xtype: 'form',
                timeout: 300,
                frame: false,
                bodyStyle: 'padding:5px 5px 0',
                fileUpload: true,
                url: '/rails_db_admin/erp_app/desktop/reports/create',
                items: [{
                    xtype: 'fileuploadfield',
                    width: '350px',
                    fieldLabel: 'Upload Report',
                    buttonText: 'Upload',
                    buttonOnly: false,
                    allowBlank: true,
                    name: 'report_data'
                }]
            },
            buttons: [{
                text: 'Submit',
                listeners: {
                    'click': function(button) {
                        var window = this.up('window'),
                            form = window.query('form')[0].getForm();

                        if (form.isValid()) {
                            form.submit({
                                timeout: 300000,
                                waitMsg: 'Creating report...',
                                success: function(form, action) {
                                    var obj = Ext.decode(action.response.responseText);
                                    if (obj.success) {
                                        me.getStore().load();
                                    }
                                    window.close();
                                },
                                failure: function(form, action) {
                                    Ext.Msg.alert("Error", "Error creating report");
                                }
                            });
                        }
                    }
                }
            }, {
                text: 'Close',
                handler: function(btn) {
                    btn.up('window').close();
                }
            }]
        }).show();
    },

    deleteReport: function(id) {
        var me = this;

        Ext.MessageBox.confirm('Confirm', 'Are you sure you want to delete this report?', function(btn) {
            if (btn === 'no') {
                return false;
            } else if (btn === 'yes') {
                var waitMsg = Ext.Msg.wait("Deleting report...", "Status");
                Ext.Ajax.request({
                    url: '/rails_db_admin/erp_app/desktop/reports/delete',
                    params: {
                        id: id
                    },
                    success: function(responseObject) {
                        waitMsg.close();
                        var obj = Ext.decode(responseObject.responseText);
                        if (obj.success) {
                            me.getStore().load();
                        } else {
                            Ext.Msg.alert('Status', 'Error deleting report');
                        }
                    },
                    failure: function() {
                        waitMsg.close();
                        Ext.Msg.alert('Status', 'Error deleting report');
                    }
                });
            }
        });
    },

    editQuery: function(report) {
        var me = this;
        var waitMsg = Ext.Msg.wait("Loading query...", "Status");

        Ext.Ajax.request({
            url: '/rails_db_admin/erp_app/desktop/reports/query',
            params: {
                id: report.get('reportId')
            },
            success: function(responseObject) {
                waitMsg.close();

                var obj = Ext.decode(responseObject.responseText);
                if (obj.success) {
                    me.initialConfig.module.editQuery(report, obj.query);
                } else {
                    Ext.Msg.error('Status', 'Error loading report');
                }
            },
            failure: function() {
                waitMsg.close();
                Ext.Msg.error('Status', 'Error loading report');
            }
        });
    },

    loadReport: function(report) {
        var me = this;

        me.initialConfig.module.loadReport(report);
    },

    exportReport: function(reportId) {
        var waitMsg = Ext.Msg.wait("Exporting Report...", "Status");

        window.open('/rails_db_admin/erp_app/desktop/reports/export?id=' + reportId, '_blank');

        waitMsg.hide();
    },

    constructor: function(config) {
        var me = this;

        config = Ext.apply({
            autoLoadRoot: true,
            rootVisible: true,
            multiSelect: true,
            handleRootContextMenu: true,
            addViewContentsToContextMenu: true,
            title: 'Reports',
            rootText: 'Reports',
            autoScroll: true,
            allowDownload: true,
            url: '/rails_db_admin/erp_app/desktop/reports/index',
            controllerPath: '/rails_db_admin/erp_app/desktop/reports',
            standardUploadUrl: '/rails_db_admin/erp_app/desktop/reports/upload_file',
            fields: [
                'text',
                'iconCls',
                'leaf',
                'reportIid',
                'reportId',
                'isReport',
                'handleContextMenu',
                'internalIdentifier',
                'reportName', {
                    name: 'reportMetaData',
                    type: 'object'
                }
            ],
            animate: false,
            listeners: {
                'showImage': function(fileManager, node, themeId) {
                    var reportId = null;
                    var reportNode = node;
                    while (reportId === null && !Compass.ErpApp.Utility.isBlank(reportNode.parentNode)) {
                        if (reportNode.data.isReport) {
                            reportId = reportNode.data.id;
                        } else {
                            reportNode = reportNode.parentNode;
                        }
                    }
                    me.initialConfig.module.showImage(node, reportId);
                },
                'contentLoaded': function(fileManager, node, content) {
                    var itemId = Compass.ErpApp.Utility.Encryption.MD5(node.data.id);
                    var centerRegion = Ext.getCmp('rails_db_admin').down('#centerRegion');
                    var item = centerRegion.getComponent(itemId);
                    var mode = Compass.ErpApp.Shared.CodeMirror.determineCodeMirrorMode(node.data.text);

                    if (Compass.ErpApp.Utility.isBlank(item)) {
                        item = Ext.create('Compass.ErpApp.Shared.CodeMirror', {
                            mode: mode,
                            sourceCode: content,
                            title: node.data.text,
                            closable: true,
                            itemId: itemId,
                            listeners: {
                                'save': function(codeMirror, content) {
                                    var waitMsg = Ext.Msg.wait("Saving Report...", "Status");
                                    Ext.Ajax.request({
                                        url: '/rails_db_admin/erp_app/desktop/reports/update_file',
                                        method: 'POST',
                                        params: {
                                            node: node.data.id,
                                            content: content
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
                        });

                        centerRegion.add(item);
                    }
                    centerRegion.setActiveTab(item);
                },
                'itemclick': function(view, record, item, index, e) {
                    e.stopEvent();
                    if (record.data.leaf && record.parentNode.data.isReport) {
                        me.editQuery(record.parentNode);
                    } else if (record.data.leaf) {
                        var fileType = record.data.id.split('.').pop();
                        if (Ext.Array.indexOf(['png', 'gif', 'jpg', 'jpeg', 'ico', 'bmp', 'tif', 'tiff'], fileType.toLowerCase()) > -1) {
                            this.fireEvent('showImage', this, record);
                        } else {
                            var msg = Ext.Msg.wait("Loading", "Retrieving contents...");
                            Ext.Ajax.request({
                                url: '/rails_db_admin/erp_app/desktop/reports/get_contents',
                                method: 'POST',
                                params: {
                                    node: record.data.id
                                },
                                success: function(response) {
                                    msg.hide();
                                    me.fireEvent('contentLoaded', me, record, response.responseText);
                                },
                                failure: function() {
                                    Ext.Msg.alert('Status', 'Error loading contents');
                                    msg.hide();
                                }
                            });
                        }
                    } else if (record.data.isReport) {
                        me.loadReport(record);
                        Ext.getCmp('reports_accordian_panel').down('railsdbadminreportssettings').expand();
                    }
                },
                'handleContextMenu': function(fileManager, node, item, index, e) {
                    var items = [];
                    if (node.isRoot()) {
                        items.push({
                            text: "New Report",
                            iconCls: 'icon-settings',
                            listeners: {
                                'click': function() {
                                    me.newReport();
                                }
                            }
                        }, {
                            text: "Upload",
                            iconCls: 'icon-theme-upload',
                            listeners: {
                                'click': function() {
                                    me.uploadReport();
                                }
                            }
                        });
                    } else if (node.data.isReport) {
                        items.push({
                            text: "Delete Report",
                            iconCls: 'icon-delete',
                            listeners: {
                                scope: node,
                                'click': function() {
                                    me.deleteReport(node.data.reportId);
                                }
                            }
                        }, {
                            text: 'Export',
                            iconCls: 'icon-document_out',
                            listeners: {
                                'click': function() {
                                    me.exportReport(node.data.reportId);
                                }
                            }
                        });
                    }

                    if (items.length > 0) {
                        var contextMenu = Ext.create('Ext.menu.Menu', {
                            items: items
                        });
                        contextMenu.showAt(e.xy);
                    }

                    return false;
                }
            }
        }, config);

        this.callParent([config]);
    }
});