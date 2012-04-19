PdfPilot.helpers do

  def is_active(menu)

  	if request.path_info == "/#{menu}"
  	  return 'active'
  	elsif request.path_info != "/new" && menu == :other
  	  return 'active'
  	end
  	nil
  end

end