class App
  include Xdef42::App
  get "/" do
    render 200, {a: "b"}
  end
end

run App.new