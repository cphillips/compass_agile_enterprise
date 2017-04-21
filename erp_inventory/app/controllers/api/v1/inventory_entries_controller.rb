module API
  module V1
    class InventoryEntriesController < BaseController

=begin

  @api {get} /api/v1/inventory_entries Index
  @apiVersion 1.0.0
  @apiName GetInventoryEntries
  @apiGroup InventoryEntry

  @apiSuccess {Boolean} success True if the request was successful
  @apiSuccess {Array} inventory_entries List of InventoryEntry records
  @apiSuccess {Number} inventory_entries.id Id of InventoryEntry

=end

      def index
        sort = nil
        dir = nil
        limit = nil
        start = nil

        sort_hash = params[:sort].blank? ? {} : Hash.symbolize_keys(JSON.parse(params[:sort]).first)

        sort = sort_hash[:property] || 'description'
        dir = sort_hash[:direction] || 'ASC'

        limit = params[:limit].blank? ? nil : params[:limit]
        start = params[:start].blank? ? nil : params[:start]

        query_filter = params[:query_filter].blank? ? {} : Hash.symbolize_keys(JSON.parse(params[:query_filter]))

        if params[:query]
          query_filter[:keyword] = params[:query].strip
        end

        # hook method to apply any scopes passed via parameters to this api
        inventory_entries = InventoryEntry.apply_filters(query_filter)

        inventory_entries = inventory_entries.by_tenant(current_user.party.dba_organization)

        if sort and dir
          inventory_entries = inventory_entries.order("#{sort} #{dir}")
        end

        total_count = inventory_entries.count

        if start and limit
          inventory_entries = inventory_entries.offset(start).limit(limit)
        end

        render :json => {success: true, total_count: total_count, inventory_entries: inventory_entries.collect(&:to_data_hash)}
      end

=begin

  @api {get} /api/v1/inventory_entries/:id Index
  @apiVersion 1.0.0
  @apiName GetInventoryEntry
  @apiGroup InventoryEntry

  @apiSuccess {Boolean} success True if the request was successful
  @apiSuccess {Array} inventory_entry InventoryEntry record
  @apiSuccess {Number} inventory_entry.id Id of InventoryEntry

=end

      def show
        inventory_entry = InventoryEntry.find(params[:id])

        render :json => {success: true, inventory_entry: inventory_entry.to_data_hash}
      end

    end # InventoryEntriesController
  end # V1
end # API
