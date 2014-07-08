module ErpApp
  class DynamicFormField
=begin  
  Field Types TODO
  special:
  codemirror
  test password field
  
  complex (for future implementation):
  concatenated
  calculated
=end

#  options = {
#    :fieldLabel => Field label text string
#    :name => Field variable name string
#    :allowBlank => required true or false
#    :value => prepopulated default value string
#    :readOnly => disabled true or false
#    :maxLength => maxLength integer
#    :width => size integer
#  }

    ##################
    # SPECIAL FIELDS #
    ##################
    def self.email(options={})
      options[:validator_function] = 'validateEmail(v)'
      DynamicFormField.basic_field('textfield', options)
    end
    
    def self.numberfield(options={})
      DynamicFormField.basic_field('numberfield', options)
    end

    def self.password(options={})
      options[:inputType] = 'password'
      DynamicFormField.basic_field('textfield', options)
    end
    
    def self.datefield(options={})
      DynamicFormField.basic_field('datefield', options)
    end
    
    def self.timefield(options={})
      DynamicFormField.basic_field('timefield', options)
    end
    
    def self.yesno(selections=[], options={})
      selections = [['yes', 'Yes'],['no', 'No']]
      DynamicFormField.basic_field('combobox', options, selections)
    end
    
    # a combobox that dynamically pulls options from a related model
    def self.related_combobox(model='', displayField = '', options={})
      options[:forceSelection] = true if options[:forceSelection].nil?
      options[:displayField] = displayField

      options[:extraParams] = {
        :model => model,
        :displayField => displayField
      }

      options[:fields] = [
                          { :name => 'id' },
                          { :name => displayField }
                         ]

      DynamicFormField.basic_field('related_combobox', options)
    end

    def self.ckeditor(options={})
      options[:height] = 300 if options[:height].nil? 
      options[:width] = 850 if options[:width].nil? 

      if options[:ckEditorConfig].nil?
        options[:ckEditorConfig] = {
          #    :width => options[:width],
          #    :height => options[:height],
          :extraPlugins => 'compasssave,jwplayer',
          :toolbar => [
                       ['Source','-','CompassSave','Preview','Print'],
                       ['Cut','Copy','Paste','PasteText','PasteFromWord'],
                       ['Undo','Redo'],
                       ['Find','Replace'],
                       ['SpellChecker','-','SelectAll'],
                       ['TextColor','BGColor'],
                       ['Bold','Italic','Underline','Strike'],
                       ['Subscript','Superscript','-','jwplayer'],
                       ['Table','NumberedList','BulletedList'],
                       ['Outdent','Indent','Blockquote'],
                       ['JustifyLeft','JustifyCenter','JustifyRight','JustifyBlock'],
                       ['BidiLtr','BidiRtl'],
                       ['Link','Unlink','Anchor'],
                       ['HorizontalRule','SpecialChar','PageBreak'],
                       ['ShowBlocks','RemoveFormat'],
                       ['Styles','Format','Font','FontSize' ],
                       ['Maximize','-','About']
                      ]
        }
      end

      DynamicFormField.basic_field('ckeditor', options)
    end

    ################
    # BASIC FIELDS #
    ################
    # ComboBox with a static store, if you need a dynamic store use DynamicFormField.related_combobox
    # selections is an array of tuples, i.e. [['AL', 'Alabama'],['AK', 'Alaska']] - [value, text]
    def self.combobox(selections=[], options={})
      options[:forceSelection] = true if options[:forceSelection].nil?
      DynamicFormField.basic_field('combobox', options, selections)
    end

    def self.textfield(options={})
      DynamicFormField.basic_field('textfield', options)
    end

    def self.displayfield(options={})
      DynamicFormField.basic_field('displayfield', options)
    end

    def self.textarea(options={})
      options[:height] = 100 if options[:height].nil? 
      DynamicFormField.basic_field('textarea', options)
    end

    def self.checkbox(options={})
      DynamicFormField.basic_field('checkbox', options)
    end

    def self.filefield(options={})
      DynamicFormField.basic_field('filefield', options)
    end

    def self.hiddenfield(options={})
      DynamicFormField.basic_field('hiddenfield', options)
    end

    # alias
    def self.hidden(options={})
      DynamicFormField.hiddenfield(options={})
    end

    def self.basic_field(xtype, options={}, selections=[])
      options = DynamicFormField.set_default_field_options(options)

      field = {
        :xtype => xtype,
        :fieldLabel => options[:fieldLabel],
        :name => options[:name],
        :value => options[:value],
        :allowBlank => options[:allowBlank],  
        :readOnly => options[:readOnly],
        :width =>options[:width],
        :height => options[:height],
        :labelWidth => options[:labelWidth],
        :display_in_grid => options[:display_in_grid],
        :searchable => options[:display_in_grid]
      }

      field[:buttonText] = options[:buttonText] unless options[:buttonText].blank?
      field[:displayField] = options[:displayField] unless options[:displayField].blank?
      field[:disabled] = options[:disabled] unless options[:disabled].nil?
      field[:editable] = options[:editable] unless options[:editable].nil?
      field[:emptyText] = options[:emptyText] unless options[:emptyText].blank?
      field[:extraParams] = options[:extraParams] unless options[:extraParams].blank?
      field[:fields] = options[:fields] unless options[:fields].blank?
      field[:forceSelection] = options[:forceSelection] unless options[:forceSelection].nil?
      field[:hidden] = options[:hidden] unless options[:hidden].nil?
      field[:hideTrigger] = options[:hideTrigger] unless options[:hideTrigger].nil?
      field[:hideMode] = options[:hideMode] unless options[:hideMode].blank?
      field[:labelAlign] = options[:labelAlign] unless options[:labelAlign].blank?
      field[:mapping] = options[:mapping] unless options[:mapping].blank?
      field[:minLength] = options[:minLength] unless options[:minLength].nil?
      field[:maxLength] = options[:maxLength] unless options[:maxLength].nil?
      field[:minValue] = options[:minValue] unless options[:minValue].nil?
      field[:maxValue] = options[:maxValue] unless options[:maxValue].nil?
      field[:msgTarget] = options[:msgTarget] unless options[:msgTarget].blank?
      field[:regexText] = options[:regexText] unless options[:regexText].blank?
      field[:url] = options[:url] unless options[:url].blank?
      field[:vtype] = options[:vtype] unless options[:vtype].blank?
      field[:validation_regex] = options[:validation_regex] unless options[:validation_regex].blank?
      field[:validator_function] = options[:validator_function] unless options[:validator_function].blank?

      field[:store] = selections if selections and selections != []    
      
      field
    end
    
    def self.set_default_field_options(options={})
      options[:fieldLabel] = '' if options[:fieldLabel].nil?
      options[:name] = '' if options[:name].nil?
      options[:allowBlank] = true if options[:allowBlank].nil?
      options[:readOnly] = false if options[:readOnly].nil?
      options[:minLength] = nil if options[:minLength].nil?
      options[:maxLength] = nil if options[:maxLength].nil?
      options[:width] = 200 if options[:width].nil?
      options[:height] = nil if options[:height].nil?
      options[:labelWidth] = 75 if options[:labelWidth].nil?
      options[:display_in_grid] = true if options[:display_in_grid].nil?
      options[:searchable] = true if options[:searchable].nil?
      
      options
    end
    
  end
end
