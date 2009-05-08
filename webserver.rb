require "rubygems"
require "sinatra"
require "json"
require "lib/connections"

configure do
  @@connections = Connections.new
end

def get_history(last_read)
  history = Hash.new
  @@connections.each_connection_with_id do |connection_id, connection|
    history[connection_id] = connection.history(last_read.has_key?(connection_id) ? last_read[connection_id] : 0)
  end
  history
end

def get_users
  users = Hash.new
  @@connections.each_connection_with_id do |connection_id, connection|
    users[connection_id] = connection.users
  end
  users
end

def sync(open)
  close = Hash.new
  close_connections = Array.new
  open.each_key do |connection_id|
    if @@connections.has?(connection_id)
      close[connection_id] = {:channels => @@connections[connection_id].sync_channels(open[connection_id]["channels"]), :privmsgs => @@connections[connection_id].sync_privmsgs(open[connection_id]["privmsgs"])}
    else
      close_connections << connection_id
    end
  end
  {:targets => close, :connections => close_connections}
end

def get_update(json_object)
  {:history => get_history(json_object["last_read"]), :sync => sync(json_object["sync"])}.to_json
end

def json_request(request)
  JSON.parse(request.env["rack.input"].read)
end

get "/" do
  erb :home
end

post "/connect" do
  command = json_request(request)
  @@connections.add(command)
  sleep 1
  get_update(command)
end

post "/close" do
  command = json_request(request)
  if command["target"]
    @@connections[command["connection_id"]].close(command["target"]) if @@connections.has?(command["connection_id"])
  else
    @@connections.remove(command["connection_id"])
  end
  sleep 1
  get_update(command)
end

post "/join" do
  command = json_request(request)
  @@connections[command["connection_id"]].join(command["channel"]) if @@connections.has?(command["connection_id"])
  sleep 1
  get_update(command)
end

post "/part" do
  command = json_request(request)
  @@connections[command["connection_id"]].part(command["channel"]) if @@connections.has?(command["connection_id"])
  sleep 1
  get_update(command)
end

post "/privmsg" do
  command = json_request(request)
  @@connections[command["connection_id"]].privmsg(command["target"], command["text"], command["action"]) if @@connections.has?(command["connection_id"])
  get_update(command)
end

post "/notice" do
  command = json_request(request)
  @@connections[command["connection_id"]].notice(command["target"], command["text"]) if @@connections.has?(command["connection_id"])
  get_update(command)
end

post "/new_window" do
  command = json_request(request)
  @@connections[command["connection_id"]].new_window(command["target"]) if @@connections.has?(command["connection_id"])
  get_update(command)
end

get "/all" do
  {:history => get_history({})}.to_json
end

post "/update" do
  get_update(JSON.parse(request.env["rack.input"].read))
end

post "/command" do
  command = json_request(request)
  @@connections[command["connection_id"]].send(command["command"]) if @@connections.has?(command["connection_id"])
  sleep command["wait"] if command["wait"]
  {:history => get_history(command["last_read"]), :sync => sync(command["sync"])}.to_json
end