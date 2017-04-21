module ErpBaseErpSvcs
  module Extensions
    module ActiveRecord
      module ActsAsErpType

        @@models = []

        def self.included(base)
          base.extend(ClassMethods)
        end

        def self.models
          @@models
        end

        # declare the class level helper methods which
        # will load the relevant instance methods
        # defined below when invoked
        module ClassMethods

          def acts_as_erp_type

            validates_exclusion_of :internal_identifier, :in => %w[root roots children child id lft rgt parent_id level parent ancestors self_and_ancestors siblings self_and_siblings descendants self_and_descendants leaves]

            # this is at the class level
            # add any class level manipulations you need here, like has_many, etc.
            extend ActsAsErpType::ActsAsSingletonMethods
            include ActsAsErpType::ActsAsInstanceMethods

            if ::ActiveRecord::Base.connection.tables.include?(self.table_name)
              # find each valid value for the domain type (erp_type) in question
              # we will then create a class method with the name of the internal identifier
              # for that type
              valid_values = self.all

              # the class method will return a populated instance of the correct type
              valid_values.each do | vv |
                (class << self; self; end).instance_eval { define_method vv.internal_identifier, Proc.new{vv} } unless vv.internal_identifier.nil?
              end
            end

            ActsAsErpType.models.push(self.name)
            ActsAsErpType.models.uniq!
          end

          def belongs_to_erp_type(model_id = nil, options = {})

            @model_id = model_id
            self.belongs_to model_id, options
            extend ActsAsErpType::BelongsToSingletonMethods
            include ActsAsErpType::BelongsToInstanceMethods

          end

        end

        # Adds singleton methods.
        module ActsAsSingletonMethods

          def valid_types
            self.all.collect{ |type| type.internal_identifier.to_sym }
          end

          def valid_type?( type_name_string )
            sym_list = self.all.collect{ |type| type.internal_identifier.to_sym }
            sym_list.include?(type_name_string.to_sym)
          end

          def eid( external_identifier_string )
            where('external_identifier = ?', external_identifier_string.to_s).first
          end

          def iid( internal_identifier_string )
            where('internal_identifier = ?', internal_identifier_string.to_s).first
          end

          def find_or_create(internal_identifier, description)
            erp_type = iid(internal_identifier)

            unless erp_type
              create!(internal_identifier: internal_identifier, description: description)
            end

            erp_type
          end

          def generate_unique_iid(name)
            iid = name.to_iid

            iid_exists = true
            iid_test = iid
            iid_counter = 1
            while iid_exists
              if self.where(internal_identifier: iid_test).first
                iid_test = "#{iid}_#{iid_counter}"
                iid_counter += 1
              else
                iid_exists = false
                iid = iid_test
              end
            end

            iid
          end

        end

        module BelongsToSingletonMethods

          def fbet( domain_value, options = {})
            find_by_erp_type( domain_value, options )
          end

          def find_by_erp_type(domain_value, options = {})

            # puts "options...."
            # puts options[:class]
            # puts options[:foreign_key]

            erp_type = options[:class] || @model_id
            fk_str = options[:foreign_key] || erp_type.to_s + '_id'

            #***************************************************************
            # uncomment these lines for a variety of debugging information
            #***************************************************************
            # klass = self.to_s.underscore + '_type'
            # puts "default class name"
            # puts klass

            # puts "model id"
            # puts @model_id
            #
            # puts "finding by erp type"
            # puts "self is: #{self}"
            # puts "type is: #{erp_type}"

            # puts "fk_str for in clause..."
            # puts fk_str

            type_klass = Kernel.const_get( erp_type.to_s.camelcase )
            in_clause_array = type_klass.send( domain_value.to_sym )

            where(fk_str + ' in (?)', in_clause_array)

          end

          def fabet( domain_value, options = {} )
            find_all_by_erp_type( domain_value, options )
          end

          def find_all_by_erp_type( domain_value, options = {} )

            erp_type = options[:class] || @model_id
            fk_str = options[:foreign_key] || erp_type.to_s + '_id'

            type_klass = Kernel.const_get( erp_type.to_s.camelcase )
            in_clause_array = type_klass.send( domain_value.to_sym ).full_set

            #puts "id for in clause..."
            #id_str = erp_type.to_s + '_id'

            where(fk_str + ' in (?)', in_clause_array)

          end

        end


        # Adds instance methods.
        module ActsAsInstanceMethods

          def to_s
            self.try(:description) ? self.try(:description) : self.try(:id)
          end

          # Alias for to_s
          def to_label
            to_s
          end

          def to_data_hash
            to_hash(only: [:id, :description, :internal_identifier, :created_at, :updated_at])
          end

        end

        # Adds instance methods.
        module BelongsToInstanceMethods

          # def instance_method_for_belongs_to
          #   puts "Instance with ID #{self.id}"
          # end

        end
      end
    end
  end
end
