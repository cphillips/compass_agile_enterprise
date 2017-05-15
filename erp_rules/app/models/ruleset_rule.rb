# create_table :ruleset_rules do |t|
#   t.integer :ruleset_id
#   t.integer :business_rule_id
# 
# end
# 
# add_index :ruleset_rules, :ruleset_id
# add_index :ruleset_rules, :business_rule_id

class RulesetRule < ActiveRecord::Base
  attr_protected :created_at, :updated_at

  belongs_to :business_rule
  belongs_to :ruleset

end