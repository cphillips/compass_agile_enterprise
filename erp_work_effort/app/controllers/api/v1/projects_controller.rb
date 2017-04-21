module API
  module V1
    class ProjectsController < BaseController

=begin

  @api {get} /api/v1/projects Index
  @apiVersion 1.0.0
  @apiName GetWorkProjects
  @apiGroup Project

  @apiSuccess {Boolean} success True if the request was successful
  @apiSuccess {Array} projects List of Projects
  @apiSuccess {Number} projects.id Id of Project
  @apiSuccess {String} projects.description Description of Project
  @apiSuccess {DateTime} projects.created_at When the Project was created
  @apiSuccess {DateTime} projects.updated_at When the Project was updated

=end

      def index
        # check if we are scoping by current user
        if params[:scope_by_user].present? and params[:scope_by_user].to_bool
          party = current_user.party
          projects = Project.scope_by_party(party,
                                            {role_types: RoleType.find_child_role_types(party.party_roles.collect { |party_role| party_role.role_type })})
        else
          # scope by dba organization
          projects = Project.scope_by_dba_organization(current_user.party.dba_organization)
        end

        if params[:query]
          projects = projects.where(projects.arel_table[:description].matches("%#{params[:query]}%"))
        end

        render :json => {success: true, projects: projects.all.map { |project| project.to_data_hash }}
      end

    end # ProjectsController
  end # V1
end # API