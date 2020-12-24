class App
  include Xdef42::App
  get "/" do
    render 200, "It's ok"
  end
end

run App.new