# create_table :business_rules do |t|
#   t.string :description
#   t.string :internal_identifier
#   t.string :match_combination_rule
#
#   t.timestamps
#
# end
#
# add_index :business_rules, :internal_identifier

class BusinessRule < ActiveRecord::Base
  attr_protected :created_at, :updated_at

  has_many   :ruleset_rules
  has_many   :rulesets, :through => :ruleset_rules

  has_many :rule_matching_conditions, :dependent => :destroy
  has_many :rule_actions, :dependent => :destroy

  def matching_conditions
    rule_matching_conditions
  end

  def actions
    rule_actions
  end

  def rule_eval(ctx)
    if match_combination_rule == "any"

      self.rule_matching_conditions.each do |mc|
        if mc.matches?(ctx)
          self.rule_actions.each do |action|
            ctx = action.execute(ctx)
          end
        end
      end

    else   # "all"

      all_match = true
      self.rule_matching_conditions.each do |mc|
        if !(mc.matches?(ctx))
          all_match = false
          break
        end

      end

      if all_match
        self.rule_actions.each do |action|
          ctx = action.execute(ctx)
        end
      end

    end

    ctx
  end

  def to_data_hash
    data = to_hash(only: [:description, :id, :internal_identifier, :created_at, :updated_at])

    data[:rule_matching_conditions] = rule_matching_conditions.collect(&:to_data_hash)
    data[:rule_actions] = rule_actions.collect(&:to_data_hash)

    data
  end

end
