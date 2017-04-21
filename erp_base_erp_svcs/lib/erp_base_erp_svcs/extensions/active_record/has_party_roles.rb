module ErpBaseErpSvcs
  module Extensions
    module ActiveRecord
      module HasPartyRoles
        def self.included(base)
          base.extend(ClassMethods)
        end

        module ClassMethods
          def has_party_roles
            extend HasPartyRoles::SingletonMethods
            include HasPartyRoles::InstanceMethods

            has_many :entity_party_roles, :as => :entity_record, dependent: :destroy
            has_many :role_types, :through => :entity_party_roles
          end
        end

        module SingletonMethods
          # Scope by a set of RoleTypes
          #
          # @param role_types [Integer | RoleType | Array] either a id of RoleType record, a RoleType record,
          # an array of RoleType records or an array of RoleType ids
          def with_party_role_types(role_types)
            joins(:entity_party_roles)
            .where(entity_party_roles: {role_type_id: role_types})
          end

          # Scope by a set of parties with the passed role_types
          #
          # @param party [Integer | Party | Array] either a id of Party record, a Party record,
          # an array of Party records or an array of Party ids
          # @param role_types [Integer | RoleType | Array] either a id of RoleType record, a RoleType record,
          # an array of RoleType records or an array of RoleType ids
          def with_party_role(parties, role_types)
            joins(:entity_party_roles).where(entity_party_roles: {role_type_id: role_types})
            .where(entity_party_roles: {party_id: parties})
          end
        end

        module InstanceMethods
          def add_party_with_role(party, role_type)
            entity_party_role = EntityPartyRole.where(party_id: party,
                                                      role_type_id: role_type,
                                                      entity_record_id: self.id,
                                                      entity_record_type: self.class.name).first

            unless entity_party_role
              entity_party_role = EntityPartyRole.create(party: party,
                                                         role_type: role_type,
                                                         entity_record: self)
            end

            entity_party_role
          end

          def remove_party_with_role(party, role_type)
            entity_party_role = EntityPartyRole.where(party_id: party,
                                                      role_type_id: role_type,
                                                      entity_record_id: self.id,
                                                      entity_record_type: self.class.name).first

            if entity_party_role
              entity_party_role.destroy
            end
          end

          def find_parties_by_role(role_types)
            unless role_types.is_a? Array
              role_types = [role_types]
            end

            role_types = RoleType.find_child_role_types(role_types)

            entity_party_roles.where(role_type_id: role_types).collect(&:party)
          end

          def find_party_by_role(role_types)
            unless role_types.is_a? Array
              role_types = [role_types]
            end

            role_types = RoleType.find_child_role_types(role_types)

            entity_party_role = entity_party_roles.where(role_type_id: role_types).first

            if entity_party_role
              entity_party_role.party
            else
              nil
            end
          end
        end

      end # HasPartyRoles
    end # ActiveRecord
  end # Extensions
end # ErpBaseErpSvcs
