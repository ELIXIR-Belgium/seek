class SinglePagesController < ApplicationController
  before_action :login_required
  before_action :single_page_enabled
  respond_to :html, :js
  
  def show
    @project = Project.find(params[:id])
    @folders = project_folders
    # For creating new investigation and study in Project view page
    @investigation = Investigation.new({})
    @study = Study.new({})
    @assay = Assay.new({})
    @sourceTypes = load_templates

    respond_to do |format|
      format.html
    end
  end

  def single_page_enabled
    unless Seek::Config.project_single_page_enabled
      flash[:error]="Not available"
      redirect_to Project.find(params[:id])
    end
  end

  def render_sharing_form
    begin
      if params[:type] == "investigation"
        @investigation = Investigation.find(params[:id]) 
      elsif params[:type] == "study"
        @study = Study.find(params[:id]) 
      elsif params[:type] == "assay"
        @assay = Assay.find(params[:id]) 
        @sop = @assay.sops.first
      end
    rescue Exception => e
      error = e.message
    end
    respond_to do |format|
      if error
        format.js { render plain: error, status: :unprocessable_entity }
      else
        format.js
      end
    end
  end

  def project_folders
    project_folders = ProjectFolder.root_folders(@project)
    if project_folders.empty?
      project_folders = ProjectFolder.initialize_default_folders(@project)
      ProjectFolderAsset.assign_existing_assets @project
    end
    project_folders
  end

  # GET
  def flowchart
    begin
      flowchart = Flowchart.where(study_id: params[:study_id]).first
      study = Study.where(id: params[:study_id]).first
      assay_ids = study.assays.select { |a| a.sops.length > 0 } .collect{|a| a.id.to_s}
      if flowchart.nil?
        return render json: {error:"no flowchart" }, status: :unprocessable_entity
      else
        #Filters items that don't exist anymore
        items = JSON.parse(flowchart.items).map{|n| n if assay_ids.include?(n["id"]) || n["id"].blank?}.compact
      end
      operators = items.map {|item| create_operator(item,study)}
      links = items.drop(1).map.with_index {|item, i| create_link(i)}
      flowchart_data = {operators: operators, links: links, operatorTypes:{}}
    rescue Exception => e
      error = e.message
    end
    if error
      render json: {status: :unprocessable_entity, error: error  }
    else
      render json: {status: :ok, data: flowchart_data }
    end
  end

  # POST >> TO-DO: PUT flowchart
  def update_flowchart
    is_new = false
    f = Flowchart.find_or_create_by(study_id: params[:flowchart][:study_id]) do |u|
      is_new = true
    end
    if f.update_attributes(flowchart_params)
      render json: { data: f, is_new: is_new }, status: :ok
    else
      render json: { error: json_api_errors(f) }, status: :unprocessable_entity
    end
  end

  #GET study_id
  def sample_source 
    flowchart = Flowchart.where(study_id: params[:study_id]).first
    if (flowchart)
      source_sample_type = SampleType.find(flowchart.source_sample_type_id).sample_attributes.select(:required, :title,
           :sample_type_id, :id, :sample_controlled_vocab_id)
      render json: { status: :ok, data: source_sample_type }
    else
      render json: { status: :unprocessable_entity, error: "There is no data yet!" }
    end
  end

  #GET 
  def sample_table
    assay = Assay.find(params[:assay_id])
    flowchart = Flowchart.where(study_id: assay.study.id).first
    if (flowchart)
      source_sample_type = SampleType.find(flowchart.source_sample_type_id)
      samples = load_samples(assay, source_sample_type)
      header = load_headers(assay, source_sample_type)
      render json: { status: :ok, data: { header: header, samples: samples } }
    else
      render json: { status: :unprocessable_entity, error: "The flowchart does not exist." }
    end
  end


  #GET
  def ontology
    begin
      labels = (SampleControlledVocab.find(params[:sample_controlled_vocab_id])
      &.sample_controlled_vocab_terms || [])
      .where("LOWER(label) like :query", query: "%#{params[:query].downcase}%")
      .select("label").limit(params[:limit] || 100)
      render json: { status: :ok, data: labels }
    rescue Exception => e
      render json: {status: :unprocessable_entity, error: e.message } 
    end
  end

  private

  def flowchart_params
    params.require(:flowchart).permit(:study_id, :source_sample_type_id, :assay_sample_type, :items)
        .select { |k, v| !v.nil? }
  end


  def create_operator (item, study)
    id = item["id"]
    { properties: {title: id.blank? ? "Source Sample" : study.assays.find(id).sops.first.title,
      inputs: id.blank? ? {} : {input_0: {label: "in"}}, outputs: {output_0: {label: "out"}}, 
      shape: id.blank? ? "parallelogram" : "rectangle", 
      shape_id: id || "init"}, left: item["left"], top: item["top"]}
  end

  def create_link index
    {fromOperator:index, fromConnector:"output_0",
      fromSubConnector: "0",toOperator: index + 1, toConnector:"input_0",toSubConnector: "0"}
  end

  # Moved to application_helper

  # def load_templates
  #   source_list = []
  #   RepositoryStandard.all().each do |item|
  #     source_list.push({title: item.title, type: item.repo_type, 
  #       repoId: item.id, attributes: 
  #       item.sample_controlled_vocabs.map do |term|
  #         { id: term.id, title: term.title, shortName: term.short_name, des: term.description, required: term.required }
  #       end
  #     })
  #   end
  #   source_list
  # end

  def load_headers (assay, source)
    # No assay is associated with the source
    header = source.sample_attributes.select(:required, :title, :sample_type_id, :id, :sample_controlled_vocab_id)
    Study.find(assay.study.id).assays.where("position <= #{assay.position}").order(:position).each do |a|
      header += a.sample_type.sample_attributes.select(:required, :title, :sample_type_id, :id, :sample_controlled_vocab_id)
    end
    header
  end


  def load_samples (assay, source)
    return nil if assay.position.nil? 
    samples_collection = {}
    # No assay is associated with the source
    samples_collection[0] = source.samples.select(:id, :json_metadata, :sample_type_id, :link_id)
    Study.find(assay.study.id).assays.where("position <= #{assay.position}").order(:position).each_with_index do |a, i|
      samples_collection[i + 1] = a.sample_type.samples.select(:id, :json_metadata, :sample_type_id, :link_id)
    end
    samples_collection
  end
end
