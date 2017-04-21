module API
  module V1
    class TimeEntriesController < BaseController

=begin

  @api {post} /api/v1/time_entries Create
  @apiVersion 1.0.0
  @apiName CreateTimeEntry
  @apiGroup TimeEntry

  @apiParam {Number} regular_hours_in_seconds Regular hours in seconds for this TimeEntry
  @apiParam {Number} [overtime_hours_in_seconds] Overtime hours in seconds for this TimeEntry
  @apiParam {DateTime} [from_datetime] From DateTime for this TimeEntry
  @apiParam {DateTime} [thru_datetime] Thru DateTime for this TimeEntry
  @apiParam {String} [comment] Comment for this Time Entry
  @apiParam {Number} [work_effort_id] ID of WorkEffort for this TimeEntry
  @apiParam {Number} [timesheet_id] ID of Timesheet to associate this TimeEntry to

  @apiSuccess {Boolean} success True if the request was successful
  @apiSuccess {Object} time_entry TimeEntry
  @apiSuccess {Number} time_entry.id Id of TimeEntry
  @apiSuccess {String} time_entry.regular_hours_in_seconds Regular hours in seconds of TimeEntry
  @apiSuccess {String} time_entry.overtime_hours_in_seconds Overtime hours in seconds of TimeEntry
  @apiSuccess {String} time_entry.comment Comment for this TimeEntry
  @apiSuccess {DateTime} time_entry.from_datetime From DateTime for TimeEntry
  @apiSuccess {DateTime} time_entry.thru_datetime Thru DateTime for TimeEntry
  @apiSuccess {DateTime} time_entry.created_at When the TimeEntry was created
  @apiSuccess {DateTime} time_entry.updated_at When the TimeEntry was updated

=end

      def create
        begin
          ActiveRecord::Base.connection.transaction do
            party = current_user.party

            time_entry = TimeEntry.new(
              manual_entry: true
            )

            if params[:from_datetime]
              time_entry.from_datetime = params[:from_datetime].to_time
            end

            if params[:thru_datetime]
              time_entry.from_datetime = params[:thru_datetime].to_time
            end

            if params[:comment]
              time_entry.comment = params[:comment].strip
            end

            if params[:regular_hours_in_seconds]
              time_entry.regular_hours_in_seconds = params[:regular_hours_in_seconds].to_i
            end

            if params[:overtime_hours_in_seconds]
              time_entry.overtime_hours_in_seconds = params[:regular_hours_in_seconds].to_i
            end

            if params[:work_effort_id]
              time_entry.work_effort = params[:work_effort_id]
            end

            # if a timesheet id is passed associate to that timesheet if not associate to
            # the current user's timesheet
            if params[:timesheet_id]
              time_entry.timesheet_id = params[:timesheet_id]
            else
              time_sheet = party.timesheets.current!(current_user.party, RoleType.iid('work_resource'))
              time_entry.timesheet_id = time_sheet.id
            end

            render json: {
              success: true,
              time_entry: time_entry.to_data_hash,
            }

          end
        rescue ActiveRecord::RecordInvalid => invalid
          Rails.logger.error invalid.record.errors

          render :json => {:success => false, :message => invalid.record.errors}
        rescue StandardError => ex
          Rails.logger.error ex.message
          Rails.logger.error ex.backtrace.join("\n")

          ExceptionNotifier.notify_exception(ex) if defined? ExceptionNotifier

          render json: {success: false, message: 'Error creating Time Entry'}
        end
      end

=begin

  @api {post} /api/v1/time_entries/:id Update
  @apiVersion 1.0.0
  @apiName UpdateTimeEntry
  @apiGroup TimeEntry

  @apiParam {Number} [regular_hours_in_seconds] Regular hours in seconds for this TimeEntry
  @apiParam {Number} [overtime_hours_in_seconds] Overtime hours in seconds for this TimeEntry
  @apiParam {DateTime} [from_datetime] From DateTime for this TimeEntry
  @apiParam {DateTime} [thru_datetime] Thru DateTime for this TimeEntry
  @apiParam {String} [comment] Comment for this Time Entry

  @apiSuccess {Boolean} success True if the request was successful
  @apiSuccess {Object} time_entry TimeEntry
  @apiSuccess {Number} time_entry.id Id of TimeEntry
  @apiSuccess {String} time_entry.regular_hours_in_seconds Regular hours in seconds of TimeEntry
  @apiSuccess {String} time_entry.overtime_hours_in_seconds Overtime hours in seconds of TimeEntry
  @apiSuccess {String} time_entry.comment Comment for this TimeEntry
  @apiSuccess {DateTime} time_entry.from_datetime From DateTime for TimeEntry
  @apiSuccess {DateTime} time_entry.thru_datetime Thru DateTime for TimeEntry
  @apiSuccess {DateTime} time_entry.created_at When the TimeEntry was created
  @apiSuccess {DateTime} time_entry.updated_at When the TimeEntry was updated

=end

      def update
        begin
          ActiveRecord::Base.connection.transaction do

            time_entry = TimeEntry.find(params[:id])

            if params[:from_datetime]
              time_entry.from_datetime = params[:from_datetime].to_time
            end

            if params[:thru_datetime]
              time_entry.from_datetime = params[:thru_datetime].to_time
            end

            if params[:comment]
              time_entry.comment = params[:comment].strip
            end

            if params[:regular_hours_in_seconds]
              time_entry.regular_hours_in_seconds = params[:regular_hours_in_seconds].to_i
            end

            if params[:overtime_hours_in_seconds]
              time_entry.overtime_hours_in_seconds = params[:regular_hours_in_seconds].to_i
            end

            # update to manual entry
            time_entry.manual_entry = true

            render json: {
              success: time_entry.save!,
              time_entry: time_entry.to_data_hash,
            }

          end
        rescue ActiveRecord::RecordInvalid => invalid
          Rails.logger.error invalid.record.errors

          render :json => {:success => false, :message => invalid.record.errors}
        rescue StandardError => ex
          Rails.logger.error ex.message
          Rails.logger.error ex.backtrace.join("\n")

          ExceptionNotifier.notify_exception(ex) if defined? ExceptionNotifier

          render json: {success: false, message: 'Error updating Time Entry'}
        end
      end

=begin

  @api {post} /api/v1/time_entries/:id Show
  @apiVersion 1.0.0
  @apiName ShowTimeEntry
  @apiGroup TimeEntry

  @apiSuccess {Boolean} success True if the request was successful
  @apiSuccess {Object} time_entry TimeEntry
  @apiSuccess {Number} time_entry.id Id of TimeEntry
  @apiSuccess {String} time_entry.regular_hours_in_seconds Regular hours in seconds of TimeEntry
  @apiSuccess {String} time_entry.overtime_hours_in_seconds Overtime hours in seconds of TimeEntry
  @apiSuccess {String} time_entry.comment Comment for this TimeEntry
  @apiSuccess {DateTime} time_entry.from_datetime From DateTime for TimeEntry
  @apiSuccess {DateTime} time_entry.thru_datetime Thru DateTime for TimeEntry
  @apiSuccess {DateTime} time_entry.created_at When the TimeEntry was created
  @apiSuccess {DateTime} time_entry.updated_at When the TimeEntry was updated

=end

      def show
        time_entry = TimeEntry.find(params[:id])

        render :json => {success: true, time_entry: time_entry.to_data_hash}
      end

=begin

  @api {post} /api/v1/time_entries Start
  @apiVersion 1.0.0
  @apiName StartTimeEntry
  @apiGroup TimeEntry

  @apiDescription Starts TimeEntry by setting the from_datetime to the current time.
  if there is already an open time_entry set its thru_datetime to the current time and
  create a new Time Entry.  It is assumed that a TimeEntry is always logged against a WorkEffort so
  a WorkEffort ID should be passed.

  @apiParam {Number} work_effort_id ID of WorkEffort to start the TimeEntry for
  @apiParam {String} [comment] Comment for this Time Entry

  @apiSuccess {Boolean} success True if the request was successful
  @apiSuccess {Object} time_entry TimeEntry
  @apiSuccess {Number} time_entry.id Id of TimeEntry
  @apiSuccess {String} time_entry.regular_hours_in_seconds Regular hours in seconds of TimeEntry
  @apiSuccess {String} time_entry.overtime_hours_in_seconds Overtime hours in seconds of TimeEntry
  @apiSuccess {String} time_entry.comment Comment for this TimeEntry
  @apiSuccess {DateTime} time_entry.from_datetime From DateTime for TimeEntry
  @apiSuccess {DateTime} time_entry.thru_datetime Thru DateTime for TimeEntry
  @apiSuccess {DateTime} time_entry.created_at When the TimeEntry was created
  @apiSuccess {DateTime} time_entry.updated_at When the TimeEntry was updated

=end

      def start
        begin
          ActiveRecord::Base.connection.transaction do

            party = current_user.party
            work_effort = WorkEffort.find(params[:work_effort_id])

            # check for an open TimeEntry
            open_time_entry = party.open_time_entry

            # if there is an open TimeEntry stop it and start a new one
            if open_time_entry
              open_time_entry.thru_datetime = Time.now

              open_time_entry.calculate_regular_hours_in_seconds!
            end

            time_entry = TimeEntry.create(
              from_datetime: params[:start_at].to_time
            )

            time_entry.work_effort = work_effort

            # associate to a timesheet
            time_sheet = party.timesheets.current!(RoleType.iid('work_resource'))
            time_sheet.time_entries << time_entry

            # update task statuses
            time_entry.update_task_status('task_status_in_progress')
            time_entry.update_task_assignment_status('task_resource_status_in_progress')

            render json: {
              success: true,
              time_entry: time_entry.to_data_hash,
            }
          end
        rescue ActiveRecord::RecordInvalid => invalid
          Rails.logger.error invalid.record.errors

          render :json => {:success => false, :message => invalid.record.errors}
        rescue StandardError => ex
          Rails.logger.error ex.message
          Rails.logger.error ex.backtrace.join("\n")

          ExceptionNotifier.notify_exception(ex) if defined? ExceptionNotifier

          render json: {success: false, message: 'Error starting Time Entry'}
        end
      end

=begin

  @api {put} /api/v1/time_entries/:id/stop Stop
  @apiVersion 1.0.0
  @apiName StopTimeEntry
  @apiGroup TimeEntry

  @apiDescription Stop TimeEntry by setting the thru_datetime and calculating the hours in seconds
  it returns the TimeEntry record as well as formatted totals for the day and week

  @apiParam {Number} work_effort_id ID of WorkEffort that this TimeEntry is associated to
  @apiParam {DateTime} end_date When this TimeEntry Stopped
  @apiParam {String} [comment] Comment for this Time Entry

  @apiSuccess {Boolean} success True if the request was successful
  @apiSuccess {Object} time_entry TimeEntry
  @apiSuccess {Number} time_entry.id Id of TimeEntry
  @apiSuccess {String} time_entry.regular_hours_in_seconds Regular hours in seconds of TimeEntry
  @apiSuccess {String} time_entry.overtime_hours_in_seconds Overtime hours in seconds of TimeEntry
  @apiSuccess {String} time_entry.comment Comment for this TimeEntry
  @apiSuccess {DateTime} time_entry.from_datetime From DateTime for TimeEntry
  @apiSuccess {DateTime} time_entry.thru_datetime Thru DateTime for TimeEntry
  @apiSuccess {DateTime} time_entry.created_at When the TimeEntry was created
  @apiSuccess {DateTime} time_entry.updated_at When the TimeEntry was updated
  @apiSuccess {String} day_total_formatted Formatted day total as 00:00:00
  @apiSuccess {String} week_total_formatted Formatted week total as 00:00:00

=end

      def stop
        begin
          ActiveRecord::Base.connection.transaction do
            party = current_user.party

            time_entry = TimeEntry.find(params[:id])
            work_effort = WorkEffort.find(params[:work_effort_id])

            time_entry.thru_datetime = params[:end_at].to_time
            time_entry.comment = params[:comment].present? ? params[:comment].strip : nil

            time_entry.calculate_regular_hours_in_seconds!

            time_entry.update_task_assignment_status('task_resource_status_hold')

            result = {
              success: true,
              time_entry: time_entry.to_data_hash,
            }

            time_helper = ErpBaseErpSvcs::Helpers::Time::Client.new(params[:client_utc_offset])

            result[:day_total_formatted] = TimeEntry.total_formatted(work_effort: work_effort,
                                                                     party: party,
                                                                     start: time_helper.beginning_of_day,
                                                                     end: time_helper.end_of_day
                                                                     )
            result[:week_total_formatted] = TimeEntry.total_formatted(work_effort: work_effort,
                                                                      party: party,
                                                                      start: time_helper.beginning_of_week,
                                                                      end: time_helper.end_of_week
                                                                      )

            render json: result
          end
        rescue ActiveRecord::RecordInvalid => invalid
          Rails.logger.error invalid.record.errors

          render :json => {:success => false, :message => invalid.record.errors}
        rescue StandardError => ex
          Rails.logger.error ex.message
          Rails.logger.error ex.backtrace.join("\n")

          ExceptionNotifier.notify_exception(ex) if defined? ExceptionNotifier

          render json: {success: false, message: 'Error stopping Time Entry'}
        end
      end

=begin

  @api {get} /api/v1/time_entries/open Open
  @apiVersion 1.0.0
  @apiName OpenTimeEntry
  @apiGroup TimeEntry

  @apiDescription If a work effort id is passed get the last open time_entry for that work_effort
  for the current user if there are no open time entries then return only the totals

  @apiParam {Number} client_utc_offset Offset of Client
  @apiParam {Number} [work_effort_id] ID of WorkEffort

  @apiSuccess {Boolean} success True if the request was successful
  @apiSuccess {Array} time_entries Array of open TimeEntries
  @apiSuccess {Number} time_entries.id Id of TimeEntry
  @apiSuccess {String} time_entries.regular_hours_in_seconds Regular hours in seconds of TimeEntry
  @apiSuccess {String} time_entries.overtime_hours_in_seconds Overtime hours in seconds of TimeEntry
  @apiSuccess {String} time_entries.comment Comment for this TimeEntry
  @apiSuccess {DateTime} time_entries.from_datetime From DateTime for TimeEntry
  @apiSuccess {DateTime} time_entries.thru_datetime Thru DateTime for TimeEntry
  @apiSuccess {DateTime} time_entries.created_at When the TimeEntry was created
  @apiSuccess {DateTime} time_entries.updated_at When the TimeEntry was updated

=end

      def open
        if params[:work_effort_id]
          work_effort = WorkEffort.find(params[:work_effort_id])
          party = current_user.party

          open_time_entry = work_effort.time_entries.scope_by_party(current_user.party).open_entries.first
          time_helper = ErpBaseErpSvcs::Helpers::Time::Client.new(params[:client_utc_offset])

          render :json => {success: true,
                           time_entry: open_time_entry.nil? ? nil : open_time_entry.to_data_hash,
                           day_total_formatted: TimeEntry.total_formatted(work_effort: work_effort,
                                                                          party: party,
                                                                          start: time_helper.beginning_of_day,
                                                                          end: time_helper.end_of_day),
                           week_total_formatted: TimeEntry.total_formatted(work_effort: work_effort,
                                                                           party: party,
                                                                           start: time_helper.beginning_of_week,
                                                                           end: time_helper.end_of_week)
                           }
        else
          render :json => {success: true, time_entries: TimeEntry.open_entries.collect { |time_entry| time_entry.to_data_hash }}
        end
      end

=begin

  @api {get} /api/v1/time_entries/totals Totals
  @apiVersion 1.0.0
  @apiName TotalsTimeEntry
  @apiGroup TimeEntry

  @apiDescription Returns totals for time entries.  If a work effort id is passed it will get totals for the
  passed work effort.  If no work effort id is passed it will get totals for the current user
  passed on their timesheet

  @apiParam {Number} client_utc_offset Offset of Client
  @apiParam {Number} [work_effort_id] ID of WorkEffort
  @apiParam {Number} [party_id] ID of Party

  @apiSuccess {Boolean} success True if the request was successful
  @apiSuccess {Number} day_total_seconds Day total in seconds
  @apiSuccess {Number} week_total_seconds Week total in seconds
  @apiSuccess {String} day_total_formatted Day total formatted as 00:00:00
  @apiSuccess {String} week_total_formatted Week total formatted as 00:00:00
  @apiSuccess {String} total_formatted Total formatted as 00:00:00

=end

      def totals
        result = {
          success: true,
          day_total_seconds: 0,
          week_total_seconds: 0,
          day_total_formatted: '00:00:00',
          week_total_formatted: '00:00:00',
          total_formatted: '00:00:00'
        }

        work_effort = nil
        party = nil
        time_helper = ErpBaseErpSvcs::Helpers::Time::Client.new(params[:client_utc_offset])

        if params[:work_effort_id]
          work_effort = WorkEffort.find(params[:work_effort_id])
        end

        if params[:party_id]
          party = Party.find(params[:party_id])
        end

        result[:day_total_seconds] = TimeEntry.total_seconds(work_effort: work_effort,
                                                             party: party,
                                                             start: time_helper.beginning_of_day,
                                                             end: time_helper.end_of_day
                                                             )
        result[:week_total_seconds] = TimeEntry.total_seconds(work_effort: work_effort,
                                                              party: party,
                                                              start: time_helper.beginning_of_week,
                                                              end: time_helper.end_of_week
                                                              )
        result[:total_seconds] = TimeEntry.total_seconds(work_effort: work_effort,
                                                         party: party
                                                         )
        result[:day_total_formatted] = TimeEntry.total_formatted(work_effort: work_effort,
                                                                 party: party,
                                                                 start: time_helper.beginning_of_day,
                                                                 end: time_helper.end_of_day
                                                                 )
        result[:week_total_formatted] = TimeEntry.total_formatted(work_effort: work_effort,
                                                                  party: party,
                                                                  start: time_helper.beginning_of_week,
                                                                  end: time_helper.end_of_week
                                                                  )
        result[:total_formatted] = TimeEntry.total_formatted(work_effort: work_effort,
                                                             party: party
                                                             )

        render json: result
      end

    end # TimeEntriesController
  end # V1
end # API
