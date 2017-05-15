module API
  module V1
    class BusinessRulesController < BaseController

      def index
        rule_set = Ruleset.find(params[:ruleset_id])

        render json: {success: true, business_rules: rule_set.business_rules.collect{|business_rule| business_rule.to_data_hash}}
      end

      def create
        begin
          ActiveRecord::Base.transaction do
            rule_set = Ruleset.find(params[:ruleset_id])

            data = Hash.symbolize_keys(JSON.parse(params[:data]))

            business_rule = rule_set.business_rules.create(description: data[:description], internal_identifier: data[:internal_identifier])

            data[:conditions].each do |condition|
              business_rule.rule_matching_conditions.create(lhs: condition[:lhs], operator: condition[:operator], rhs: condition[:rhs])
            end

            data[:actions].each do |action|
              business_rule.rule_actions.create(expression: action)
            end

            render json: {success: true, business_rule: business_rule.to_data_hash}

          end
        rescue Exception => ex
          Rails.logger.error(ex.message)
          Rails.logger.error(ex.backtrace.join("\n"))

          render json: {success: false, message: 'Error. Please try again later.'}

        end
      end

      def update
        begin
          ActiveRecord::Base.transaction do
            business_rule = BusinessRule.find(params[:id])

            data = Hash.symbolize_keys(JSON.parse(params[:data]))

            business_rule.description = data[:description];
            business_rule.internal_identifier = data[:internal_identifier];
            business_rule.save!

            business_rule.rule_matching_conditions.destroy_all
            data[:conditions].each do |condition|
              business_rule.rule_matching_conditions.create(lhs: condition[:lhs], operator: condition[:operator], rhs: condition[:rhs])
            end

            business_rule.rule_actions.destroy_all
            data[:actions].each do |action|
              business_rule.rule_actions.create(expression: action)
            end

            render json: {success: true, business_rule: business_rule.to_data_hash}

          end
        rescue Exception => ex
          Rails.logger.error(ex.message)
          Rails.logger.error(ex.backtrace.join("\n"))

          render json: {success: false, message: 'Error. Please try again later.'}

        end
      end

      def destroy
        business_rule = BusinessRule.find(params[:id])

        render json: {success: business_rule.destroy}
      end

    end # BusinessRulesController
  end # V1
end # API
