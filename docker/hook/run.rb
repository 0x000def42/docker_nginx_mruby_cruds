class App
  include Xdef42::App
  get "/" do
    db.set("number", JSON.stringify({field1: 15, field2: "STRING", id: 99999}))
    render 200, {a: JSON.parse(db.get("number"))}
  end
end

run App.instance