Ext.define("Compass.ErpApp.Desktop.Applications.FileManager", {
    extend: "Ext.ux.desktop.Module",
    id: 'file_manager-win',
    setWindowStatus: function (status) {
        this.win.setStatus(status);
    },

    clearWindowStatus: function () {
        this.win.clearStatus();
    },

    init: function () {
        this.launcher = {
            text: 'File Manager',
            iconCls: 'icon-file-manager',
            handler: this.createWindow,
            scope: this
        };
    },
    createWindow: function () {
        var self = this;
        var desktop = this.app.getDesktop();
        var win = desktop.getWindow('file_manager');
        if (!win) {

            var contentCardPanel = Ext.create('Ext.Panel', {
                layout: 'card',
                autoDestroy: true,
                frame: false,
                border: false,
                region: 'center'
            });

            var fileTreePanel = Ext.create('Compass.ErpApp.Shared.FileManagerTree', {
                    allowDownload: true,
                    addViewContentsToContextMenu: true,
                    region: 'west',
                    rootVisible: true,
                    containerScroll: true,
                    standardUploadUrl: '/erp_app/desktop/file_manager/base/upload_file',
                    border: false,
                    width: 250,
                    frame: true,
                    listeners: {
                        'showImage': function (fileManager, record) {
                            var itemId = Compass.ErpApp.Utility.Encryption.MD5(record.data.id);

                            contentCardPanel.removeAll(true);
                            contentCardPanel.add(Ext.create('Ext.panel.Panel', {
                                itemId: itemId,
                                closable: true,
                                layout: 'fit',
                                html: '<img src="/erp_app/desktop/file_manager/base/download_file/?path=' + record.data.id + '&token=' + Math.round(Math.random() * 10000000) + '" />'
                            }));
                            contentCardPanel.getLayout().setActiveItem(0);
                            return false;
                        },
                        'contentLoaded': function (fileManager, record, content) {
                            var path = record.data.id,
                                itemId = Compass.ErpApp.Utility.Encryption.MD5(path),
                                mode = Compass.ErpApp.Shared.CodeMirror.determineCodeMirrorMode(path);

                            contentCardPanel.removeAll(true);
                            contentCardPanel.add({
                                itemId: itemId,
                                disableToolbar: !currentUser.hasRole('admin'),
                                xtype: 'codemirror',
                                mode: mode,
                                sourceCode: content,
                                listeners: {
                                    'save': function (codeMirror, content) {
                                        self.setWindowStatus('Saving...');
                                        Ext.Ajax.request({
                                            url: '/erp_app/desktop/file_manager/base/update_file',
                                            method: 'POST',
                                            params: {
                                                node: path,
                                                content: content
                                            },
                                            success: function (response) {
                                                var obj = Ext.decode(response.responseText);
                                                if (obj.success) {
                                                    self.clearWindowStatus();
                                                }
                                            },
                                            failure: function (response) {
                                                self.clearWindowStatus();
                                                Ext.Msg.alert('Error', 'Error saving content');
                                            }
                                        });
                                    }
                                }
                            });
                            contentCardPanel.getLayout().setActiveItem(0);
                        },
                        'filedeleted': function (fileManager, record) {
                            var itemId = itemId = Compass.ErpApp.Utility.Encryption.MD5(record.data.id);
                            var card = contentCardPanel.down('#' + itemId);

                            if (card) {
                                card.destroy();
                            }
                        }
                    }
                }
            );

            win = desktop.createWindow({
                id: 'file_manager',
                title: 'File Manager',
                maximized: true,
                width: 1000,
                height: 550,
                autoDestroy: true,
                iconCls: 'icon-file-manager-light',
                shim: false,
                animCollapse: false,
                constrainHeader: true,
                layout: 'border',
                items: [fileTreePanel, contentCardPanel],
                listeners: {
                    'destroy': function () {
                        fileTreePanel.destroy();
                        contentCardPanel.destroy();
                    }
                }
            });

            this.win = win;
        }
        win.show();
        return win;
    }
});
