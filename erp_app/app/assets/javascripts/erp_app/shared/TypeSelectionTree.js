Ext.define('Compass.ErpApp.Shared.TypeSelectionModel', {
    extend: 'Ext.data.Model',
    fields: [
        // ExtJs node fields
        {
            name: 'text',
            type: 'string'
        }, {
            name: 'leaf',
            type: 'boolean'
        }, {
            name: 'checked',
            type: 'boolean'
        }, {
            name: 'children'
        },
        // Custom fields
        {
            name: 'internalIdentifier',
            type: 'string',
            mapping: 'internal_identifier'
        }
    ]
});

Ext.define("Compass.ErpApp.Shared.TypeSelectionTree", {
    extend: "Ext.tree.Panel",
    alias: 'widget.typeselectiontree',

    title: 'Select Types',
    width: '100%',
    minHeight: 200,
    height: 200,
    rootVisible: false,
    cascadeSelectionUp: false,
    cascadeSelectionDown: false,
    canCreate: false,
    mixins: {
        field: 'Ext.form.field.Field'
    },

    createNewText: 'Create New',

    /**
     * @cfg {Array} availableTypes
     * Array of types that can be selected
     */
    availableTypes: null,

    /**
     * @cfg {Array} selectedTypes
     * Array of currently selected types
     */
    selectedTypes: [],

    /**
     * @cfg {String} typesUrl
     * Url to load types from.
     */
    typesUrl: null,

    /**
     * @cfg {String} typesRoot
     * Root attribute for types returned from the server.
     */
    typesRoot: null,

    /**
     * @cfg {Boolean} defaultParentType
     * default parent type if no parent is selected
     */
    defaultParentType: null,

    /**
     * @cfg {String} disabledNodeMessage
     * Message to display when a disabled type is clicked
     */
    disabledNodeMessage: 'This item can not be unselected',

    /**
     * @cfg {Array} unSelectableTypes
     * Array of types that can not be selected
     */
    unSelectableTypes: null,

    initComponent: function() {
        var me = this;

        if (me.availableTypes && me.availableTypes.length > 0 && me.availableTypes.first()['text']) {
            me.store = Ext.create('Ext.data.TreeStore', {
                model: 'Compass.ErpApp.Shared.TypeSelectionModel',
                folderSort: true,
                sorters: [{
                    property: 'text',
                    direction: 'ASC'
                }]
            });

            me.store.setRootNode({
                text: '',
                children: me.availableTypes
            });

            if (me.selectedTypes) {
                me.setSelectedTypes(me.selectedTypes);
            }
        } else {
            var params = {};

            if (!Ext.isEmpty(me.parentType)) {
                params['parent'] = me.parentType;
            } else {
                params['parent'] = me.defaultParentType;
            }

            me.store = Ext.create('Ext.data.TreeStore', {
                model: 'Compass.ErpApp.Shared.TypeSelectionModel',
                tree: me,
                folderSort: true,
                proxy: {
                    type: 'ajax',
                    url: me.typesUrl + '.tree',
                    reader: {
                        type: 'treereader',
                        root: me.typesRoot
                    }
                },
                sorters: [{
                    property: 'text',
                    direction: 'ASC'
                }]
            });

            if (!Ext.isEmpty(me.availableTypes)) {
                me.store.load({
                    params: {
                        ids: me.availableTypes.join(',')
                    },
                    callback: function() {
                        if (me.selectedTypes) {
                            me.setSelectedTypes(me.selectedTypes);
                        }
                    }
                });
            } else {
                me.store.load({
                    params: params,
                    callback: function() {
                        if (me.selectedTypes) {
                            me.setSelectedTypes(me.selectedTypes);
                        }
                    }
                });
            }
        }

        toolbarItems = [{
            xtype: 'button',
            text: 'Select All',
            iconCls: 'icon-info',
            handler: function(btn) {
                btn.up('typeselectiontree').toggleChecked(btn, true);
            }
        }];

        if (me.canCreate) {
            toolbarItems.push({
                xtype: 'button',
                text: me.createNewText,
                iconCls: 'icon-add',
                handler: function() {
                    me.showCreateType();
                }
            });
        }

        me.dockedItems = [{
            xtype: 'toolbar',
            items: toolbarItems
        }];

        me.callParent(arguments);

        me.addListener('beforecellclick', function(grid) {
            grid.ownerCt.suspendLayouts();
        });

        me.addListener('checkchange', function(node, checked) {
            var me = this;

            if (me.unSelectableTypes && Ext.Array.contains(me.unSelectableTypes.split(','), node.get('internalIdentifier'))) {
                Ext.Msg.warning('Warning', me.disabledNodeMessage);

                node.set('checked', !checked);

                return false;
            }

            if (me.cascadeSelectionUp) {
                var rootNode = me.getRootNode();
                var parentNode = node;
                var childChecked = false;

                while (parentNode != rootNode) {
                    childChecked = false;

                    parentNode.eachChild(function(child) {
                        if (child.get('checked')) {
                            childChecked = true;
                        }
                    });

                    if (!checked && !childChecked) {
                        parentNode.set('checked', checked);
                    }

                    if (!checked && childChecked) {
                        parentNode.set('checked', !checked);
                    }

                    if (checked && childChecked) {
                        parentNode.set('checked', checked);
                    }

                    parentNode = parentNode.parentNode;
                }
            }

            if (me.cascadeSelectionDown) {
                if (node.get('checked')) {
                    node.cascadeBy(function(childNode) {
                        childNode.set('checked', true);
                    });
                }
            }

            node.getOwnerTree().resumeLayouts();
            node.getOwnerTree().fireEvent('typesselected', node.getOwnerTree());
        });

        me.collapseAll();
    },

    showCreateType: function() {
        var me = this;

        var window = Ext.widget('window', {
            title: me.createNewText,
            modal: true,
            layout: 'fit',
            plain: true,
            buttonAlign: 'center',
            items: [{
                xtype: 'form',
                url: me.typesUrl,
                defaults: {
                    width: 375,
                    xtype: 'textfield'
                },
                bodyStyle: 'padding:5px 5px 0',
                items: [{
                    xtype: 'combo',
                    name: 'parent',
                    itemId: 'parentType',
                    emptyText: 'No Parent',
                    width: 320,
                    loadingText: 'Retrieving Types...',
                    store: Ext.create("Ext.data.Store", {
                        proxy: {
                            type: 'ajax',
                            url: me.typesUrl + '.json',
                            reader: {
                                type: 'json',
                                root: me.typesRoot
                            },
                            extraParams: {
                                parent: me.defaultParentType
                            }
                        },
                        fields: [{
                            name: 'internal_identifier'
                        }, {
                            name: 'description'

                        }]
                    }),
                    forceSelection: true,
                    allowBlank: true,
                    editable: false,
                    fieldLabel: 'Parent',
                    mode: 'remote',
                    displayField: 'description',
                    valueField: 'internal_identifier',
                    triggerAction: 'all',
                    listConfig: {
                        tpl: '<div class="my-boundlist-item-menu">No Parent</div><tpl for="."><div class="x-boundlist-item">{description}</div></tpl>',
                        listeners: {
                            el: {
                                delegate: '.my-boundlist-item-menu',
                                click: function() {
                                    window.down('#parentType').clearValue();
                                }
                            }
                        }
                    }
                }, {
                    fieldLabel: 'Name',
                    allowBlank: false,
                    name: 'description'
                }]
            }],
            buttons: [{
                text: 'Submit',
                listeners: {
                    'click': function(button) {
                        var window = button.findParentByType('window');
                        var formPanel = window.down('form');

                        if (formPanel.isValid()) {
                            formPanel.getForm().submit({
                                timeout: 30000,
                                waitMsg: 'Creating type...',
                                params: {
                                    default_parent: me.defaultParentType
                                },
                                success: function(form, action) {
                                    var responseObj = Ext.decode(action.response.responseText);

                                    if (responseObj.success) {
                                        var values = formPanel.getValues();
                                        var parentNode = me.getRootNode();

                                        if (!Ext.isEmpty(values.parent)) {
                                            parentNode = parentNode.findChildBy(function(node) {
                                                if (node.data.internalIdentifier == values.parent) {
                                                    return true;
                                                }
                                            }, this, true);
                                        }

                                        if (parentNode) {
                                            parentNode.set('leaf', false);
                                        } else {
                                            parentNode = me.getRootNode();
                                        }

                                        parentNode.appendChild({
                                            text: responseObj[me.typesRoot.singularize()].description,
                                            internalIdentifier: responseObj[me.typesRoot.singularize()].internal_identifier,
                                            checked: true,
                                            leaf: true,
                                            children: []
                                        });

                                        window.close();
                                    } else {
                                        Ext.Msg.alert("Error", responseObj.message);
                                    }
                                },
                                failure: function(form, action) {
                                    Compass.ErpApp.Utility.handleFormFailure(action);
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
        });
        window.show();
    },

    getSelectedRecords: function() {
        var me = this;
        var records = [];

        me.getRootNode().cascadeBy(function(node) {
            if (me.cascadeSelectionUp) {
                var childChecked = false;
                node.eachChild(function(child) {
                    if (child.get('checked')) {
                        childChecked = true;
                    }
                });
                if (node.get('checked') && !childChecked) {
                    records.push(node);
                }
            } else {
                if (node.get('checked')) {
                    records.push(node);
                }
            }
        });
        return Ext.Array.clean(records);
    },

    getSelectedTypes: function() {
        var me = this;
        var types = [];

        Ext.Array.forEach(me.getSelectedRecords(), function(record) {
            types.push(record.get('internalIdentifier'));
        });

        return Ext.Array.clean(types);
    },

    setAvailableTypes: function(types) {
        var me = this;

        me.store.setRootNode({
            text: '',
            children: types
        });
    },

    setSelectedTypes: function(types) {
        var me = this;

        types = Ext.Array.clean(types.split(','));

        me.getRootNode().cascadeBy(function(node) {
            if (Ext.Array.contains(types, node.get('internalIdentifier'))) {
                node.set('checked', true);
                var parentNode = node.parentNode;

                if (me.cascadeSelectionUp) {
                    while (parentNode != me.getRootNode()) {
                        parentNode.set('checked', true);
                        parentNode.expand();
                        parentNode = parentNode.parentNode;
                    }
                }

                // expand nodes
                while (parentNode != me.getRootNode()) {
                    parentNode.expand();
                    parentNode = parentNode.parentNode;
                }
            }
        });
    },

    setUnSelectableTypes: function(types) {
        var me = this;

        me.unSelectableTypes = types;
    },

    toggleChecked: function(btn, checked) {
        var me = this;

        me.getRootNode().cascadeBy(function(node) {
            if (!me.unSelectableTypes || !Ext.Array.contains(me.unSelectableTypes.split(','), node.get('internalIdentifier'))) {
                node.set('checked', checked);
            }
        });

        if (checked) {
            btn.setText('Unselect All');
        } else {
            btn.setText('Select All');
        }

        btn.setHandler(function() {
            me.toggleChecked(btn, !checked);
        });
    },

    /*
     * Field methods
     */

    getValue: function() {
        var me = this;

        return me.getSelectedTypes().join(',');
    },

    setValue: function(value) {
        var me = this;

        if (value) {
            me.setSelectedTypes(value);
        }
    },

    getSubmitData: function() {
        var me = this,
            data = null;
        if (!me.disabled && me.submitValue) {
            data = {};
            data[me.getName()] = me.getValue();
        }
        return data;
    },

    validate: function() {
        if (this.initialConfig.allowBlank !== true && Ext.isEmpty(this.getSelectedTypes())) {
            if (this.getEl())
                this.getEl().setStyle('border', 'solid 1px red');

            return false;
        } else {
            if (this.getEl())
                this.getEl().setStyle('border', '');

            return true;
        }
    }
});