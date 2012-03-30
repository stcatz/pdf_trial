PdfPilot.controllers  do
  layout :base

  get :index do
  	@all_file = Dir.glob File.join( PdfPilot::UPLOAD_PATH, '*.pdf')
  	@files = {}
  	@all_file.map{ |a| @files[a.split('/').last ] = a }
    render :index
  end

  get :new do
    render :new
  end

  get :show, :with => :id do
    @file_name = params[:id]
    render :show
  end

  post :create do
    temp_file = params[:pdf_file][:tempfile]
    diskfile = File.join(PdfPilot::UPLOAD_PATH, params[:pdf_file][:filename])
    if temp_file.size > 0
      File.open(diskfile, "wb") do |f|
        buffer = ""
        while (buffer = temp_file.read(8192))
          f.write(buffer)
        end
      end
    end
    redirect url(:index)
  end


end