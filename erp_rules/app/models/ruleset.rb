# create_table :rulesets do |t|
#   t.string :description
#   t.string :internal_identifier
#
#   t.timestamps
#
# end
#
# add_index :rulesets, :internal_identifier

class Ruleset < ActiveRecord::Base
  attr_protected :created_at, :updated_at

  has_many   :ruleset_rules, dependent: :destroy
  has_many   :business_rules, :through => :ruleset_rules, dependent: :destroy

  def rules
    business_rules
  end

  def execute(ctx)
    rules.each do |rule|
      ctx = rule.rule_eval(ctx)
    end

    ctx
  end

  def generate_rulebook
    puts "Generating rulebook..."
    puts "\n"
    puts "Rulebook name: " + self.description
    puts "\n"

    rules.each do |r|
      puts "Rule Name: " + r.description
      puts "Combination rule: " + r.match_combination_rule
      puts "\n"
      puts "Match criteria"
      puts "\n"

      r.rule_matching_conditions.each do |mc|
        puts "Matching Condition: " + mc.format_expression.to_s
      end

      puts "\n"
      puts "Actions"
      puts "\n"

      r.rule_actions.each do |a|
        puts "Rule Action: " + a.format_expression.to_s
      end

      puts "\n\n"

    end
  end

  def to_data_hash
    to_hash(only: [:id, :description, :created_at, :updated_at])
  end

end
