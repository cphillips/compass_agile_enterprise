# create_table :rule_actions do |t|
#   t.integer :business_rule_id
#   t.string  :description
#   t.string  :expression
# 
# end
# 
# add_index :rule_actions, :business_rule_id

class RuleAction < ActiveRecord::Base
  attr_protected :created_at, :updated_at

  belongs_to :business_rules

  def execute(ctx)
    action_arr = expression.split('=')
    tag = action_arr[0].to_s.strip.to_sym
    val = action_arr[1].to_s.strip
    ctx[tag] = val

    ctx
  end

  def format_expression
    description
  end

  def to_data_hash
    to_hash(only: [:id, :description, :expression])
  end

end