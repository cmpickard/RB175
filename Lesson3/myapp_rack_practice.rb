require 'rackup'

class MyApp
  def call(env)
    body = "<h1> Hello in style!</h1>"
    ['200', { "Content-Type" => "text/html" }, [env.to_s]]
  end
end

Rackup::Handler::WEBrick.run MyApp.new