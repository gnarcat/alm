
def determine_revision
  # Note the revision we're running
  revisionFile = Rails.root + "/REVISION"
  digits = 8
  Rails.env + begin
    " " + File.read(revisionFile).strip[0...digits]
  rescue
    begin
      if File.exist?(".git")
        " #{`git log -1`.split(" ")[1][0...digits]} #{`git branch`.split("\n")[0].split(" ")[-1]}"
      else
        " " + XmlSimple::xml_in_string(`svn info --xml`)["entry"][0]["revision"]
      end
    rescue
      ""
    end
  end
end 
SOURCE_REVISION = determine_revision
