class CreateBusinessRules < ActiveRecord::Migration
  def up

    ## ruleset
    unless table_exists?(:rulesets)
      create_table :rulesets do |t|
        t.string :description
        t.string :internal_identifier

        t.timestamps

      end

      add_index :rulesets, :internal_identifier

    end

    ## rule
    unless table_exists?(:business_rules)
      create_table :business_rules do |t|
        t.string :description
        t.string :internal_identifier
        t.string :match_combination_rule

        t.timestamps

      end

      add_index :business_rules, :internal_identifier

    end

    ## ruleset rules
    unless table_exists?(:ruleset_rules)

      create_table :ruleset_rules do |t|
        t.integer :ruleset_id
        t.integer :business_rule_id

      end

      add_index :ruleset_rules, :ruleset_id
      add_index :ruleset_rules, :business_rule_id

    end

    ## standard boolean matching conditions
    unless table_exists?(:rule_matching_conditions)
      create_table :rule_matching_conditions do |t|
        t.string  :description
        t.string  :internal_identifier
        t.integer :eval_sequence
        t.string  :lhs
        t.string  :operator
        t.string  :rhs

        # foreign keys
        t.integer :business_rule_id

        t.timestamps
      end
    end

    ## rule action
    unless table_exists?(:rule_actions)
      create_table :rule_actions do |t|
        t.integer :business_rule_id
        t.string  :description
        t.string  :expression

      end

      add_index :rule_actions, :business_rule_id

    end

  end

  def down

    # Drop all tables, including those that were originally created then deleted
    [
      :rulesets, :business_rules, :ruleset_rules, :rule_matching_conditions, :rule_actions
    ].each do |tbl|
      if table_exists?(tbl)
        drop_table tbl
      end
    end

  end
end
