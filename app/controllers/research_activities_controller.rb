class ResearchActivitiesController < ApiController
  def show
    activity = ResearchActivity.includes(participations: %i[person organization], visits: %i[station participations]).find(params[:id])
    render json: ResearchActivitySerializer.new(activity)
  end
end
