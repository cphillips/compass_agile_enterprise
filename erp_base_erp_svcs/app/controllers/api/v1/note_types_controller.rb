module API
  module V1
    class NoteTypesController < BaseController

      def index
        NoteType.include_root_in_json = false

        if params[:ids]

          render json: {note_types: NoteType.where(id: params[:ids].split(',')).all}
        else

          render json: {success: true, note_types: NoteType.all}
        end
      end

      def show
        NoteType.include_root_in_json = false

        note_type = NoteType.find(params[:id])

        render json: {success: true, note_type: note_type}
      end

    end # NoteTypesController
  end # V1
end # API