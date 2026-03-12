require "test_helper"

class TodoTest < ActiveSupport::TestCase
  test "should be valid with valid attributes" do
    todo = Todo.new(title: "Test todo")
    assert todo.valid?
  end

  test "should be valid with completed set to false" do
    todo = Todo.new(title: "Test todo", completed: false)
    assert todo.valid?
  end

  test "should be valid with completed set to true" do
    todo = Todo.new(title: "Test todo", completed: true)
    assert todo.valid?
  end

  test "should not be valid without a title" do
    todo = Todo.new(title: nil)
    assert_not todo.valid?
    assert_includes todo.errors[:title], "can't be blank"
  end

  test "should not be valid with empty title" do
    todo = Todo.new(title: "")
    assert_not todo.valid?
    assert_includes todo.errors[:title], "can't be blank"
  end

  test "should not be valid with title longer than 255 characters" do
    todo = Todo.new(title: "a" * 256)
    assert_not todo.valid?
    assert_includes todo.errors[:title], "is too long (maximum is 255 characters)"
  end

  test "should be valid with title of exactly 255 characters" do
    todo = Todo.new(title: "a" * 255)
    assert todo.valid?
  end

  test "completed scope returns only completed todos" do
    completed = todos(:two)
    incomplete = todos(:one)

    assert_includes Todo.completed, completed
    assert_not_includes Todo.completed, incomplete
  end

  test "incomplete scope returns only incomplete todos" do
    completed = todos(:two)
    incomplete = todos(:one)

    assert_includes Todo.incomplete, incomplete
    assert_not_includes Todo.incomplete, completed
  end

  test "default value of completed should be false" do
    todo = Todo.new(title: "Test todo")
    assert_equal false, todo.completed
  end
end
