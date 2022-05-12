require "pg"
require "pry"

class DatabasePersistence
  def initialize(logger)
    # @db = PG.connect(dbname: "todos")

    @db = if Sinatra::Base.production?
      PG.connect(ENV['DATABASE_URL'])
    else
      PG.connect(dbname: "todos")
    end

    @logger = logger
  end

  def query(statement, *params)
    @logger.info "#{statement}: #{params}"

    @db.exec_params(statement, params)
  end

  def find_list(id)
    sql = <<~SQL
      SELECT lists.*, COUNT(todo.id) AS todos_count,
        COUNT(NULLIF(todo.completed, true)) AS todos_remaining_count
        FROM lists
        LEFT JOIN todo ON todo.list_id = lists.id
        WHERE lists.id = $1
        GROUP BY lists.id
        ORDER BY lists.name;
    SQL
    result = query(sql, id)
    tuple_to_list_hash(result.first)
  end

  def all_lists
    sql = <<~SQL
      SELECT lists.*, COUNT(todo.id) AS todos_count,
        COUNT(NULLIF(todo.completed, true)) AS todos_remaining_count
        FROM lists
        LEFT JOIN todo ON todo.list_id = lists.id
        GROUP BY lists.id
        ORDER BY lists.name;
    SQL
    result = query(sql)

    result.map do |tuple|
      tuple_to_list_hash(tuple)
    end
  end

  def create_new_list(list_name)
    sql = "INSERT INTO lists (name) VALUES ($1);"
    query(sql, list_name)
    # id = next_element_id(@session[:lists])
    # @session[:lists] << { id: id, name: list_name, todos: [] }
  end

  def delete_list(id)
    query("DELETE FROM todo WHERE list_id = $1", id)
    query("DELETE FROM lists WHERE id = $1", id)
    # @session[:lists].reject! { |list| list[:id] == id }
  end

  def update_list_name(id, new_name)
    sql = "UPDATE lists SET name = $1 WHERE id = $2"
    query(sql, new_name, id)

    # list = find_list(id)

    # list[:name] = new_name
  end

  def create_new_todo(list_id, todo_name)
    sql = "INSERT INTO todo (name, list_id) VALUES ($2, $1)"
    query(sql, list_id, todo_name)
    # list = find_list(list_id)
    # id = next_element_id(list[:todos])
    # list[:todos] << { id: id, name: todo_name, completed: false }
  end

  def delete_todo_from_list(list_id, todo_id)
    sql = "DELETE FROM todo WHERE id = $1 AND list_id = $2"

    query(sql, todo_id, list_id)
    # list = find_list(list_id)
    # list[:todos].reject! { |todo| todo[:id] == todo_id }
  end

  def updated_todo_status(list_id, todo_id, new_status)
    sql = "UPDATE todo SET completed = $1 WHERE id = $2 AND list_id = $3"
    query(sql, new_status, todo_id, list_id)
    # list = find_list(list_id)

    # todo = @list[:todos].find { |t| t[:id] == todo_id }
    # todo[:completed] = new_status
  end

  def mark_all_todos_as_completed(list_id)
    sql = "UPDATE todo SET completed = true WHERE list_id = $1"
    query(sql, list_id)
    # list = find_list(list_id)
    # list[:todos].each do |todo|
    #   todo[:completed] = true
    # end
  end

  def disconnect
    @db.close
  end

  def find_todos_for_list(list_id)
    todo_sql = "SELECT * FROM todo WHERE list_id = $1"
    todos_result = query(todo_sql, list_id)

    todos_result.map do |todo_tuple|
        { id: todo_tuple["id"].to_i,
        name: todo_tuple["name"] ,
        completed: todo_tuple["completed"] == "t" }
      end
  end

  private

  def tuple_to_list_hash(tuple)


    { id: tuple["id"].to_i,
      name: tuple["name"],
      todos_count: tuple["todos_count"].to_i,
      todos_remaining_count: tuple["todos_remaining_count"].to_i
    }
  end
end