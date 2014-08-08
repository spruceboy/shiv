####
# contains rendering stuff.. 
#

class Render
  
  def initialize()
    #code
  end
  
  def render(view, locals)
    
  end

  private
    def path_to_template(view)
      File.dirname(__FILE__) + '/views/' + view + ext()
    end
    def loud_template(view)
      return File.read(path_to_template(view))
    end
    
    def ext()
      "thisisahugemistake"
    end
    
end

#improvements are needed here - a bit of a mess..
class RenderEng < Render
  require 'haml'
  require 'tilt/haml'
  
  def initialize()
    #code
  end
  
  def render(view, locals, layout="layout")
    render_file(layout,view, locals)
  end
  
private
    def render_file(layout,view, locals)
      
      Tilt::HamlTemplate.new(path_to_template(layout)).render(Object.new, :data => locals) { Tilt::HamlTemplate.new(path_to_template(view)).render(Object.new, :data => locals)}
      
    end
    
    def ext()
      ".haml"
    end
end








