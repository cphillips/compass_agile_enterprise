class RelationshipType < ActiveRecord::Base
  attr_protected :created_at, :updated_at

  acts_as_erp_type
  acts_as_nested_set
  include ErpTechSvcs::Utils::DefaultNestedSetMethods

  belongs_to :valid_from_role, :class_name => "RoleType", :foreign_key => "valid_from_role_type_id"
  belongs_to :valid_to_role, :class_name => "RoleType", :foreign_key => "valid_to_role_type_id"

  # find existing role type or create it and return it.  Parent can be passed
  # which will scope this type by the parent
  def self.find_or_create(to_role_type, from_role_type, parent=nil)
    if to_role_type.is_a? String 
      to_role_type = RoleType.iid(to_role_type)
    end

    if from_role_type.is_a? String 
      from_role_type = RoleType.iid(from_role_type)
    end

    relationship_type = if parent
                          parent.children.where('valid_to_role_type_id = ? and valid_from_role_type_id = ?',
                                                to_role_type, from_role_type).first
                        else
                          RelationshipType.where('valid_to_role_type_id = ? and valid_from_role_type_id = ?',
                                                 to_role_type, from_role_type).first
                        end

    unless relationship_type
      relationship_type = RelationshipType.create(
          description: "#{from_role_type.description} to #{to_role_type.description}",
          internal_identifier: "#{from_role_type.internal_identifier}_to_#{to_role_type.internal_identifier}",
          valid_from_role: from_role_type,
          valid_to_role: to_role_type)

      if parent
        relationship_type.move_to_child_of(parent)
      end
    end

    relationship_type
  end
end
