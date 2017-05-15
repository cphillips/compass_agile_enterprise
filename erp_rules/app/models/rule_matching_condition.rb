# create_table :rule_matching_conditions do |t|
#   t.string  :description
#   t.string  :internal_identifier
#   t.integer :eval_sequence
#   t.string  :lhs
#   t.string  :operator
#   t.string  :rhs
#
#   # foreign keys
#   t.integer :business_rule_id
#
#   t.timestamps
# end

class RuleMatchingCondition < ActiveRecord::Base
  attr_protected :created_at, :updated_at

  belongs_to :business_rules

  # Format the expression as lhs + operator + rhs
  #
  def format_expression
    if operator == 'include?'
      # wrap lhs in context
      formatted_lhs = "!ctx[:#{lhs}].nil? && ctx[:#{lhs}]."
    else
      # wrap lhs in context
      formatted_lhs = "!ctx[:#{lhs}].nil? && ctx[:#{lhs}]"
    end

    # If the rhs is an integer then we do not want to quote it, if it is a string we need to quote it
    if rhs.is_integer?
      formatted_rhs = rhs
    else
      formatted_rhs = "'" + rhs + "'"
    end

    formatted_lhs + operator + formatted_rhs
  end

  # check if the rule matches
  #
  def matches?(ctx)
    # Russell - there may be a better way to do this. I could not get eval to
    # consistently treat strings and numbers for conversion purposes, so I had
    # to do this to FORCE a conversion to strings so that, from an external
    # perspective, you could treat question = "Y" and bp = 125 the same

    eval( format_expression )
  end

  def to_data_hash
    to_hash(only: [:id, :description, :internal_identifier, :lhs, :operator, :rhs])
  end

end
